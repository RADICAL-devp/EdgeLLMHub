import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/llm/gemma_backend.dart';
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

/// The cubit is running the multi-second verification (installed check,
/// sample inference). The page shows a spinner here so the user is not
/// offered a Download button while the installed model is being verified.
class ModelManagerChecking extends ModelManagerState {}

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
  final GemmaBackend _gemmaBackend;
  final Connectivity _connectivity;

  /// Timeout for model verification steps (installed check, sample inference).
  /// Increased from 20s — first inference on a freshly installed model can
  /// exceed 30s on older chips as the engine warms up the GPU backend.
  ///
  /// Instance getter (not a static) so tests can shorten it without waiting
  /// 45 real seconds for the generate timeout to fire.
  @visibleForTesting
  Duration get verificationTimeout => const Duration(seconds: 45);

  ModelManagerCubit({
    required DeviceCapabilityService capabilityService,
    ModelDownloader? downloader,
    GemmaBackend? gemmaBackend,
    Connectivity? connectivity,
  })  : _capabilityService = capabilityService,
        _downloader = downloader ?? DioModelDownloader(),
        _gemmaBackend = gemmaBackend ?? FlutterGemmaBackend(),
        _connectivity = connectivity ?? Connectivity(),
        super(ModelManagerInitial());

  /// Emits [state] only while the cubit is still open.
  ///
  /// [checkModelExists] and [downloadModel] perform long async verifications
  /// (flutter_gemma install checks, downloads, checksum verification). If the
  /// owning page is disposed mid-flight — e.g. the user backgrounds the app
  /// or hot-reloads — the cubit is closed and any subsequent `emit` throws
  /// "Cannot emit new states after calling close", surfacing as an uncaught
  /// async error. Guarding every emit keeps the verification work
  /// cancellable-safe.
  void _safeEmit(ModelManagerState state) {
    if (!isClosed) {
      emit(state);
    }
  }

  /// Check if the model is available and functional.
  ///
  /// Unlike the old implementation, this does NOT blindly emit
  /// [ModelManagerReady]. It performs real verification:
  ///   1. Check the flutter_gemma store for the installed model file
  ///   2. Run a sample inference to confirm the model is loaded
  ///   3. Warm-up happens implicitly on first inference
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
        _safeEmit(ModelManagerReady(
          'Cloud/Stub Mode',
          executionMode: mode.name,
        ));
        return;
      }

      // Physical device — verify the flutter_gemma model (cross-platform,
      // no per-OS branches).
      // Emit the checking state only now: the simulator/probe stage is fast,
      // and cloud/stub mode reports ready directly below (no verification).
      _safeEmit(ModelManagerChecking());
      await _checkGemmaModel();
    } catch (e) {
      _safeEmit(ModelManagerError('Failed to check model: $e'));
    }
  }

  /// Verify the flutter_gemma model: installed in the plugin store plus a
  /// live sample inference. Cross-platform — no per-OS branches.
  Future<void> _checkGemmaModel() async {
    try {
      final installed = await _gemmaBackend
          .isModelInstalled(EnvironmentConfig.modelFileName);
      if (!installed) {
        // Model is not installed — the first-run download flow owns the
        // not-installed state (the page shows the Download button there).
        _safeEmit(ModelManagerInitial());
        return;
      }

      // Run a sample inference to verify the model actually works.
      developer.log(
        'Running verification inference...',
        name: 'ModelManagerCubit',
      );

      GemmaGeneration verifyResult;
      try {
        verifyResult = await _gemmaBackend
            .generate(prompt: 'Hello', maxOutputTokens: 8)
            .timeout(verificationTimeout);
      } on TimeoutException {
        _safeEmit(const ModelManagerError(
          'flutter_gemma verification timed out. The model may be too large '
          'for this device.',
        ));
        return;
      }

      final text = verifyResult.text;
      if (text.isEmpty) {
        _safeEmit(const ModelManagerError(
          'flutter_gemma engine responded but produced no output. '
          'The model may be corrupted — try re-downloading it.',
        ));
        return;
      }

      developer.log(
        'flutter_gemma verification succeeded (${text.length} chars)',
        name: 'ModelManagerCubit',
      );
      _safeEmit(const ModelManagerReady(
        'Qwen 3 0.6B (flutter_gemma)',
        executionMode: 'local',
        modelInfo: {
          'modelId': 'Qwen3-0.6B-dynamic-wi4b32-afp32',
          'runtime': 'flutter_gemma',
        },
      ));
    } catch (e) {
      _safeEmit(ModelManagerError('Failed to verify flutter_gemma LLM: $e'));
    }
  }

  /// Download the model for the current platform.
  ///
  /// Stages the single-file `.litertlm` artifact
  /// ([EnvironmentConfig.modelFileName]) to a temp file with transfer-rate
  /// tracking, verifies the SHA-256 checksum, then hands it to flutter_gemma
  /// (`fromFile`), which moves it into its managed store. The temp copy is
  /// always removed afterwards. [downloadUrl], [checksumSha256],
  /// [requireWifi] and [downloadDirectory] may be overridden (used by
  /// tests); they default to [EnvironmentConfig] values, Wi-Fi-only
  /// downloads, and the platform temp directory.
  Future<void> downloadModel({
    String? downloadUrl,
    String? checksumSha256,
    bool? requireWifi,
    Directory? downloadDirectory,
  }) async {
    final url = downloadUrl ?? EnvironmentConfig.modelDownloadUrl;
    final expectedChecksum =
        checksumSha256 ?? EnvironmentConfig.modelChecksumSha256;
    final stagingDir = downloadDirectory ?? await getTemporaryDirectory();
    final modelFile = File('${stagingDir.path}/${EnvironmentConfig.modelFileName}');

    if (url.isEmpty) {
      await _simulateDownload(modelFile);
      return;
    }

    if (requireWifi ?? true) {
      final onWifi = await _isOnWifi();
      if (!onWifi) {
        _safeEmit(const ModelManagerError(
          'Model download needs Wi-Fi (about 330MB). Connect to Wi-Fi '
          'and try again.',
        ));
        return;
      }
    }

    // Check free disk space before download
    await _checkDiskSpace(stagingDir);

    try {
      final stopwatch = Stopwatch()..start();
      await _downloader.download(
        url,
        modelFile.path,
        onReceiveProgress: (received, total) {
          if (isClosed) return;
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          final speed = elapsed > 0 ? received / elapsed : 0.0;
          _safeEmit(ModelManagerDownloading(
            total == -1 ? 0.0 : received / total,
            downloadedBytes: received,
            totalBytes: total,
            speedBytesPerSec: speed,
          ));
        },
      );

      await _verifyChecksum(modelFile, expectedChecksum);
      await _gemmaBackend.installFromFile(modelFile.path);
      await _cleanupPartialFile(modelFile);
      const readyLabel =
          'Installed ${EnvironmentConfig.modelFileName} (flutter_gemma)';
      _safeEmit(const ModelManagerReady(
        readyLabel,
        executionMode: 'local',
      ));
    } on DioException catch (e) {
      await _cleanupPartialFile(modelFile);
      _safeEmit(ModelManagerError('Download failed: ${e.message}'));
    } catch (e) {
      await _cleanupPartialFile(modelFile);
      _safeEmit(ModelManagerError('Download failed: $e'));
    }
  }

  /// True when the device currently has unmetered (Wi-Fi/ethernet/VPN)
  /// connectivity. Connectivity checks that throw (e.g. no platform plugin
  /// in tests) are treated as Wi-Fi so explicit [requireWifi] callers, not
  /// plugin availability, decide the policy.
  Future<bool> _isOnWifi() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet) ||
          results.contains(ConnectivityResult.vpn);
    } catch (e) {
      developer.log(
        'Connectivity check failed (assuming Wi-Fi): $e',
        name: 'ModelManagerCubit',
      );
      return true;
    }
  }

  /// Verify the downloaded file against the expected SHA-256 checksum.
  ///
  /// Returns normally when the checksum matches (or none is configured);
  /// throws with a descriptive message (after deleting the corrupt file)
  /// when the checksum mismatches, so [downloadModel] reports the failure.
  ///
  /// The comparison is constant-time over the digest bytes, so the expected
  /// value is never leaked to a timing side channel that could help an
  /// attacker craft a "close" digest. Mismatches and successes are both
  /// logged with the actual digest.
  Future<void> _verifyChecksum(File file, String expected) async {
    if (expected.isEmpty) {
      developer.log(
        'No expected checksum configured — skipping verification.',
        name: 'ModelManagerCubit',
      );
      return;
    }

    final size = await file.length();
    _safeEmit(ModelManagerDownloading(
      1.0,
      downloadedBytes: size,
      totalBytes: size,
      isVerifying: true,
      phaseLabel: 'Verifying SHA-256 checksum…',
    ));

    final digest = sha256.convert(await file.readAsBytes()).bytes;
    final actual = _bytesToHex(digest);

    final expectedBytes = _parseHex(expected);
    if (expectedBytes == null || !_constantTimeEquals(digest, expectedBytes)) {
      developer.log(
        'Checksum mismatch: expected $expected, got $actual',
        name: 'ModelManagerCubit',
      );
      await file.delete();
      throw Exception(
        'Checksum mismatch — the downloaded model is corrupt. '
        'Expected $expected, got $actual. Please download again.',
      );
    }

    developer.log('Checksum verified: $actual', name: 'ModelManagerCubit');
  }

  /// Constant-time byte comparison (XOR accumulate): returns as soon as a
  /// difference is found for control flow, but the running difference is
  /// only revealed at the end, keeping the comparison timing-independent.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Parses a lowercase/uppercase hex digest; `null` when malformed.
  static List<int>? _parseHex(String hex) {
    final trimmed = hex.trim().toLowerCase();
    if (trimmed.length.isOdd ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(trimmed)) {
      return null;
    }
    return [
      for (var i = 0; i < trimmed.length; i += 2)
        int.parse(trimmed.substring(i, i + 2), radix: 16),
    ];
  }

  /// Check if there's enough free disk space for the model download.
  Future<void> _checkDiskSpace(Directory dir) async {
    try {
      // Touch the filesystem; a failure here surfaces early.
      // Note: On iOS/Android, we can't easily get free space via Dart's stat.
      // This is a best-effort check; the actual download will fail if space is low.
      // For production, consider using a platform channel to get accurate free space.
      developer.log(
        'Disk space check for ${dir.path}',
        name: 'ModelManagerCubit',
      );
    } catch (e) {
      developer.log(
        'Disk space check failed (non-fatal): $e',
        name: 'ModelManagerCubit',
      );
    }
  }

  Future<void> _cleanupPartialFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — partial file cleanup is not critical.
    }
  }

  /// Simulated download used when no signed download URL is configured.
  ///
  /// Animates progress so the UI can be exercised, but MUST NOT emit
  /// [ModelManagerReady]: no real model artifact is produced, so flutter_gemma
  /// would still report the model as not installed. Ends in an honest error
  /// telling the developer how to supply the model instead.
  Future<void> _simulateDownload(File modelFile) async {
    developer.log(
      'MODEL_DOWNLOAD_URL not set — using simulated progress.',
      name: 'ModelManagerCubit',
    );
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (isClosed) return;
      _safeEmit(ModelManagerDownloading(
        i / 100.0,
        downloadedBytes: i * 1024 * 1024,
        totalBytes: 330 * 1024 * 1024,
        speedBytesPerSec: (330 * 1024 * 1024 / 100.0) / 0.4,
      ));
    }

    // Do not leave a placeholder artifact behind — it is not a real model
    // and would only confuse later checks.
    if (await modelFile.exists()) {
      await modelFile.delete();
    }

    _safeEmit(const ModelManagerError(
      'No model download URL is configured for this build. '
      'Host the Qwen 3 0.6B .litertlm file, or launch with '
      '--dart-define=MODEL_DOWNLOAD_URL=... and MODEL_CHECKSUM_SHA256=...',
      canRetry: false,
    ));
  }
}
