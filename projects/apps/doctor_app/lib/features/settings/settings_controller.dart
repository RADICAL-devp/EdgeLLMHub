import 'package:equatable/equatable.dart';
import 'package:signals/signals.dart';

import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/model_install_progress.dart';
import '../../../core/services/model_manager_service.dart';
import '../../../core/services/settings_service.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.thinkingMode = false,
    this.languageCode = 'en',
    this.wifiOnlyDownloads = true,
    this.modelStatus,
    this.noteCount = 0,
    this.isLoading = true,
    this.isDeletingModels = false,
    this.isDeletingNotes = false,
    this.error,
  });

  final bool thinkingMode;
  final String languageCode;
  final bool wifiOnlyDownloads;
  final ModelStatus? modelStatus;
  final int noteCount;
  final bool isLoading;
  final bool isDeletingModels;
  final bool isDeletingNotes;
  final String? error;

  SettingsState copyWith({
    bool? thinkingMode,
    String? languageCode,
    bool? wifiOnlyDownloads,
    ModelStatus? modelStatus,
    int? noteCount,
    bool? isLoading,
    bool? isDeletingModels,
    bool? isDeletingNotes,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      thinkingMode: thinkingMode ?? this.thinkingMode,
      languageCode: languageCode ?? this.languageCode,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      modelStatus: modelStatus ?? this.modelStatus,
      noteCount: noteCount ?? this.noteCount,
      isLoading: isLoading ?? this.isLoading,
      isDeletingModels: isDeletingModels ?? this.isDeletingModels,
      isDeletingNotes: isDeletingNotes ?? this.isDeletingNotes,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    thinkingMode,
    languageCode,
    wifiOnlyDownloads,
    modelStatus,
    noteCount,
    isLoading,
    isDeletingModels,
    isDeletingNotes,
    error,
  ];
}

class SettingsController extends Signal<SettingsState> {
  SettingsController({
    required SettingsService settings,
    required ModelManagerService models,
    required NoteRepository repository,
  }) : _settings = settings,
       _models = models,
       _repository = repository,
       super(
         SettingsState(
           thinkingMode: settings.thinkingMode,
           languageCode: settings.languageCode,
           wifiOnlyDownloads: settings.wifiOnlyDownloads,
         ),
       );

  final SettingsService _settings;
  final ModelManagerService _models;
  final NoteRepository _repository;

  Future<void> load() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _models.getStatus();
      final count = await _repository.countAll();
      if (disposed) return;
      value = value.copyWith(
        modelStatus: status,
        noteCount: count,
        thinkingMode: _settings.thinkingMode,
        languageCode: _settings.languageCode,
        wifiOnlyDownloads: _settings.wifiOnlyDownloads,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      if (disposed) return;
      value = value.copyWith(
        isLoading: false,
        error: 'The local settings could not be loaded.',
      );
    }
  }

  Future<void> setThinkingMode(bool enabled) async {
    await _settings.setThinkingMode(enabled);
    if (!disposed) value = value.copyWith(thinkingMode: enabled);
  }

  Future<void> setLanguageCode(String code) async {
    await _settings.setLanguageCode(code);
    if (!disposed) value = value.copyWith(languageCode: _settings.languageCode);
  }

  Future<void> setWifiOnlyDownloads(bool enabled) async {
    await _settings.setWifiOnlyDownloads(enabled);
    if (!disposed) value = value.copyWith(wifiOnlyDownloads: enabled);
  }

  Future<void> deleteModels() async {
    if (value.isDeletingModels) return;
    value = value.copyWith(isDeletingModels: true, clearError: true);
    try {
      await _models.deleteModels();
      final status = await _models.getStatus();
      if (disposed) return;
      value = value.copyWith(isDeletingModels: false, modelStatus: status);
    } catch (error) {
      if (disposed) return;
      value = value.copyWith(
        isDeletingModels: false,
        error: error is AppException
            ? error.message
            : 'The models could not be removed.',
      );
    }
  }

  Future<void> deleteAllNotes() async {
    if (value.isDeletingNotes) return;
    value = value.copyWith(isDeletingNotes: true, clearError: true);
    try {
      await _repository.deleteAll();
      if (disposed) return;
      value = value.copyWith(isDeletingNotes: false, noteCount: 0);
    } catch (_) {
      if (disposed) return;
      value = value.copyWith(
        isDeletingNotes: false,
        error: 'The local notes could not be deleted.',
      );
    }
  }

  Future<void> resetOnboarding() async {
    await _settings.resetOnboarding();
  }
}
