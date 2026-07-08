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
