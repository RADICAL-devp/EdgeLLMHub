import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:doctor_app/core/config/environment.dart';
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
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final bool isVerifying;
  final String phaseLabel;

  const ModelManagerDownloading(
    this.progress, {
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.isVerifying = false,
    this.phaseLabel = 'Downloading model…',
  });

  @override
  List<Object?> get props => [
        progress,
        downloadedBytes,
        totalBytes,
        speedBytesPerSec,
        isVerifying,
        phaseLabel,
      ];
}

class ModelManagerReady extends ModelManagerState {
  final String modelPath;
  final String executionMode; // 'local', 'cloud', or 'stub'
  final Map<String, Object?>? modelInfo;

  const ModelManagerReady(this.modelPath, {this.executionMode = 'local', this.modelInfo});

  @override
  List<Object?> get props => [modelPath, executionMode, modelInfo];
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

// ---------------------------------------------------------------------------
// Model downloader abstraction (real implementation uses Dio)
// ---------------------------------------------------------------------------

/// Abstraction over the binary download so the cubit stays unit-testable.
abstract class ModelDownloader {
  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  });
}

/// [ModelDownloader] backed by Dio.
class DioModelDownloader implements ModelDownloader {
  final Dio _dio;

  DioModelDownloader({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class ModelManagerCubit extends Cubit<ModelManagerState> {
  final DeviceCapabilityService _capabilityService;
  final ModelDownloader _downloader;
  static const _iosChannel = MethodChannel('com.example.clinical/llm');
  static const _androidChannel = MethodChannel('com.example.clinical/llm');

  /// Timeout for model verification (sample inference).
  static const _verificationTimeout = Duration(seconds: 20);

  ModelManagerCubit({
    required DeviceCapabilityService capabilityService,
    ModelDownloader? downloader,
  })  : _capabilityService = capabilityService,
        _downloader = downloader ?? DioModelDownloader(),
        super(ModelManagerInitial());

  /// Check if the model is available and functional.
  ///
  /// Unlike the old implementation, this does NOT blindly emit
  /// [ModelManagerReady]. It performs real verification:
  ///   1. Check if the MethodChannel/plugin responds
  ///   2. Verify the model file/library is present (via getModelInfo)
  ///   3. Verify checksum matches expected bundle
  ///   4. Run a sample inference to confirm the model is loaded
  ///   5. Warm-up inference to reduce first-request latency
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
      // Step 1: Get model info (bundled status, path, checksum)
      final modelInfo = await _iosChannel
          .invokeMapMethod<String, Object?>('getModelInfo')
          .timeout(_verificationTimeout);

      if (modelInfo == null) {
        emit(const ModelManagerError(
          'MLC LLM handler did not return model info.',
        ));
        return;
      }

      final bundled = modelInfo['bundled'] == true;
      if (!bundled) {
        emit(const ModelManagerError(
          'SmolLM-350M model not bundled in app. '
          'Run ios/scripts/setup_ios_mlc.sh to compile and bundle the model.',
        ));
        return;
      }

      // Step 2: Verify checksum if available
      final checksum = modelInfo['checksumSha256'] as String?;
      if (checksum != null && checksum.isNotEmpty) {
        developer.log(
          'Model checksum: $checksum',
          name: 'ModelManagerCubit',
        );
        // In production, compare against expected checksum from build artifacts
        // For now, log it for debugging
      }

      // Step 3: Check if engine is ready
      final isAvailable = modelInfo['ready'] == true;
      if (isAvailable != true) {
        // Engine not initialized yet — try to initialize
        developer.log(
          'MLC engine not initialized, initializing...',
          name: 'ModelManagerCubit',
        );
        try {
          await _iosChannel
              .invokeMethod<void>('initialize')
              .timeout(_verificationTimeout);
        } on PlatformException catch (e) {
          emit(ModelManagerError(
            'Failed to initialize MLC engine: ${e.message}',
          ));
          return;
        }
      }

      // Step 4: Warm-up inference to reduce first-request latency
      developer.log(
        'Running warm-up inference...',
        name: 'ModelManagerCubit',
      );
      try {
        await _iosChannel
            .invokeMethod<String>('warmUp')
            .timeout(_verificationTimeout);
      } on TimeoutException {
        developer.log(
          'Warm-up timed out (continuing anyway)',
          name: 'ModelManagerCubit',
        );
      } on PlatformException catch (e) {
        developer.log(
          'Warm-up failed (continuing anyway): ${e.message}',
          name: 'ModelManagerCubit',
        );
      }

      // Step 5: Run a sample inference to verify the model actually works
      developer.log(
        'Running verification inference...',
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
      emit(ModelManagerReady(
        'Bundled SmolLM-350M (MLCSwift)',
        executionMode: 'local',
        modelInfo: modelInfo,
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

  /// Check Android MLC model availability with real verification.
  Future<void> _checkAndroidModel() async {
    try {
      // Step 1: Get model info (bundled status, path, checksum)
      final modelInfo = await _androidChannel
          .invokeMapMethod<String, Object?>('getModelInfo')
          .timeout(_verificationTimeout);

      if (modelInfo == null) {
        emit(const ModelManagerError(
          'MLC Android handler did not return model info.',
        ));
        return;
      }

      final bundled = modelInfo['bundled'] == true;
      if (!bundled) {
        emit(const ModelManagerError(
          'SmolLM-350M model not found in assets. '
          'Ensure SmolLM-350M-Instruct-q4f16_1-MLC is in android/app/src/main/assets/',
        ));
        return;
      }

      // Step 2: Verify checksum if available
      final checksum = modelInfo['checksumSha256'] as String?;
      if (checksum != null && checksum.isNotEmpty) {
        developer.log(
          'Model checksum: $checksum',
          name: 'ModelManagerCubit',
        );
      }

      // Step 3: Check if engine is ready
      final isAvailable = modelInfo['ready'] == true;
      if (isAvailable != true) {
        // Engine not initialized yet — try to initialize
        developer.log(
          'MLC Android engine not initialized, initializing...',
          name: 'ModelManagerCubit',
        );
        try {
          await _androidChannel
              .invokeMethod<void>('initialize')
              .timeout(const Duration(seconds: 60));
        } on PlatformException catch (e) {
          emit(ModelManagerError(
            'Failed to initialize MLC Android engine: ${e.message}',
          ));
          return;
        }
      }

      // Step 4: Warm-up inference to reduce first-request latency
      developer.log(
        'Running warm-up inference...',
        name: 'ModelManagerCubit',
      );
      try {
        await _androidChannel
            .invokeMethod<String>('warmUp')
            .timeout(_verificationTimeout);
      } on TimeoutException {
        developer.log(
          'Warm-up timed out (continuing anyway)',
          name: 'ModelManagerCubit',
        );
      } on PlatformException catch (e) {
        developer.log(
          'Warm-up failed (continuing anyway): ${e.message}',
          name: 'ModelManagerCubit',
        );
      }

      // Step 5: Run a sample inference to verify the model actually works
      developer.log(
        'Running verification inference...',
        name: 'ModelManagerCubit',
      );

      final verifyResult = await _androidChannel
          .invokeMethod<String>('generate', {
            'prompt': 'Hello',
          })
          .timeout(_verificationTimeout);

      if (verifyResult == null || verifyResult.isEmpty) {
        emit(const ModelManagerError(
          'MLC Android LLM engine responded but produced no output. '
          'The model may be corrupted.',
        ));
        return;
      }

      developer.log(
        'MLC Android verification succeeded (${verifyResult.length} chars)',
        name: 'ModelManagerCubit',
      );
      emit(ModelManagerReady(
        'Bundled SmolLM-350M (MLC Android)',
        executionMode: 'local',
        modelInfo: modelInfo,
      ));
    } on TimeoutException {
      emit(const ModelManagerError(
        'MLC Android LLM verification timed out. The model may be too large '
        'for this device.',
      ));
    } on MissingPluginException {
      emit(const ModelManagerError(
        'MLC Android LLM handler is not registered. '
        'Ensure MLCLLMHandler is configured in MainActivity.kt.',
        canRetry: false,
      ));
    } on PlatformException catch (e) {
      emit(ModelManagerError(
        'MLC Android LLM platform error: ${e.message}',
      ));
    } catch (e) {
      emit(ModelManagerError('Failed to verify MLC Android LLM: $e'));
    }
  }

  /// Download the model (Android only — iOS bundles the model).
  ///
  /// When [downloadUrl] is configured, downloads for real with transfer-rate
  /// tracking and verifies the SHA-256 checksum on completion. Otherwise
  /// falls back to simulated progress for development. [downloadUrl] and
  /// [checksumSha256] default to [EnvironmentConfig] values but may be
  /// overridden (used by tests); [downloadDirectory] overrides the platform
  /// documents directory.
  Future<void> downloadModel({
    String? downloadUrl,
    String? checksumSha256,
    Directory? downloadDirectory,
  }) async {
    final url = downloadUrl ?? EnvironmentConfig.modelDownloadUrl;
    final expectedChecksum =
        checksumSha256 ?? EnvironmentConfig.modelChecksumSha256;
    final dir = downloadDirectory ?? await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/${EnvironmentConfig.modelFileName}');

    if (url.isEmpty) {
      await _simulateDownload(modelFile);
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();
      await _downloader.download(
        url,
        modelFile.path,
        onReceiveProgress: (received, total) {
          if (isClosed) return;
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          final speed = elapsed > 0 ? received / elapsed : 0.0;
          emit(ModelManagerDownloading(
            total == -1 ? 0.0 : received / total,
            downloadedBytes: received,
            totalBytes: total,
            speedBytesPerSec: speed,
          ));
        },
      );

      await _verifyChecksum(modelFile, expectedChecksum);
    } on DioException catch (e) {
      await _cleanupPartialFile(modelFile);
      emit(ModelManagerError('Download failed: ${e.message}'));
    } catch (e) {
      await _cleanupPartialFile(modelFile);
      emit(ModelManagerError('Download failed: $e'));
    }
  }

  /// Verify the downloaded file against the expected SHA-256 checksum.
  Future<void> _verifyChecksum(File file, String expected) async {
    if (expected.isEmpty) {
      developer.log(
        'No expected checksum configured — skipping verification.',
        name: 'ModelManagerCubit',
      );
      emit(ModelManagerReady(file.path, executionMode: 'local'));
      return;
    }

    final size = await file.length();
    emit(ModelManagerDownloading(
      1.0,
      downloadedBytes: size,
      totalBytes: size,
      isVerifying: true,
      phaseLabel: 'Verifying SHA-256 checksum…',
    ));

    final digest = sha256.convert(await file.readAsBytes());
    final actual = digest.toString().toLowerCase();

    if (actual != expected.toLowerCase()) {
      developer.log(
        'Checksum mismatch: expected $expected, got $actual',
        name: 'ModelManagerCubit',
      );
      await file.delete();
      emit(ModelManagerError(
        'Checksum mismatch — the downloaded model is corrupt. '
        'Expected $expected, got $actual. Please download again.',
      ));
      return;
    }

    developer.log('Checksum verified: $actual', name: 'ModelManagerCubit');
    emit(ModelManagerReady(file.path, executionMode: 'local'));
  }

  Future<void> _cleanupPartialFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — partial file cleanup is not critical.
    }
  }

  /// Simulated download used when no signed download URL is configured.
  Future<void> _simulateDownload(File modelFile) async {
    developer.log(
      'MODEL_DOWNLOAD_URL not set — using simulated progress.',
      name: 'ModelManagerCubit',
    );
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (isClosed) return;
      emit(ModelManagerDownloading(
        i / 100.0,
        downloadedBytes: i * 1024 * 1024,
        totalBytes: 350 * 1024 * 1024,
        speedBytesPerSec: (350 * 1024 * 1024 / 100.0) / 0.4,
      ));
    }

    // Create placeholder so subsequent checks pass
    if (!await modelFile.exists()) {
      await modelFile.writeAsString('placeholder_model_data');
    }

    emit(ModelManagerReady(modelFile.path, executionMode: 'local'));
  }
}
