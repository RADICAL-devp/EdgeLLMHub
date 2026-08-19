import 'package:doctor_app/core/services/speech_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/domain/services/note_assist_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/ai_assist_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_state.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/note_editor_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteLocalRepository extends Mock implements NoteLocalRepository {}

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

class _MockSpeechService extends Mock implements SpeechService {}

class _MockNoteAssistService extends Mock implements NoteAssistService {}

class _MockLlmPort extends Mock implements LlmPort {}

void main() {
  late LocalDatabase db;
  late SyncQueueService syncQueueService;
  late _MockNoteLocalRepository localRepository;
  late _MockSyncRepository syncRepository;
  late _MockSpeechService speechService;
  late _MockNoteAssistService assistService;
  late _MockLlmPort llmPort;

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
    registerFallbackValue(ProcessingMode.cleanTranscript);
    registerFallbackValue(StructuredSummary());
    db = LocalDatabase.connect(NativeDatabase.memory());
    syncQueueService = SyncQueueService(
      syncRepository: _MockSyncRepository(),
      database: db,
    );
    localRepository = _MockNoteLocalRepository();
    syncRepository = _MockSyncRepository();
    speechService = _MockSpeechService();
    assistService = _MockNoteAssistService();
    llmPort = _MockLlmPort();

    GetIt.I.registerSingleton<SyncQueueService>(syncQueueService);
    GetIt.I.registerSingleton<SpeechService>(speechService);
    GetIt.I.registerSingleton<LlmPort>(llmPort);

    when(() => syncRepository.syncNoteToBackend('c1'))
        .thenAnswer((_) async {});
    when(() => llmPort.processText(any(), any()))
        .thenAnswer((_) async => 'Mock response');
    when(() => llmPort.generateField(any(), any(), patientContext: any(named: 'patientContext')))
        .thenAnswer((_) async => 'Mock field response');
    when(() => llmPort.generateFieldStream(any(), any(), patientContext: any(named: 'patientContext')))
        .thenAnswer((_) => Stream.value('Mock field response'));
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  DoctorNote note({
    String rawText = 'Patient reports persistent cough.',
    String? richTextDelta = '[{"insert":"Patient reports persistent cough.\\n"}]',
  }) {
    return DoctorNote(
      noteId: 'n-c1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      richTextDelta: richTextDelta,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  // Drift's watch() stream schedules a zero-duration timer when the
  // StreamBuilder is disposed. Unmounting the tree and pumping lets the
  // fake clock flush that timer before the pending-timer check.
  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<NoteEditorCubit> pumpEditor(WidgetTester tester) async {    final cubit = NoteEditorCubit(
      localRepository: localRepository,
      syncRepository: syncRepository,
      syncQueueService: syncQueueService,
    );
    when(() => localRepository.getNotesForConsultation('c1'))
        .thenAnswer((_) async => [note()]);
    when(() => localRepository.getNoteByConsultationId('c1'))
        .thenAnswer((_) async => note());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: MultiBlocProvider(
          providers: [
            BlocProvider<NoteEditorCubit>.value(value: cubit),
            BlocProvider<AiAssistCubit>(
              create: (_) => AiAssistCubit(assistService: assistService),
            ),
          ],
          child: const NoteEditorPage(
            consultationId: 'c1',
            patientId: 'p1',
            doctorId: 'd1',
          ),
        ),
      ),
    );
    // Let the cubit load, then run the post-frame content restore. Avoid
    // pumpAndSettle: the sync indicator animates indefinitely.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return cubit;
  }

  testWidgets('restores note content and shows word count', (tester) async {
    final cubit = await pumpEditor(tester);
    expect(cubit.state, isA<NoteEditorLoaded>());

    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    expect(find.textContaining('words'), findsOneWidget);
    expect(find.textContaining('4 words'), findsOneWidget);

    // Flush autosave + sync debounce timers before teardown.
    await tester.pump(const Duration(seconds: 5));
    await unmountTree(tester);
    await cubit.close();
  });

  testWidgets('typing updates cubit with plain text and rich-text delta',
      (tester) async {
    final cubit = await pumpEditor(tester);

    // flutter_quill renders a custom RawEditor (no EditableText), so drive
    // the document through the exposed controller — exactly what the editor
    // does on user input. Edits must stop before the trailing newline.
    final editor =
        tester.widget<QuillEditor>(find.byType(QuillEditor));
    editor.controller.replaceText(
      0,
      editor.controller.document.length - 1,
      'New note content',
      const TextSelection.collapsed(offset: 16),
    );
    await tester.pump();

    final loaded = cubit.state as NoteEditorLoaded;
    expect(loaded.note.rawText, 'New note content\n');
    expect(loaded.note.richTextDelta, isNotNull);
    expect(loaded.note.richTextDelta, contains('New note content'));

    await tester.pump(const Duration(seconds: 5));
    await unmountTree(tester);
    await cubit.close();
  });

  testWidgets('FAB starts dictation through the speech service',
      (tester) async {
    final cubit = await pumpEditor(tester);
    when(() => speechService.startListening(any()))
        .thenAnswer((_) async {});
    when(() => speechService.stopListening()).thenAnswer((_) async {});

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    verify(() => speechService.startListening(any())).called(1);
    expect((cubit.state as NoteEditorLoaded).isListening, isTrue);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    verify(() => speechService.stopListening()).called(1);
    expect((cubit.state as NoteEditorLoaded).isListening, isFalse);

    await tester.pump(const Duration(seconds: 5));
    await unmountTree(tester);
    await cubit.close();
  });
}
