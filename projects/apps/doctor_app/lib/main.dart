import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'core/services/speech_service.dart';
import 'features/note_assist/data/local/local_database.dart';
import 'features/note_assist/data/local/note_local_repository.dart';
import 'features/note_assist/presentation/cubit/note_editor_cubit.dart';
import 'features/note_assist/presentation/cubit/ai_assist_cubit.dart';
import 'package:dio/dio.dart';
import 'features/note_assist/data/remote/note_remote_datasource.dart';
import 'features/note_assist/data/repositories/note_sync_repository.dart';
import 'features/note_assist/domain/services/note_assist_service.dart';
import 'features/note_assist/data/services/on_device_llm_service.dart';
import 'features/note_assist/presentation/pages/consultation_detail_page.dart';
import 'features/note_assist/presentation/pages/model_manager_page.dart';

import 'core/ports/llm_port.dart';
import 'core/llm/native_llm_adapter.dart';
import 'core/ports/transcript_repository.dart';
import 'core/ports/transcript_summary_repository.dart';
import 'core/repositories/drift_transcript_repository.dart';
import 'core/repositories/drift_summary_repository.dart';
import 'core/services/device_capability_service.dart';
import 'core/application_services/transcript_chunking_service.dart';
import 'core/application_services/summary_generation_service.dart';
import 'core/application_services/summary_orchestrator.dart';
import 'core/application_services/clinical_processing_orchestrator.dart';
import 'core/application_services/validation_service.dart';
import 'core/application_services/terminology_assistance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const DoctorApp());
}

Future<void> setupDependencies() async {
  final getIt = GetIt.instance;

  // Services
  final speechService = SpeechService();
  await speechService.initialize();
  getIt.registerSingleton<SpeechService>(speechService);

  // Database
  final db = LocalDatabase();
  getIt.registerSingleton<LocalDatabase>(db);

  // Repositories
  getIt.registerLazySingleton<NoteLocalRepository>(() => NoteLocalRepository(db));
  
  getIt.registerLazySingleton<Dio>(() => Dio(BaseOptions(baseUrl: 'http://localhost:8080')));
  getIt.registerLazySingleton<NoteRemoteDatasource>(() => NoteRemoteDatasource(getIt<Dio>()));
  getIt.registerLazySingleton<NoteSyncRepository>(
    () => NoteSyncRepository(getIt<NoteLocalRepository>(), getIt<NoteRemoteDatasource>())
  );

  // AI Service
  getIt.registerLazySingleton<NoteAssistService>(() => OnDeviceLlmService());

  // Clinical Intelligence Core Services
  getIt.registerLazySingleton<DeviceCapabilityService>(() => DeviceCapabilityService());
  getIt.registerLazySingleton<LlmPort>(() => NativeLlmAdapter());
  getIt.registerLazySingleton<TranscriptRepository>(() => DriftTranscriptRepository(getIt<LocalDatabase>()));
  getIt.registerLazySingleton<TranscriptSummaryRepository>(() => DriftSummaryRepository(getIt<LocalDatabase>()));
  
  getIt.registerLazySingleton<TranscriptChunkingService>(() => TranscriptChunkingService());
  getIt.registerLazySingleton<ValidationService>(() => ValidationService());
  getIt.registerLazySingleton<TerminologyAssistanceService>(() => TerminologyAssistanceService(getIt<LlmPort>()));
  getIt.registerLazySingleton<SummaryGenerationService>(() => SummaryGenerationService(getIt<LlmPort>(), getIt<TerminologyAssistanceService>()));
  getIt.registerLazySingleton<SummaryOrchestrator>(() => SummaryOrchestrator(
        llmPort: getIt<LlmPort>(),
        transcriptRepo: getIt<TranscriptRepository>(),
        summaryRepo: getIt<TranscriptSummaryRepository>(),
        chunkingService: getIt<TranscriptChunkingService>(),
        generationService: getIt<SummaryGenerationService>(),
      ));
  getIt.registerLazySingleton<ClinicalProcessingOrchestrator>(() => ClinicalProcessingOrchestrator(
        llmPort: getIt<LlmPort>(),
        summaryOrchestrator: getIt<SummaryOrchestrator>(),
        validationService: getIt<ValidationService>(),
      ));
}

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

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

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
