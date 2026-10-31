import 'dart:async';

import 'package:doctor_app/core/crypto/phi_encryption_service.dart';
import 'package:doctor_app/core/data/app_database.dart';
import 'package:doctor_app/core/data/note_repository.dart';
import 'package:doctor_app/core/models/clinical_note.dart';
import 'package:doctor_app/core/utils/debouncer.dart';
import 'package:doctor_app/features/notes/cubits/note_editor_cubit.dart';
import 'package:doctor_app/features/notes/cubits/note_editor_state.dart';
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

  group('NoteEditorCubit with a real encrypted repository', () {
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
      final cubit = NoteEditorCubit(
        repository: repository,
        debouncer: Debouncer(const Duration(milliseconds: 10)),
      );
      addTearDown(cubit.close);

      final note = await cubit.create(
        title: 'Initial title',
        patientName: 'Asha Rao',
        languageCode: 'en',
      );
      expect(note, isNotNull);
      expect(cubit.state, isA<NoteEditorLoaded>());

      cubit.updateTitle('Updated title');
      cubit.updateTranscript('Patient has chest pain.');
      expect((cubit.state as NoteEditorLoaded).hasUnsavedChanges, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      await cubit.saveNow();

      final saved = await repository.getById(note!.id);
      expect(saved, isNotNull);
      expect(saved!.title, 'Updated title');
      expect(saved.transcript, 'Patient has chest pain.');
      expect((cubit.state as NoteEditorLoaded).hasUnsavedChanges, isFalse);
    });

    test(
      'close flushes an unsaved edit before tearing the editor down',
      () async {
        final cubit = NoteEditorCubit(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        final note = await cubit.create(
          title: 'Auto save',
          patientName: 'Asha',
          languageCode: 'en',
        );
        cubit.updateTitle('Saved on close');

        await cubit.close();

        expect((await repository.getById(note!.id))!.title, 'Saved on close');
      },
    );

    test('finalizes and reopens a note', () async {
      final cubit = NoteEditorCubit(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      addTearDown(cubit.close);
      final note = await cubit.create(
        title: 'Review',
        patientName: 'Asha',
        languageCode: 'en',
      );

      await cubit.finalizeNote();
      expect(
        (cubit.state as NoteEditorLoaded).note.status,
        NoteStatus.finalized,
      );
      expect(
        (await repository.getById(note!.id))!.status,
        NoteStatus.finalized,
      );

      await cubit.reopenNote();
      expect((cubit.state as NoteEditorLoaded).note.status, NoteStatus.draft);
      expect((await repository.getById(note.id))!.status, NoteStatus.draft);
    });

    test(
      'delete removes the note and does not resurrect it on close',
      () async {
        final cubit = NoteEditorCubit(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        final note = await cubit.create(
          title: 'Delete me',
          patientName: 'Asha',
          languageCode: 'en',
        );
        cubit.updateTitle('Unsaved change');

        expect(await cubit.deleteNote(), isTrue);
        expect(await repository.getById(note!.id), isNull);

        // close() normally flushes unsaved edits. After a delete it must not
        // recreate the row.
        await cubit.close();
        expect(await repository.getById(note.id), isNull);
      },
    );

    test('holds structured sections and cleaned transcripts', () async {
      final cubit = NoteEditorCubit(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      addTearDown(cubit.close);
      final note = await cubit.create(
        title: 'Sections',
        patientName: 'Asha',
        languageCode: 'hi',
      );

      cubit.updateSections(
        StructuredNoteSections(chiefComplaint: 'Khansi', assessment: 'Sardi'),
      );
      cubit.updateCleanedTranscript('Saaf transcript');
      cubit.setThinkingModeUsed(true);
      await cubit.saveNow();

      final saved = await repository.getById(note!.id);
      expect(saved!.sections.chiefComplaint, 'Khansi');
      expect(saved.cleanedTranscript, 'Saaf transcript');
      expect(saved.thinkingModeUsed, isTrue);
      expect(saved.languageCode, 'hi');
    });
  });

  group('NoteEditorCubit save and delete races', () {
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

        final cubit = NoteEditorCubit(
          repository: repository,
          debouncer: Debouncer(const Duration(hours: 1)),
        );
        await cubit.load(note.id);
        cubit.updateTitle('Edited');
        final save = cubit.saveNow();
        await saveStarted.future;

        final deleteFuture = cubit.deleteNote();
        releaseSave.complete();
        expect(await deleteFuture, isTrue);
        await save;
        await cubit.close();

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

      final cubit = NoteEditorCubit(
        repository: repository,
        debouncer: Debouncer(const Duration(hours: 1)),
      );
      await cubit.load(note.id);
      cubit.updateTitle('Edited but unsaved');

      await cubit.saveNow();

      final state = cubit.state as NoteEditorLoaded;
      expect(state.note.title, 'Edited but unsaved');
      expect(state.hasUnsavedChanges, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.error, isNotNull);
    });
  });
}
