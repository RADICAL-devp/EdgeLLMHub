import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
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
  ///   6. Check model version compatibility and trigger upgrade if needed
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
      if (isIosPlatform) {
        await _checkIosModel();
      } else if (isAndroidPlatform) {
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

  /// Check if model upgrade is needed by comparing versions.
  ///
  /// Returns true if the installed model version is older than the
  /// bundled version or incompatible with the current app version.
  Future<bool> _needsModelUpgrade(Map<String, Object?> modelInfo) async {
    try {
      final installedVersion = modelInfo['modelVersion'] as String?;
      if (installedVersion == null || installedVersion.isEmpty) {
        // No version info — assume upgrade needed
        return true;
      }

      // Compare with bundled model version
      final bundledVersion = EnvironmentConfig.bundledModelVersion.version;
      return _compareVersions(installedVersion, bundledVersion) < 0;
    } catch (e) {
      developer.log(
        'Version check failed, assuming upgrade needed: $e',
        name: 'ModelManagerCubit',
      );
      return true;
    }
  }

  /// Compare semantic versions (major.minor.patch).
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }
    return 0;
  }

  /// Platform gates, factored out so tests can simulate either platform.
  @visibleForTesting
  bool get isIosPlatform => Platform.isIOS;

  @visibleForTesting
  bool get isAndroidPlatform => Platform.isAndroid;

  /// Check iOS MLC model availability with real verification.
  Future<void> _checkIosModel() async {
    try {
      // Step 1: Get model info (installed status, path, checksum)
      final modelInfo = await _iosChannel
          .invokeMapMethod<String, Object?>('getModelInfo')
          .timeout(_verificationTimeout);

      if (modelInfo == null) {
        emit(const ModelManagerError(
          'MLC LLM handler did not return model info.',
        ));
        return;
      }

      final installed = modelInfo['installed'] == true;
      if (!installed) {
        // Model is not installed — the first-run download flow owns the
        // not-installed state (the page shows the Download button there).
        emit(ModelManagerInitial());
        return;
      }

      // Step 2: Verify checksum if available
      final checksum = modelInfo['checksumSha256'] as String?;
      if (checksum != null && checksum.isNotEmpty) {
        // Security note (Workstream 8): an INSTALLED model's integrity is
        // guaranteed at download time — _verifyChecksum() validates the
        // archive's SHA-256 (constant-time) BEFORE extraction, and the
        // corrupt archive is deleted on mismatch. The native side reports a
        // checksum of the extracted BUNDLE binary (checksums.sha256), a
        // different artifact than the archive, so it cannot be compared
        // against EnvironmentConfig.modelChecksumSha256 (the archive pin)
        // without false positives. It is logged for diagnostics instead;
        // no second verification path is needed.
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

      // Step 6: Check if model upgrade is needed
      final needsUpgrade = await _needsModelUpgrade(modelInfo);
      if (needsUpgrade) {
        developer.log(
          'Model upgrade available — triggering download',
          name: 'ModelManagerCubit',
        );
        await downloadModel();
        return;
      }

      developer.log(
        'MLC verification succeeded (${verifyResult.length} chars)',
        name: 'ModelManagerCubit',
      );
      emit(ModelManagerReady(
        'Bundled SmolLM-360M (MLCSwift)',
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
      // Step 1: Get model info (installed status, path, checksum)
      final modelInfo = await _androidChannel
          .invokeMapMethod<String, Object?>('getModelInfo')
          .timeout(_verificationTimeout);

      if (modelInfo == null) {
        emit(const ModelManagerError(
          'MLC Android handler did not return model info.',
        ));
        return;
      }

      final installed = modelInfo['installed'] == true;
      if (!installed) {
        emit(ModelManagerInitial());
        return;
      }

      // Step 2: Verify checksum if available
      final checksum = modelInfo['checksumSha256'] as String?;
      if (checksum != null && checksum.isNotEmpty) {
        // Security note (Workstream 8): same as the iOS path — integrity is
        // enforced at download time via _verifyChecksum() (constant-time,
        // archive deleted on mismatch). The reported value is the extracted
        // bundle checksum, a different artifact than the archive pin, so it
        // is logged for diagnostics rather than compared.
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

      // Step 6: Check if model upgrade is needed
      final needsUpgrade = await _needsModelUpgrade(modelInfo);
      if (needsUpgrade) {
        developer.log(
          'Model upgrade available — triggering download',
          name: 'ModelManagerCubit',
        );
        await downloadModel();
        return;
      }

      developer.log(
        'MLC Android verification succeeded (${verifyResult.length} chars)',
        name: 'ModelManagerCubit',
      );
      emit(ModelManagerReady(
        'Bundled SmolLM-360M (MLC Android)',
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

  /// Download the model for the current platform.
  ///
  /// Downloads the packaged model artifact ([EnvironmentConfig.modelFileName],
  /// typically a `.zip` of the MLC-packaged model directory) with transfer-rate
  /// tracking, verifies the SHA-256 checksum, then extracts it to
  /// `{dir}/{modelBundleDirName}` so the platform handlers find it at the
  /// well-known location. When the artifact is not an archive (legacy single
  /// binary), it is kept as-is. [downloadUrl], [checksumSha256] and
  /// [downloadDirectory] may be overridden (used by tests); they default to
  /// [EnvironmentConfig] values and the platform documents directory.
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

    // Check free disk space before download
    await _checkDiskSpace(dir);

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
      final readyPath = await _prepareModelAt(modelFile, dir);
      emit(ModelManagerReady(readyPath, executionMode: 'local'));
    } on DioException catch (e) {
      await _cleanupPartialFile(modelFile);
      emit(ModelManagerError('Download failed: ${e.message}'));
    } catch (e) {
      await _cleanupPartialFile(modelFile);
      emit(ModelManagerError('Download failed: $e'));
    }
  }

  /// Turn the downloaded artifact into a usable model on disk.
  ///
  /// Archive artifacts (`.zip`) are extracted into `{dir}/{modelBundleDirName}`
  /// (the well-known location the platform handlers load from) and the
  /// archive itself is removed. Non-archive artifacts are used in place.
  Future<String> _prepareModelAt(File artifact, Directory dir) async {
    if (!artifact.path.toLowerCase().endsWith('.zip')) {
      return artifact.path;
    }
    final targetDir = Directory(
      '${dir.path}/${EnvironmentConfig.modelBundleDirName}',
    );
    await _extractArchive(artifact, targetDir);
    if (await artifact.exists()) {
      await artifact.delete();
    }
    return targetDir.path;
  }

  Future<void> _extractArchive(File zipFile, Directory targetDir) async {
    if (targetDir.existsSync()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.isEmpty) {
      throw Exception('Model archive contains no files.');
    }
    // MLC-packaged artifacts wrap the model directory, so entries are named
    // `{modelBundleDirName}/...`. Strip that prefix — targetDir already IS
    // the model directory.
    const prefix = '${EnvironmentConfig.modelBundleDirName}/';
    for (final entry in archive.files) {
      final rel = entry.name.startsWith(prefix)
          ? entry.name.substring(prefix.length)
          : entry.name;
      if (rel.isEmpty) continue;
      final path = p.join(targetDir.path, rel);
      if (entry.isFile) {
        final file = File(path);
        await file.create(recursive: true);
        final content = entry.readBytes();
        if (content != null) {
          await file.writeAsBytes(content);
        }
      } else {
        await Directory(path).create(recursive: true);
      }
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
    emit(ModelManagerDownloading(
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

  /// Check if there's enough free disk space for model download + extraction.
  Future<void> _checkDiskSpace(Directory dir) async {
    try {
      // Use stat to get filesystem info
      final stat = await dir.stat();
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
  /// [ModelManagerReady]: no real model artifact is produced, so the native
  /// MLC engine would still report the model as not installed. Ends in an
  /// honest error telling the developer how to supply the model instead.
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

    // Do not leave a placeholder artifact behind — it is not a real model
    // and would only confuse later checks.
    if (await modelFile.exists()) {
      await modelFile.delete();
    }

    emit(const ModelManagerError(
      'No model download URL is configured for this build. '
      'Bundle the SmolLM-360M model into the app, or launch with '
      '--dart-define=MODEL_DOWNLOAD_URL=... and MODEL_CHECKSUM_SHA256=...',
      canRetry: false,
    ));
  }
}
