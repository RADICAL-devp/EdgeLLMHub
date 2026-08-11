import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalRepository extends Mock implements NoteLocalRepository {}

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

void main() {
  late LocalDatabase db;
  late SyncQueueService syncQueueService;
  late _MockLocalRepository localRepository;
  late _MockSyncRepository syncRepository;
  late NoteEditorCubit cubit;

  setUp(() {
    registerFallbackValue(DoctorNote(
      noteId: 'n',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
    db = LocalDatabase.connect(NativeDatabase.memory());
    syncQueueService = SyncQueueService(
      syncRepository: _MockSyncRepository(),
      database: db,
    );
    localRepository = _MockLocalRepository();
    syncRepository = _MockSyncRepository();
    cubit = NoteEditorCubit(
      localRepository: localRepository,
      syncRepository: syncRepository,
      syncQueueService: syncQueueService,
    );

    when(() => syncRepository.syncNoteToBackend('c1'))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
  });

  DoctorNote note({String rawText = 'content'}) {
    return DoctorNote(
      noteId: 'n-c1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('creates a blank note when none exists', () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => <DoctorNote>[]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note(rawText: ''));
    when(() => localRepository.saveNote(any()))
        .thenAnswer((_) async {});

    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    expect(cubit.state, isA<NoteEditorLoaded>());
    verify(() => localRepository.saveNote(any())).called(1);
    expect((cubit.state as NoteEditorLoaded).note.rawText, '');
  });

  test('loads an existing note without creating one', () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());

    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    expect(cubit.state, isA<NoteEditorLoaded>());
    expect((cubit.state as NoteEditorLoaded).note.rawText, 'content');
    verifyNever(() => localRepository.saveNote(any()));
  });

  test('auto-saves after a debounce when text changes', () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());
    when(() => localRepository.saveNote(any())).thenAnswer((_) async {});
    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    cubit.updateText('edited', richTextDelta: '[{"insert":"edited\\n"}]');

    await Future<void>.delayed(const Duration(seconds: 3));

    final loaded = cubit.state as NoteEditorLoaded;
    expect(loaded.note.rawText, 'edited');
    expect(loaded.note.richTextDelta, '[{"insert":"edited\\n"}]');
    verify(() => localRepository.saveNote(any())).called(1);
  });

  test('saveNoteFields persists extracted fields', () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());
    when(() => localRepository.saveNote(any())).thenAnswer((_) async {});
    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    final withFields = (cubit.state as NoteEditorLoaded).note.copyWith(
          extractedFields: const ExtractedFields(
            symptoms: ['cough'],
            provisionalDiagnosis: 'Bronchitis',
          ),
        );
    cubit.saveNoteFields(withFields);

    await Future<void>.delayed(const Duration(seconds: 3));

    final loaded = cubit.state as NoteEditorLoaded;
    expect(loaded.note.extractedFields?.provisionalDiagnosis, 'Bronchitis');
    verify(() => localRepository.saveNote(any())).called(1);
  });

  test('retrySync clears the error and triggers a new sync attempt',
      () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());
    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    cubit.retrySync();
    expect((cubit.state as NoteEditorLoaded).error, isNull);

    await Future<void>.delayed(const Duration(seconds: 4));
    expect((cubit.state as NoteEditorLoaded).isSyncing, isFalse);
    verify(() => syncRepository.syncNoteToBackend('c1')).called(1);
  });

  test('failed sync queues the note offline and surfaces an error',
      () async {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());
    when(() => syncRepository.syncNoteToBackend('c1'))
        .thenThrow(Exception('offline'));

    await cubit.loadOrCreateNote(
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
    );

    await Future<void>.delayed(const Duration(seconds: 4));

    final loaded = cubit.state as NoteEditorLoaded;
    expect(loaded.error, contains('queued for retry'));
    expect(loaded.isSyncing, isFalse);

    final entries = await syncQueueService.getPendingEntries();
    expect(entries, isNotEmpty);
  });
}
