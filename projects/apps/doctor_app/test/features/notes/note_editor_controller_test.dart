import 'dart:async';

import 'package:doctor_app/core/crypto/phi_encryption_service.dart';
import 'package:doctor_app/core/data/app_database.dart';
import 'package:doctor_app/core/data/note_repository.dart';
import 'package:doctor_app/core/models/clinical_note.dart';
import 'package:doctor_app/core/utils/debouncer.dart';
import 'package:doctor_app/features/notes/controllers/note_editor_controller.dart';
import 'package:doctor_app/features/notes/controllers/note_editor_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_models/shared_models.dart';

import '../../helpers/fakes.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      ClinicalNote.create(
        id: 'fallback',
        title: 'Fallback note',
        patientName: 'Fallback patient',
        languageCode: 'en',
      ),
    );
  });

  group('NoteEditorController with a real encrypted repository', () {
    late AppDatabase db;
    late NoteRepository repository;

    setUp(() {
      db = AppDatabase.connect(NativeDatabase.memory());
      repository = NoteRepository(
        db,
        PhiEncryptionService(
          secureStorage: MemorySecureStorage(),
          keyAlias: 'editor_test_key',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('creates a note, debounces edits, and saves them to disk', () async {
      final controller = NoteEditorController(
        repository: repository,
        debouncer: Debouncer(const Duration(milliseconds: 10)),
      );
      addTearDown(controller.close);

      final note = await controller.create(
        title: 'Initial title',
        patientName: 'Asha Rao',
        languageCode: 'en',
      );
      expect(note, isNotNull);
      expect(controller.value, isA<NoteEditorLoaded>());

      controller.updateTitle('Updated title');
      controller.updateTranscript('Patient has chest pain.');
      expect((controller.value as NoteEditorLoaded).hasUnsavedChanges, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      await controller.saveNow();

      final saved = await repository.getById(note!.id);
      expect(saved, isNotNull);
      expect(saved!.title, 'Updated title');
      expect(saved.transcript, 'Patient has chest pain.');
      expect((controller.value as NoteEditorLoaded).hasUnsavedChanges, isFalse);
    });

    test(
      'close flushes an unsaved edit before tearing the editor down',
      () async {
        final controller = NoteEditorController(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        final note = await controller.create(
          title: 'Auto save',
          patientName: 'Asha',
          languageCode: 'en',
        );
        controller.updateTitle('Saved on close');

        await controller.close();

        expect((await repository.getById(note!.id))!.title, 'Saved on close');
      },
    );

    test('finalizes and reopens a note', () async {
      final controller = NoteEditorController(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      addTearDown(controller.close);
      final note = await controller.create(
        title: 'Review',
        patientName: 'Asha',
        languageCode: 'en',
      );

      await controller.finalizeNote();
      expect(
        (controller.value as NoteEditorLoaded).note.status,
        NoteStatus.finalized,
      );
      expect(
        (await repository.getById(note!.id))!.status,
        NoteStatus.finalized,
      );

      await controller.reopenNote();
      expect(
        (controller.value as NoteEditorLoaded).note.status,
        NoteStatus.draft,
      );
      expect((await repository.getById(note.id))!.status, NoteStatus.draft);
    });

    test(
      'delete removes the note and does not resurrect it on close',
      () async {
        final controller = NoteEditorController(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        final note = await controller.create(
          title: 'Delete me',
          patientName: 'Asha',
          languageCode: 'en',
        );
        controller.updateTitle('Unsaved change');

        expect(await controller.deleteNote(), isTrue);
        expect(await repository.getById(note!.id), isNull);

        // close() normally flushes unsaved edits. After a delete it must not
        // recreate the row.
        await controller.close();
        expect(await repository.getById(note.id), isNull);
      },
    );

    test('holds structured sections and cleaned transcripts', () async {
      final controller = NoteEditorController(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      addTearDown(controller.close);
      final note = await controller.create(
        title: 'Sections',
        patientName: 'Asha',
        languageCode: 'hi',
      );

      controller.updateSections(
        StructuredNoteSections(chiefComplaint: 'Khansi', assessment: 'Sardi'),
      );
      controller.updateCleanedTranscript('Saaf transcript');
      controller.setThinkingModeUsed(true);
      await controller.saveNow();

      final saved = await repository.getById(note!.id);
      expect(saved!.sections.chiefComplaint, 'Khansi');
      expect(saved.cleanedTranscript, 'Saaf transcript');
      expect(saved.thinkingModeUsed, isTrue);
      expect(saved.languageCode, 'hi');
    });
  });

  group('NoteEditorController save and delete races', () {
    test(
      'a late save cannot recreate a note while delete is in flight',
      () async {
        final repository = MockNoteRepository();
        final note = ClinicalNote.create(
          id: 'note-race',
          title: 'Race',
          patientName: 'Asha',
          languageCode: 'en',
        );
        final saveStarted = Completer<void>();
        final releaseSave = Completer<void>();
        final operations = <String>[];

        when(() => repository.getById(note.id)).thenAnswer((_) async => note);
        when(() => repository.save(any())).thenAnswer((_) async {
          operations.add('save-start');
          saveStarted.complete();
          await releaseSave.future;
          operations.add('save-end');
        });
        when(() => repository.deleteById(note.id)).thenAnswer((_) async {
          operations.add('delete');
        });

        final controller = NoteEditorController(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        await controller.load(note.id);
        controller.updateTitle('Edited');
        final save = controller.saveNow();
        await saveStarted.future;

        final deleteFuture = controller.deleteNote();
        releaseSave.complete();
        expect(await deleteFuture, isTrue);
        await save;
        await controller.close();

        expect(operations, ['save-start', 'save-end', 'delete']);
      },
    );

    test('save failure keeps the edited note and surfaces the error', () async {
      final repository = MockNoteRepository();
      final note = ClinicalNote.create(
        id: 'note-failure',
        title: 'Original',
        patientName: 'Asha',
        languageCode: 'en',
      );

      when(() => repository.getById(note.id)).thenAnswer((_) async => note);
      when(() => repository.save(any())).thenThrow(Exception('disk full'));

      final controller = NoteEditorController(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      await controller.load(note.id);
      controller.updateTitle('Edited but unsaved');

      await controller.saveNow();

      final state = controller.value as NoteEditorLoaded;
      expect(state.note.title, 'Edited but unsaved');
      expect(state.hasUnsavedChanges, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.error, isNotNull);
    });
  });
}
