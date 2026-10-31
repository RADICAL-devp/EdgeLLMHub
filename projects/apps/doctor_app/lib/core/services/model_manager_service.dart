import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart'
    hide DownloadCancelledException;

import '../config/model_config.dart';
import '../exceptions/app_exceptions.dart';
import '../models/model_install_progress.dart';
import 'settings_service.dart';

/// Thin abstraction over flutter_edge_ai's static install API.
///
/// Keeping this behind an interface lets the download state machine be tested
/// without loading a native runtime.
abstract interface class EdgeModelInstaller {
  bool get hasLlm;
  bool get hasStt;

  Future<int?> storageBytes();

  Future<void> installLlm({
    required void Function(double progress) onProgress,
    required CancelToken cancelToken,
  });

  Future<void> installStt({
    required void Function(double progress) onModelProgress,
    required void Function(double progress) onTokenizerProgress,
    required CancelToken cancelToken,
  });

  Future<void> uninstallAll();
}

class FlutterEdgeModelInstaller implements EdgeModelInstaller {
  @override
  bool get hasLlm => FlutterEdgeAi.hasActiveModel();

  @override
  bool get hasStt => FlutterEdgeAi.hasActiveStt();

  @override
  Future<int?> storageBytes() async {
    try {
      final stats = await FlutterEdgeAi.getStorageInfo();
      return stats.totalSizeBytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> installLlm({
    required void Function(double progress) onProgress,
    required CancelToken cancelToken,
  }) async {
    await FlutterEdgeAi.installModel(
          modelType: ModelCatalog.llm.modelType,
          fileType: ModelCatalog.llm.fileType,
        )
        .fromNetwork(ModelCatalog.llm.url, foreground: true)
        .withProgress((progress) => onProgress(progress / 100.0))
        .withCancelToken(cancelToken)
        .install();
  }

  @override
  Future<void> installStt({
    required void Function(double progress) onModelProgress,
    required void Function(double progress) onTokenizerProgress,
    required CancelToken cancelToken,
  }) async {
    await FlutterEdgeAi.installStt()
        .modelFromNetwork(ModelCatalog.stt.modelUrl)
        .tokenizerFromNetwork(ModelCatalog.stt.tokenizerUrl)
        .ofType(ModelCatalog.stt.modelType)
        .withModelProgress((progress) => onModelProgress(progress / 100.0))
        .withTokenizerProgress(
          (progress) => onTokenizerProgress(progress / 100.0),
        )
        .withCancelToken(cancelToken)
        .install();
  }

  @override
  Future<void> uninstallAll() async {
    try {
      final active = FlutterEdgeAi.activeModelSpec;
      if (active != null) {
        await FlutterEdgeAi.uninstallModel(active.name);
      }
    } catch (_) {
      // Fall through to the installed-model list below.
    }
    try {
      final installed = await FlutterEdgeAi.listInstalledModels();
      for (final id in installed) {
        await FlutterEdgeAi.uninstallModel(id);
      }
    } catch (_) {
      // Best effort: the storage screen still reports what is left.
    }
    try {
      await FlutterEdgeAi.uninstallStt();
    } catch (_) {
      // No active STT is a no-op for this API, but guard anyway.
    }
  }
}

class NetworkState {
  const NetworkState({required this.online, required this.wifi});

  final bool online;
  final bool wifi;
}

abstract interface class NetworkChecker {
  Future<NetworkState> check();
}

class ConnectivityNetworkChecker implements NetworkChecker {
  ConnectivityNetworkChecker([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkState> check() async {
    final results = await _connectivity.checkConnectivity();
    final online = results.any((result) => result != ConnectivityResult.none);
    final wifi =
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    return NetworkState(online: online, wifi: wifi);
  }
}

/// Coordinates first-launch model downloads, consent-aware network checks, and
/// progress reporting. All downloads are performed by flutter_edge_ai.
class ModelManagerService {
  ModelManagerService({
    required SettingsService settings,
    EdgeModelInstaller? installer,
    NetworkChecker? networkChecker,
  }) : _settings = settings,
       _installer = installer ?? FlutterEdgeModelInstaller(),
       _networkChecker = networkChecker ?? ConnectivityNetworkChecker();

  final SettingsService _settings;
  final EdgeModelInstaller _installer;
  final NetworkChecker _networkChecker;

  CancelToken? _cancelToken;
  bool _installInFlight = false;

  bool get llmReady => _installer.hasLlm;
  bool get sttReady => _installer.hasStt;
  bool get allReady => llmReady && sttReady;
  bool get isDownloading => _installInFlight;

  Future<ModelStatus> getStatus() async {
    final bytes = await _installer.storageBytes();
    return ModelStatus(
      llmReady: llmReady,
      sttReady: sttReady,
      storageMb: bytes == null ? null : bytes / (1024 * 1024),
    );
  }

  /// Downloads and activates both models.
  ///
  /// Throws [WifiRequiredException], [NoNetworkException],
  /// [DownloadCancelledException], or [ModelInstallException] on failure.
  Future<void> installAll({
    required void Function(ModelInstallProgress progress) onProgress,
  }) async {
    if (allReady) {
      onProgress(
        const ModelInstallProgress(
          phase: ModelInstallPhase.completed,
          overall: 1,
          message: 'Models are ready.',
        ),
      );
      return;
    }

    if (_installInFlight) {
      onProgress(
        const ModelInstallProgress(
          phase: ModelInstallPhase.checkingNetwork,
          overall: 0,
          message: 'A model download is already in progress.',
        ),
      );
      return;
    }

    _installInFlight = true;
    try {
      onProgress(
        const ModelInstallProgress(
          phase: ModelInstallPhase.checkingNetwork,
          overall: 0,
          message: 'Checking connection…',
        ),
      );

      final network = await _networkChecker.check();
      if (!network.online) throw const NoNetworkException();
      if (_settings.wifiOnlyDownloads && !network.wifi) {
        throw const WifiRequiredException();
      }

      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      try {
        if (!llmReady) {
          onProgress(
            const ModelInstallProgress(
              phase: ModelInstallPhase.downloadingLlm,
              overall: 0.01,
              message: 'Downloading the language model…',
            ),
          );
          await _installer.installLlm(
            cancelToken: cancelToken,
            onProgress: (fileProgress) {
              onProgress(
                ModelInstallProgress(
                  phase: ModelInstallPhase.downloadingLlm,
                  overall: 0.01 + (fileProgress * 0.79),
                  fileProgress: fileProgress,
                  message: 'Downloading the language model…',
                ),
              );
            },
          );
          onProgress(
            const ModelInstallProgress(
              phase: ModelInstallPhase.installingLlm,
              overall: 0.81,
              message: 'Preparing the language model…',
            ),
          );
        }

        if (!sttReady) {
          onProgress(
            const ModelInstallProgress(
              phase: ModelInstallPhase.downloadingSttModel,
              overall: 0.82,
              message: 'Downloading the speech model…',
            ),
          );
          await _installer.installStt(
            cancelToken: cancelToken,
            onModelProgress: (fileProgress) {
              onProgress(
                ModelInstallProgress(
                  phase: ModelInstallPhase.downloadingSttModel,
                  overall: 0.82 + (fileProgress * 0.14),
                  fileProgress: fileProgress,
                  message: 'Downloading the speech model…',
                ),
              );
            },
            onTokenizerProgress: (fileProgress) {
              onProgress(
                ModelInstallProgress(
                  phase: ModelInstallPhase.downloadingSttTokenizer,
                  overall: 0.96 + (fileProgress * 0.03),
                  fileProgress: fileProgress,
                  message: 'Finishing the speech model…',
                ),
              );
            },
          );
          onProgress(
            const ModelInstallProgress(
              phase: ModelInstallPhase.installingStt,
              overall: 0.995,
              message: 'Preparing the speech model…',
            ),
          );
        }

        if (!llmReady || !sttReady) {
          throw const ModelInstallException(
            'The models were downloaded but could not be activated. Please try '
            'again, or restart the app.',
          );
        }

        onProgress(
          const ModelInstallProgress(
            phase: ModelInstallPhase.completed,
            overall: 1,
            message: 'Models are ready on this device.',
          ),
        );
      } on DownloadCancelledException {
        onProgress(
          const ModelInstallProgress(
            phase: ModelInstallPhase.cancelled,
            overall: 0,
            message: 'Download cancelled.',
          ),
        );
        rethrow;
      } catch (error) {
        if (CancelToken.isCancel(error)) {
          onProgress(
            const ModelInstallProgress(
              phase: ModelInstallPhase.cancelled,
              overall: 0,
              message: 'Download cancelled.',
            ),
          );
          throw const DownloadCancelledException();
        }
        final wrapped = error is ModelInstallException
            ? error
            : ModelInstallException(
                'The model download failed. Check your connection and try again.',
                cause: error,
              );
        onProgress(
          ModelInstallProgress(
            phase: ModelInstallPhase.error,
            overall: 0,
            message: wrapped.message,
            error: wrapped,
          ),
        );
        throw wrapped;
      } finally {
        _cancelToken = null;
      }
    } finally {
      _installInFlight = false;
    }
  }

  void cancel() {
    _cancelToken?.cancel('User cancelled');
  }

  Future<void> deleteModels() async {
    await _installer.uninstallAll();
  }
}
