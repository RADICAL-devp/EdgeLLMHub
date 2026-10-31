import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'core/ai/ai_service.dart';
import 'core/ai/edge_ai_service.dart';
import 'core/crypto/phi_encryption_service.dart';
import 'core/data/app_database.dart';
import 'core/data/note_repository.dart';
import 'core/services/audio_capture_service.dart';
import 'core/services/model_manager_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/transcription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native inference and download logs are disabled so no clinical text can
  // reach the console.
  FlutterEdgeAi.logLevel = EdgeAiLogLevel.none;

  final settings = SettingsService();
  await settings.init();

  String? startupError;
  try {
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
      sttBackends: const [LiteRtSttBackend()],
    );
  } catch (error) {
    // The app still opens to a safe explanation instead of a blank screen.
    // Details are only shown in debug builds by DoctorApp.
    startupError = error.toString();
  }

  // A previous session may have been interrupted mid-recording. Audio is
  // temporary, so delete any orphaned recording before the UI can start.
  await AudioCaptureService.deleteStaleTemporaryFiles();

  final database = AppDatabase();
  final encryption = PhiEncryptionService();
  final repository = NoteRepository(database, encryption);
  final models = ModelManagerService(settings: settings);
  final audio = AudioCaptureService();
  final transcription = WhisperTranscriptionService();
  final ai = EdgeAiService();

  final getIt = GetIt.instance;
  getIt.registerSingleton<SettingsService>(settings);
  getIt.registerSingleton<AppDatabase>(database);
  getIt.registerSingleton<PhiEncryptionService>(encryption);
  getIt.registerSingleton<NoteRepository>(repository);
  getIt.registerSingleton<ModelManagerService>(models);
  getIt.registerSingleton<AudioCaptureService>(audio);
  getIt.registerSingleton<TranscriptionService>(transcription);
  getIt.registerSingleton<AIService>(ai);

  runApp(DoctorApp(settings: settings, startupError: startupError));
}
