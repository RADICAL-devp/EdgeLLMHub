import 'dart:convert';

import 'package:doctor_app/core/crypto/phi_encryption_service.dart';
import 'package:doctor_app/core/data/app_database.dart';
import 'package:doctor_app/core/data/note_repository.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/models/clinical_note.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MemorySecureStorage storage;
  late PhiEncryptionService encryption;
  late NoteRepository repository;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    storage = MemorySecureStorage();
    encryption = PhiEncryptionService(
      secureStorage: storage,
      keyAlias: 'test_phi_key',
    );
    repository = NoteRepository(db, encryption);
  });

  tearDown(() async {
    await db.close();
  });

  ClinicalNote note({
    String id = 'note-1',
    String title = 'Chest pain review',
    String patient = 'Asha Rao',
    String transcript = 'Patient reports chest pain since yesterday.',
    NoteStatus status = NoteStatus.draft,
    DateTime? updatedAt,
  }) {
    final timestamp = updatedAt ?? DateTime(2025, 5, 10, 12);
    return ClinicalNote(
      id: id,
      title: title,
      patientName: patient,
      transcript: transcript,
      sections: StructuredNoteSections(
        chiefComplaint: 'Chest pain',
        assessment: 'Possible angina',
      ),
      status: status,
      languageCode: 'en',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  group('PhiEncryptionService', () {
    test('round-trips PHI and persists the key in secure storage', () async {
      final cipher = await encryption.encryptString('sensitive note');
      expect(cipher, isNot(contains('sensitive')));
      expect(await encryption.decryptString(cipher), 'sensitive note');

      final anotherService = PhiEncryptionService(
        secureStorage: storage,
        keyAlias: 'test_phi_key',
      );
      expect(await anotherService.decryptString(cipher), 'sensitive note');
      expect(
        storage.lastReadAppleOptions?.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
      expect(
        storage.lastWriteAppleOptions?.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
    });

    test('detects tampered ciphertext', () async {
      final cipher = await encryption.encryptString('sensitive note');
      final bytes = base64Decode(cipher);
      bytes[bytes.length - 1] ^= 1;
      final tampered = base64Encode(bytes);

      expect(
        () => encryption.decryptString(tampered),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('empty strings stay empty', () async {
      expect(await encryption.encryptString(''), '');
      expect(await encryption.decryptString(''), '');
    });

    test('uses one key for concurrent first encryptions', () async {
      final ciphertexts = await Future.wait(
        List.generate(12, (index) => encryption.encryptString('note $index')),
      );

      final plaintexts = await Future.wait(
        ciphertexts.map(encryption.decryptString),
      );

      expect(plaintexts, List.generate(12, (index) => 'note $index'));
      expect(storage.values, contains('test_phi_key'));
    });
  });

  group('NoteRepository', () {
    test('stores PHI columns as ciphertext and restores the note', () async {
      final original = note();
      await repository.save(original);

      final row = await db.select(db.clinicalNotes).getSingle();
      expect(row.titleCipher, isNot(original.title));
      expect(row.patientNameCipher, isNot(original.patientName));
      expect(row.transcriptCipher, isNot(original.transcript));
      expect(row.sectionsCipher, isNot(contains('Chest pain')));
      expect(row.languageCode, 'en');

      final restored = await repository.getById(original.id);
      expect(restored, isNotNull);
      expect(restored!.title, original.title);
      expect(restored.patientName, original.patientName);
      expect(restored.transcript, original.transcript);
      expect(restored.sections.chiefComplaint, 'Chest pain');
      expect(restored.sections.assessment, 'Possible angina');
      expect(restored.status, NoteStatus.draft);
    });

    test('orders notes by most recently updated and counts statuses', () async {
      await repository.save(note(id: 'old', updatedAt: DateTime(2025, 5, 1)));
      await repository.save(note(id: 'new', updatedAt: DateTime(2025, 5, 3)));
      await repository.save(
        note(
          id: 'final',
          updatedAt: DateTime(2025, 5, 2),
          status: NoteStatus.finalized,
        ),
      );

      final all = await repository.getAll();
      expect(all.map((item) => item.id), ['new', 'final', 'old']);
      expect(await repository.countAll(), 3);
      expect(await repository.countByStatus(NoteStatus.draft), 2);
      expect(await repository.countByStatus(NoteStatus.finalized), 1);
    });

    test('searches decrypted title, patient, transcript, and dates', () async {
      await repository.save(note());

      expect(await repository.search('chest pain'), hasLength(1));
      expect(await repository.search('asha'), hasLength(1));
      expect(await repository.search('yesterday'), hasLength(1));
      expect(await repository.search('2025-05-10'), hasLength(1));
      expect(
        await repository.search(
          '',
          from: DateTime(2025, 5, 10),
          to: DateTime(2025, 5, 10),
        ),
        hasLength(1),
      );
      expect(
        await repository.search(
          '',
          from: DateTime(2025, 5, 11),
          to: DateTime(2025, 5, 12),
        ),
        isEmpty,
      );
      expect(await repository.search('nothing here'), isEmpty);
    });

    test(
      'deletes one note and all notes without touching the other records',
      () async {
        await repository.save(note(id: 'one'));
        await repository.save(note(id: 'two', title: 'Follow-up'));

        await repository.deleteById('one');
        expect(await repository.getById('one'), isNull);
        expect(await repository.getById('two'), isNotNull);

        await repository.deleteAll();
        expect(await repository.countAll(), 0);
      },
    );

    test(
      'keeps an unreadable row visible as a deletable placeholder',
      () async {
        await db
            .into(db.clinicalNotes)
            .insert(
              ClinicalNotesCompanion.insert(
                id: 'broken',
                titleCipher: 'not-valid-base64',
                patientNameCipher: 'not-valid-base64',
                transcriptCipher: 'not-valid-base64',
                sectionsCipher: 'not-valid-base64',
                status: NoteStatus.draft.index,
                createdAt: DateTime(2025, 5, 10),
                updatedAt: DateTime(2025, 5, 10),
              ),
            );

        final notes = await repository.getAll();
        expect(notes, hasLength(1));
        expect(notes.single.title, 'Unreadable note');
        expect(notes.single.displayTitle, 'Unreadable note');
      },
    );
  });
}
