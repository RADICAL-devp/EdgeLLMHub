import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/environment.dart';
import 'core/services/speech_service.dart';
import 'core/services/database_service.dart';
import 'core/services/sync_queue_service.dart';
import 'core/services/device_capability_service.dart';
import 'core/services/speech_service_factory.dart';
import 'core/llm/llm_port_factory.dart';
import 'core/llm/hybrid_llm_adapter.dart';
import 'core/ports/llm_port.dart';
import 'core/ports/transcript_repository.dart';
import 'core/ports/transcript_summary_repository.dart';
import 'core/repositories/drift_transcript_repository.dart';
import 'core/repositories/drift_summary_repository.dart';
import 'core/network/retry_interceptor.dart';
import 'core/network/circuit_breaker.dart';
import 'core/validation/input_validator.dart';

import 'core/application_services/transcript_chunking_service.dart';
import 'core/application_services/transcript_normalization_service.dart';
import 'core/application_services/transcript_cleanup_service.dart';
import 'core/application_services/doctor_note_generation_service.dart';
import 'core/application_services/transcript_summary_aggregation_service.dart';
import 'core/application_services/summary_generation_service.dart';
import 'core/application_services/summary_orchestrator.dart';
import 'core/application_services/clinical_processing_orchestrator.dart';
import 'core/application_services/validation_service.dart';
import 'core/application_services/terminology_assistance_service.dart';

import 'features/note_assist/data/local/local_database.dart';
import 'features/note_assist/data/local/note_local_repository.dart';
import 'features/note_assist/data/remote/note_remote_datasource.dart';
import 'features/note_assist/data/repositories/note_sync_repository.dart';
import 'features/note_assist/data/services/on_device_llm_service.dart';
import 'features/note_assist/domain/services/note_assist_service.dart';
import 'features/note_assist/presentation/cubit/note_editor_cubit.dart';
import 'features/note_assist/presentation/cubit/ai_assist_cubit.dart';
import 'features/note_assist/presentation/pages/consultation_detail_page.dart';
import 'features/note_assist/presentation/pages/model_manager_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const DoctorApp());
}

/// Canonical dependency injection graph.
///
/// Registration order follows dependency flow:
///   1. Platform services (DeviceCapabilityService)
///   2. Database
///   3. Network (Dio + interceptors)
///   4. Speech service
///   5. LLM port (hybrid adapter)
///   6. Repositories
///   7. Application services
///   8. Orchestrators
Future<void> setupDependencies() async {
  final getIt = GetIt.instance;

  // ── 1. Platform services ──────────────────────────────────────────
  final capabilityService = DeviceCapabilityService();
  getIt.registerSingleton<DeviceCapabilityService>(capabilityService);

  // ── 2. Database ───────────────────────────────────────────────────
  final db = LocalDatabase();
  getIt.registerSingleton<LocalDatabase>(db);

  final dbService = DatabaseService(db);
  getIt.registerSingleton<DatabaseService>(dbService);

  // ── 3. Network (Dio + interceptors) ───────────────────────────────
  final circuitBreaker = CircuitBreaker();
  getIt.registerSingleton<CircuitBreaker>(circuitBreaker);

  final dio = Dio(BaseOptions(
    baseUrl: EnvironmentConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
  ));

  // Add interceptors in order: retry → logging (debug only)
  dio.interceptors.add(RetryInterceptor(dio));
  if (EnvironmentConfig.enableNetworkLogging) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  getIt.registerSingleton<Dio>(dio);

  // ── 4. Input validation ───────────────────────────────────────────
  getIt.registerSingleton<InputValidator>(const InputValidator());

  // ── 5. Speech service ─────────────────────────────────────────────
  final speechService = await SpeechServiceFactory.create(
    capabilityService,
    dio: dio,
  );
  getIt.registerSingleton<SpeechService>(speechService);

  // ── 6. LLM port (hybrid adapter) ─────────────────────────────────
  final llmPort = await LlmPortFactory.create(capabilityService, dio: dio);
  getIt.registerSingleton<LlmPort>(llmPort);
  getIt.registerSingleton<HybridLlmAdapter>(llmPort);

  // ── 7. Repositories ───────────────────────────────────────────────
  getIt.registerLazySingleton<NoteLocalRepository>(
      () => NoteLocalRepository(db));

  getIt.registerLazySingleton<NoteRemoteDatasource>(
      () => NoteRemoteDatasource(getIt<Dio>()));

  getIt.registerLazySingleton<NoteSyncRepository>(() => NoteSyncRepository(
      getIt<NoteLocalRepository>(), getIt<NoteRemoteDatasource>()));

  final syncQueue = SyncQueueService(getIt<NoteSyncRepository>());
  syncQueue.startListening();
  getIt.registerSingleton<SyncQueueService>(syncQueue);

  getIt.registerLazySingleton<TranscriptRepository>(
      () => DriftTranscriptRepository(getIt<LocalDatabase>()));
  getIt.registerLazySingleton<TranscriptSummaryRepository>(
      () => DriftSummaryRepository(getIt<LocalDatabase>()));

  // ── 8. AI / NoteAssist service ────────────────────────────────────
  getIt.registerLazySingleton<NoteAssistService>(
      () => OnDeviceLlmService(getIt<LlmPort>()));

  // ── 9. Application services ───────────────────────────────────────
  getIt.registerLazySingleton<TranscriptChunkingService>(
      () => TranscriptChunkingService());
  getIt.registerLazySingleton<TranscriptNormalizationService>(
      () => TranscriptNormalizationService());
  getIt.registerLazySingleton<ValidationService>(() => ValidationService());

  getIt.registerLazySingleton<TranscriptCleanupService>(
    () => TranscriptCleanupService(
      llmPort: getIt<LlmPort>(),
      normalizationService: getIt<TranscriptNormalizationService>(),
    ),
  );
  getIt.registerLazySingleton<TerminologyAssistanceService>(
    () => TerminologyAssistanceService(
      llmPort: getIt<LlmPort>(),
      normalizationService: getIt<TranscriptNormalizationService>(),
    ),
  );
  getIt.registerLazySingleton<SummaryGenerationService>(
    () => SummaryGenerationService(llmPort: getIt<LlmPort>()),
  );
  getIt.registerLazySingleton<DoctorNoteGenerationService>(
    () => DoctorNoteGenerationService(llmPort: getIt<LlmPort>()),
  );
  getIt.registerLazySingleton<TranscriptSummaryAggregationService>(
    () => TranscriptSummaryAggregationService(),
  );
  getIt.registerLazySingleton<SummaryOrchestrator>(() => SummaryOrchestrator(
        validationService: getIt<ValidationService>(),
        normalizationService: getIt<TranscriptNormalizationService>(),
        chunkingService: getIt<TranscriptChunkingService>(),
        summaryGenerationService: getIt<SummaryGenerationService>(),
        doctorNoteGenerationService: getIt<DoctorNoteGenerationService>(),
        aggregationService: getIt<TranscriptSummaryAggregationService>(),
        transcriptRepository: getIt<TranscriptRepository>(),
        summaryRepository: getIt<TranscriptSummaryRepository>(),
      ));
  getIt.registerLazySingleton<ClinicalProcessingOrchestrator>(
      () => ClinicalProcessingOrchestrator(
            validationService: getIt<ValidationService>(),
            terminologyAssistanceService:
                getIt<TerminologyAssistanceService>(),
            transcriptCleanupService: getIt<TranscriptCleanupService>(),
          ));
}

// ═══════════════════════════════════════════════════════════════════════════
// Router
// ═══════════════════════════════════════════════════════════════════════════

final GoRouter _router = GoRouter(
  initialLocation: '/model_manager',
  routes: [
    GoRoute(
      path: '/model_manager',
      builder: (context, state) => const ModelManagerPage(),
    ),
    GoRoute(
      path: '/consultation/:consultationId/patient/:patientId/doctor/:doctorId',
      builder: (context, state) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => NoteEditorCubit(
                localRepository: GetIt.I<NoteLocalRepository>(),
                syncRepository: GetIt.I<NoteSyncRepository>(),
                syncQueueService: GetIt.I<SyncQueueService>(),
              ),
            ),
            BlocProvider(
              create: (context) => AiAssistCubit(
                assistService: GetIt.I<NoteAssistService>(),
              ),
            ),
          ],
          child: ConsultationDetailPage(
            consultationId: state.pathParameters['consultationId']!,
            patientId: state.pathParameters['patientId']!,
            doctorId: state.pathParameters['doctorId']!,
          ),
        );
      },
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════════════════
// App Widget
// ═══════════════════════════════════════════════════════════════════════════

class DoctorApp extends StatefulWidget {
  const DoctorApp({super.key});

  @override
  State<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends State<DoctorApp> {
  @override
  void initState() {
    super.initState();
    // Show AI risk disclaimer on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAiDisclaimerIfNeeded();
    });
  }

  Future<void> _showAiDisclaimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAcknowledged = prefs.getBool('ai_disclaimer_acknowledged') ?? false;

    if (!hasAcknowledged && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.smart_toy, size: 48, color: Colors.blue),
          title: const Text('AI-Assisted Clinical Notes'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This application uses AI to assist with clinical documentation. '
                  'Please be aware of the following:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                _DisclaimerPoint(
                  icon: Icons.edit_note,
                  text: 'AI-generated notes are drafts and must be reviewed '
                      'by a qualified healthcare professional before use.',
                ),
                SizedBox(height: 8),
                _DisclaimerPoint(
                  icon: Icons.security,
                  text: 'Patient data is processed on-device by default. '
                      'No protected health information (PHI) leaves your device '
                      'unless explicitly configured.',
                ),
                SizedBox(height: 8),
                _DisclaimerPoint(
                  icon: Icons.warning_amber,
                  text: 'AI may produce inaccurate or incomplete information. '
                      'Always verify clinical details independently.',
                ),
                SizedBox(height: 8),
                _DisclaimerPoint(
                  icon: Icons.gavel,
                  text: 'Use of this tool does not replace professional medical '
                      'judgment. The clinician remains fully responsible for '
                      'all clinical decisions.',
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await prefs.setBool('ai_disclaimer_acknowledged', true);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Doctor Note App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

/// A single point in the AI disclaimer dialog.
class _DisclaimerPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisclaimerPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
