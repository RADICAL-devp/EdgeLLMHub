import 'package:equatable/equatable.dart';

enum RecordingPhase {
  idle,
  preparing,
  recording,
  paused,
  transcribing,
  done,
  error,
}

class RecordingState extends Equatable {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.amplitude = 0,
    this.progress = 0,
    this.segmentIndex = 0,
    this.segmentCount = 0,
    this.transcript = '',
    this.error,
    this.permissionDenied = false,
    this.needsModelSetup = false,
    this.noSpeech = false,
  });

  final RecordingPhase phase;
  final Duration elapsed;

  /// 0..1 visual level derived from the recorder's dBFS amplitude.
  final double amplitude;

  /// 0..1 transcription progress.
  final double progress;
  final int segmentIndex;
  final int segmentCount;
  final String transcript;
  final String? error;
  final bool permissionDenied;
  final bool needsModelSetup;
  final bool noSpeech;

  bool get isRecording => phase == RecordingPhase.recording;
  bool get isPaused => phase == RecordingPhase.paused;
  bool get isTranscribing => phase == RecordingPhase.transcribing;
  bool get isDone => phase == RecordingPhase.done;

  RecordingState copyWith({
    RecordingPhase? phase,
    Duration? elapsed,
    double? amplitude,
    double? progress,
    int? segmentIndex,
    int? segmentCount,
    String? transcript,
    String? error,
    bool? permissionDenied,
    bool? needsModelSetup,
    bool? noSpeech,
    bool clearError = false,
  }) {
    return RecordingState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      amplitude: amplitude ?? this.amplitude,
      progress: progress ?? this.progress,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      segmentCount: segmentCount ?? this.segmentCount,
      transcript: transcript ?? this.transcript,
      error: clearError ? null : (error ?? this.error),
      permissionDenied: permissionDenied ?? this.permissionDenied,
      needsModelSetup: needsModelSetup ?? this.needsModelSetup,
      noSpeech: noSpeech ?? this.noSpeech,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    elapsed,
    amplitude,
    progress,
    segmentIndex,
    segmentCount,
    transcript,
    error,
    permissionDenied,
    needsModelSetup,
    noSpeech,
  ];
}
