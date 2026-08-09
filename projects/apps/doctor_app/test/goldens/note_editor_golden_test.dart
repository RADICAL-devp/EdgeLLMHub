import 'package:doctor_app/core/services/speech_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/domain/services/note_assist_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/ai_assist_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/note_editor_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_helpers.dart';

class _MockNoteLocalRepository extends Mock implements NoteLocalRepository {}

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

class _MockSpeechService extends Mock implements SpeechService {}

class _MockNoteAssistService extends Mock implements NoteAssistService {}

void main() {
  late LocalDatabase db;
  late SyncQueueService syncQueueService;
  late _MockNoteLocalRepository localRepository;
  late _MockSpeechService speechService;

  setUp(() {
    registerFallbackValue(DoctorNote(
      noteId: 'n',
      consultationId: 'c',
      patientId: 'p',
      doctorId: 'd',
      rawText: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
    registerFallbackValue((String _) {});
    db = LocalDatabase.connect(NativeDatabase.memory());
    syncQueueService = SyncQueueService(
      syncRepository: _MockSyncRepository(),
      database: db,
    );
    localRepository = _MockNoteLocalRepository();
    speechService = _MockSpeechService();

    GetIt.I.registerSingleton<SyncQueueService>(syncQueueService);
    GetIt.I.registerSingleton<SpeechService>(speechService);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  DoctorNote note() => DoctorNote(
        noteId: 'n-c1',
        consultationId: 'c1',
        patientId: 'p1',
        doctorId: 'd1',
        rawText: 'Patient reports persistent cough for three days.',
        richTextDelta:
            '[{"insert":"Patient reports persistent cough for three days.\\n"}]',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Widget editor() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NoteEditorCubit>(
          create: (_) => NoteEditorCubit(
            localRepository: localRepository,
            syncRepository: _MockSyncRepository(),
            syncQueueService: syncQueueService,
          ),
        ),
        BlocProvider<AiAssistCubit>(
          create: (_) => AiAssistCubit(
            assistService: _MockNoteAssistService(),
          ),
        ),
      ],
      child: const NoteEditorPage(
        consultationId: 'c1',
        patientId: 'p1',
        doctorId: 'd1',
      ),
    );
  }

  void stubNoteLookup() {
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final suffix = brightness == Brightness.dark ? ' dark' : '';
    final nameSuffix = brightness == Brightness.dark ? '_dark' : '';

    testWidgets('editor with content$suffix', (tester) async {
      stubNoteLookup();
      usePhoneViewport(tester);
      await tester.pumpWidget(goldenApp(child: editor(), brightness: brightness));
      // Post-frame content restore runs after the first frame; a few fixed
      // pumps keep the capture deterministic (the Quill caret blinks, so
      // never pumpAndSettle here).
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/note_editor_loaded$nameSuffix.png'),
      );
      await tester.pump(const Duration(seconds: 5));
      await unmountTree(tester);
    });
  }

  testWidgets('editor at 2x text scale does not overflow', (tester) async {
    stubNoteLookup();
    usePhoneViewport(tester, textScale: 2.0);
    await tester.pumpWidget(goldenApp(child: editor()));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final errors = tester.takeException();
    expect(errors, isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/note_editor_loaded_a11y.png'),
    );
    await tester.pump(const Duration(seconds: 5));
    await unmountTree(tester);
  });
}
