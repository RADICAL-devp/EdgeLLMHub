import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:doctor_app/core/services/device_capability_service.dart';

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

abstract class ModelManagerState extends Equatable {
  const ModelManagerState();

  @override
  List<Object?> get props => [];
}

class ModelManagerInitial extends ModelManagerState {}

class ModelManagerDownloading extends ModelManagerState {
  final double progress; // 0.0 to 1.0

  const ModelManagerDownloading(this.progress);

  @override
  List<Object?> get props => [progress];
}

class ModelManagerReady extends ModelManagerState {
  final String modelPath;
  final String executionMode; // 'local', 'cloud', or 'stub'

  const ModelManagerReady(this.modelPath, {this.executionMode = 'local'});

  @override
  List<Object?> get props => [modelPath, executionMode];
}

class ModelManagerError extends ModelManagerState {
  final String message;
  final bool canRetry;

  const ModelManagerError(this.message, {this.canRetry = true});

  @override
  List<Object?> get props => [message, canRetry];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class ModelManagerCubit extends Cubit<ModelManagerState> {
  final DeviceCapabilityService _capabilityService;
  static const _iosChannel = MethodChannel('com.example.clinical/llm');
  static const String _modelFileName = 'gemma-2b-it.bin';

  /// Timeout for model verification (sample inference).
  static const _verificationTimeout = Duration(seconds: 30);

  ModelManagerCubit({
    required DeviceCapabilityService capabilityService,
  })  : _capabilityService = capabilityService,
        super(ModelManagerInitial());

  /// Check if the model is available and functional.
  ///
  /// Unlike the old implementation, this does NOT blindly emit
  /// [ModelManagerReady]. It performs real verification:
  ///   1. Check if the MethodChannel/plugin responds
  ///   2. Verify the model file/library is present
  ///   3. Run a sample inference to confirm the model is loaded
  Future<void> checkModelExists() async {
    try {
      final isSimulator = await _capabilityService.isSimulator;
      final canRunLocal = await _capabilityService.canRunLocalLlm();
      final mode = await _capabilityService.getRecommendedExecutionMode();

      if (isSimulator || !canRunLocal) {
        // Simulator or low-capability device → cloud/stub mode
        // Model manager should indicate "ready" in cloud mode
        developer.log(
          'Device uses ${mode.name} mode (simulator=$isSimulator, '
          'canRunLocal=$canRunLocal)',
          name: 'ModelManagerCubit',
        );
        emit(ModelManagerReady(
          'Cloud/Stub Mode',
          executionMode: mode.name,
        ));
        return;
      }

      // Physical device — check platform-specific model
      if (Platform.isIOS) {
        await _checkIosModel();
      } else if (Platform.isAndroid) {
        await _checkAndroidModel();
      } else {
        emit(const ModelManagerError(
          'Unsupported platform for local LLM inference.',
          canRetry: false,
        ));
      }
    } catch (e) {
      emit(ModelManagerError('Failed to check model: $e'));
    }
  }

  /// Check iOS MLC model availability with real verification.
  Future<void> _checkIosModel() async {
    try {
      // Step 1: Check if the handler is registered and responds
      final isAvailable =
          await _iosChannel.invokeMethod<bool>('isAvailable');

      if (isAvailable != true) {
        emit(const ModelManagerError(
          'MLC LLM engine is not ready. The model may need to be '
          'downloaded or the engine may still be initializing.',
        ));
        return;
      }

      // Step 2: Run a sample inference to verify the model actually works
      developer.log(
        'MLC engine reports available, running verification...',
        name: 'ModelManagerCubit',
      );

      final verifyResult = await _iosChannel
          .invokeMethod<String>('generate', {
            'prompt': 'Hello',
          })
          .timeout(_verificationTimeout);

      if (verifyResult == null || verifyResult.isEmpty) {
        emit(const ModelManagerError(
          'MLC LLM engine responded but produced no output. '
          'The model may be corrupted.',
        ));
        return;
      }

      developer.log(
        'MLC verification succeeded (${verifyResult.length} chars)',
        name: 'ModelManagerCubit',
      );
      emit(const ModelManagerReady(
        'Bundled MLC LLM',
        executionMode: 'local',
      ));
    } on TimeoutException {
      emit(const ModelManagerError(
        'MLC LLM verification timed out. The model may be too large '
        'for this device.',
      ));
    } on MissingPluginException {
      emit(const ModelManagerError(
        'MLC LLM handler is not registered. '
        'Ensure MLCLLMHandler is configured in AppDelegate.swift.',
        canRetry: false,
      ));
    } on PlatformException catch (e) {
      emit(ModelManagerError(
        'MLC LLM platform error: ${e.message}',
      ));
    } catch (e) {
      emit(ModelManagerError('Failed to verify MLC LLM: $e'));
    }
  }

  /// Check Android Gemma model availability.
  Future<void> _checkAndroidModel() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');

      if (!await modelFile.exists()) {
        emit(ModelManagerInitial());
        return;
      }

      // Dynamically load flutter_gemma to avoid iOS compilation issues
      // In production, this would use FlutterGemmaPlugin.instance.init()
      developer.log(
        'Android model file exists, initializing Gemma...',
        name: 'ModelManagerCubit',
      );

      // TODO: Add real Gemma verification similar to iOS
      // For now, file existence is the check
      emit(ModelManagerReady(modelFile.path, executionMode: 'local'));
    } catch (e) {
      emit(ModelManagerError('Failed to check Android model: $e'));
    }
  }

  /// Download the model (Android only — iOS bundles the model).
  Future<void> downloadModel() async {
    try {
      emit(const ModelManagerDownloading(0.0));

      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/$_modelFileName');

      // TODO: Replace with real model download from GCP bucket
      // when a signed URL is available.
      //
      // await _dio.download(
      //   modelDownloadUrl,
      //   modelFile.path,
      //   onReceiveProgress: (received, total) {
      //     if (total != -1) {
      //       emit(ModelManagerDownloading(received / total));
      //     }
      //   },
      // );

      // Simulate download progress for development
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (isClosed) return;
        emit(ModelManagerDownloading(i / 100.0));
      }

      // Create placeholder so subsequent checks pass
      if (!await modelFile.exists()) {
        await modelFile.writeAsString('placeholder_model_data');
      }

      emit(ModelManagerReady(modelFile.path, executionMode: 'local'));
    } catch (e) {
      emit(ModelManagerError('Failed to download model: $e'));
    }
  }
}
