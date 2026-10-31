enum ModelInstallPhase {
  idle,
  checkingNetwork,
  downloadingLlm,
  installingLlm,
  downloadingSttModel,
  downloadingSttTokenizer,
  installingStt,
  completed,
  cancelled,
  error,
}

/// Immutable progress snapshot for the first-launch model download.
class ModelInstallProgress {
  const ModelInstallProgress({
    required this.phase,
    required this.overall,
    this.fileProgress,
    this.message = '',
    this.error,
  });

  const ModelInstallProgress.idle()
    : phase = ModelInstallPhase.idle,
      overall = 0,
      fileProgress = null,
      message = '',
      error = null;

  final ModelInstallPhase phase;

  /// 0..1 across the whole download (LLM + speech model + tokenizer).
  final double overall;

  /// 0..1 for the file currently being downloaded, when known.
  final double? fileProgress;

  final String message;
  final Object? error;

  bool get isBusy =>
      phase == ModelInstallPhase.checkingNetwork ||
      phase == ModelInstallPhase.downloadingLlm ||
      phase == ModelInstallPhase.installingLlm ||
      phase == ModelInstallPhase.downloadingSttModel ||
      phase == ModelInstallPhase.downloadingSttTokenizer ||
      phase == ModelInstallPhase.installingStt;

  bool get isTerminal =>
      phase == ModelInstallPhase.completed ||
      phase == ModelInstallPhase.cancelled ||
      phase == ModelInstallPhase.error;

  ModelInstallProgress copyWith({
    ModelInstallPhase? phase,
    double? overall,
    double? fileProgress,
    String? message,
    Object? error,
  }) {
    return ModelInstallProgress(
      phase: phase ?? this.phase,
      overall: overall ?? this.overall,
      fileProgress: fileProgress ?? this.fileProgress,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

class ModelStatus {
  const ModelStatus({
    required this.llmReady,
    required this.sttReady,
    this.storageMb,
  });

  const ModelStatus.unknown()
    : llmReady = false,
      sttReady = false,
      storageMb = null;

  final bool llmReady;
  final bool sttReady;
  final double? storageMb;

  bool get allReady => llmReady && sttReady;

  String get summary {
    if (allReady) return 'Ready on this device';
    if (llmReady) return 'Speech model needs setup';
    if (sttReady) return 'Language model needs setup';
    return 'Models need setup';
  }
}
