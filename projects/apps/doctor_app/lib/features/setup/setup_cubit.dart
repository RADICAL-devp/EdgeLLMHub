import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/model_install_progress.dart';
import '../../../core/services/model_manager_service.dart';
import '../../../core/services/settings_service.dart';

class SetupState extends Equatable {
  const SetupState({
    this.status,
    this.progress = const ModelInstallProgress.idle(),
    this.isChecking = true,
    this.isInstalling = false,
    this.isComplete = false,
    this.needsWifi = false,
    this.error,
  });

  final ModelStatus? status;
  final ModelInstallProgress progress;
  final bool isChecking;
  final bool isInstalling;
  final bool isComplete;
  final bool needsWifi;
  final String? error;

  double get overall => progress.overall;

  SetupState copyWith({
    ModelStatus? status,
    ModelInstallProgress? progress,
    bool? isChecking,
    bool? isInstalling,
    bool? isComplete,
    bool? needsWifi,
    String? error,
    bool clearError = false,
  }) {
    return SetupState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      isChecking: isChecking ?? this.isChecking,
      isInstalling: isInstalling ?? this.isInstalling,
      isComplete: isComplete ?? this.isComplete,
      needsWifi: needsWifi ?? this.needsWifi,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    status,
    progress,
    isChecking,
    isInstalling,
    isComplete,
    needsWifi,
    error,
  ];
}

class SetupCubit extends Cubit<SetupState> {
  SetupCubit({
    required ModelManagerService models,
    required SettingsService settings,
  }) : _models = models,
       _settings = settings,
       super(const SetupState());

  final ModelManagerService _models;
  final SettingsService _settings;

  Future<void> load() async {
    emit(state.copyWith(isChecking: true, clearError: true, needsWifi: false));
    try {
      final status = await _models.getStatus();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: status,
          isChecking: false,
          isComplete: status.allReady,
          progress: status.allReady
              ? const ModelInstallProgress(
                  phase: ModelInstallPhase.completed,
                  overall: 1,
                  message: 'Models are ready on this device.',
                )
              : const ModelInstallProgress.idle(),
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isChecking: false,
          error: 'The local model status could not be read.',
        ),
      );
    }
  }

  Future<void> install({bool allowCellular = false}) async {
    if (state.isInstalling) return;
    if (allowCellular) {
      await _settings.setWifiOnlyDownloads(false);
    }
    emit(
      state.copyWith(
        isInstalling: true,
        isComplete: false,
        needsWifi: false,
        clearError: true,
        progress: const ModelInstallProgress(
          phase: ModelInstallPhase.checkingNetwork,
          overall: 0,
          message: 'Checking connection…',
        ),
      ),
    );

    try {
      await _models.installAll(
        onProgress: (progress) {
          if (isClosed) return;
          emit(
            state.copyWith(
              progress: progress,
              isInstalling: progress.isBusy,
              error: progress.phase == ModelInstallPhase.error
                  ? (progress.error?.toString() ?? progress.message)
                  : null,
              clearError: progress.phase != ModelInstallPhase.error,
            ),
          );
        },
      );
      if (isClosed) return;
      final status = await _models.getStatus();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: status,
          isInstalling: false,
          isChecking: false,
          isComplete: status.allReady,
          progress: status.allReady
              ? const ModelInstallProgress(
                  phase: ModelInstallPhase.completed,
                  overall: 1,
                  message: 'Models are ready on this device.',
                )
              : const ModelInstallProgress(
                  phase: ModelInstallPhase.error,
                  overall: 0,
                  message:
                      'The models could not be activated. Please try again.',
                ),
        ),
      );
    } on WifiRequiredException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isInstalling: false,
          needsWifi: true,
          error: error.message,
          progress: const ModelInstallProgress(
            phase: ModelInstallPhase.error,
            overall: 0,
            message: 'Wi-Fi is required by the current download setting.',
          ),
        ),
      );
    } on DownloadCancelledException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isInstalling: false,
          error: error.message,
          progress: const ModelInstallProgress(
            phase: ModelInstallPhase.cancelled,
            overall: 0,
            message: 'Download cancelled.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isInstalling: false,
          error: error.message,
          progress: ModelInstallProgress(
            phase: ModelInstallPhase.error,
            overall: 0,
            message: error.message,
            error: error,
          ),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isInstalling: false,
          error:
              'The model download failed. Check your connection and try again.',
        ),
      );
    }
  }

  void cancel() {
    _models.cancel();
  }

  Future<void> deleteModels() async {
    if (state.isInstalling) return;
    try {
      await _models.deleteModels();
      await load();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error:
              'The models could not be removed. Close the app and try again.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    // Leaving setup must not leave a foreground download running with no UI.
    if (state.isInstalling) _models.cancel();
    return super.close();
  }
}
