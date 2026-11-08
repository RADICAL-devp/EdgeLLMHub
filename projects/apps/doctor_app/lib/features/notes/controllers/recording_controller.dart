import 'dart:async';

import 'package:record/record.dart';
import 'package:signals/signals.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/audio_capture_service.dart';
import '../../../core/services/transcription_service.dart';
import 'recording_state.dart';

class RecordingController extends Signal<RecordingState> {
  RecordingController({
    required AudioCaptureService audio,
    required TranscriptionService transcription,
    required String languageCode,
  }) : _audio = audio,
       _transcription = transcription,
       _languageCode = languageCode,
       super(const RecordingState());

  final AudioCaptureService _audio;
  final TranscriptionService _transcription;
  final String _languageCode;

  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  DateTime? _startedAt;
  Duration _accumulated = Duration.zero;

  Duration get _elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) return _accumulated;
    return _accumulated + DateTime.now().difference(startedAt);
  }

  Future<void> start() async {
    if (value.phase == RecordingPhase.recording ||
        value.phase == RecordingPhase.paused ||
        value.phase == RecordingPhase.transcribing ||
        value.phase == RecordingPhase.preparing) {
      return;
    }
    value = const RecordingState(phase: RecordingPhase.preparing);

    if (!_transcription.isReady) {
      value = const RecordingState(
        phase: RecordingPhase.error,
        error: 'The on-device speech model is not installed yet.',
        needsModelSetup: true,
      );
      return;
    }

    final allowed = await _audio.ensurePermission();
    if (disposed) return;
    if (!allowed) {
      value = const RecordingState(
        phase: RecordingPhase.error,
        error:
            'Microphone access is required to record a consultation. '
            'Enable it in system settings and try again.',
        permissionDenied: true,
      );
      return;
    }

    try {
      await _audio.start();
      if (disposed) {
        await _audio.cancel();
        return;
      }
      _accumulated = Duration.zero;
      _startedAt = DateTime.now();
      _startTimer();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audio.amplitudeStream.listen(_onAmplitude);
      if (!disposed) {
        value = const RecordingState(phase: RecordingPhase.recording);
      }
    } catch (error) {
      if (disposed) return;
      value = RecordingState(
        phase: RecordingPhase.error,
        error: error is AppException
            ? error.message
            : 'Recording could not start. Check that no other app is using '
                  'the microphone.',
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (disposed || value.phase != RecordingPhase.recording) return;
      value = value.copyWith(elapsed: _elapsed);
    });
  }

  void _onAmplitude(Amplitude amplitude) {
    if (disposed || value.phase != RecordingPhase.recording) return;
    // record reports dBFS (0 is loudest); map the useful speech range to 0..1.
    final db = amplitude.current.clamp(-70.0, 0.0).toDouble();
    final level = ((db + 55) / 55).clamp(0.0, 1.0).toDouble();
    value = value.copyWith(amplitude: level);
  }

  Future<void> pause() async {
    if (value.phase != RecordingPhase.recording) return;
    final elapsed = _elapsed;
    try {
      await _audio.pause();
    } catch (_) {
      // Keep the current value; the stop action will surface a real error.
    }
    _accumulated = elapsed;
    _startedAt = null;
    _timer?.cancel();
    if (!disposed) {
      value = value.copyWith(
        phase: RecordingPhase.paused,
        elapsed: elapsed,
        amplitude: 0,
      );
    }
  }

  Future<void> resume() async {
    if (value.phase != RecordingPhase.paused) return;
    try {
      await _audio.resume();
    } catch (error) {
      if (!disposed) {
        value = value.copyWith(
          phase: RecordingPhase.error,
          error: 'Recording could not resume. Please try again.',
        );
      }
      return;
    }
    if (disposed) {
      await _audio.cancel();
      return;
    }
    _startedAt = DateTime.now();
    _startTimer();
    if (!disposed) {
      value = value.copyWith(
        phase: RecordingPhase.recording,
        elapsed: _accumulated,
        clearError: true,
      );
    }
  }

  Future<void> stopAndTranscribe() async {
    if (value.phase != RecordingPhase.recording &&
        value.phase != RecordingPhase.paused) {
      return;
    }
    final elapsed = _elapsed;
    _timer?.cancel();
    _startedAt = null;
    _accumulated = elapsed;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (!disposed) {
      value = value.copyWith(
        phase: RecordingPhase.transcribing,
        elapsed: elapsed,
        amplitude: 0,
        progress: 0,
        segmentIndex: 0,
        segmentCount: 0,
        clearError: true,
      );
    }

    try {
      final path = await _audio.stop();
      if (disposed) {
        await _audio.deleteTemporaryFile(path);
        return;
      }
      if (path == null || path.isEmpty) {
        throw const TranscriptionException(
          'The recording could not be saved. Please record again.',
        );
      }

      final result = await _transcription.transcribeFile(
        path,
        languageCode: _languageCode,
        onProgress: (progress) {
          if (disposed) return;
          value = value.copyWith(
            progress: progress.overall,
            segmentIndex: progress.segmentIndex,
            segmentCount: progress.segmentCount,
          );
        },
      );

      if (disposed) return;
      value = value.copyWith(
        phase: RecordingPhase.done,
        transcript: result.text,
        progress: 1,
        segmentIndex: result.segmentCount,
        segmentCount: result.segmentCount,
      );
    } on NoSpeechDetectedException catch (error) {
      if (!disposed) {
        value = value.copyWith(
          phase: RecordingPhase.error,
          error: error.message,
          noSpeech: true,
        );
      }
    } on ModelNotReadyException catch (error) {
      if (!disposed) {
        value = value.copyWith(
          phase: RecordingPhase.error,
          error: error.message,
          needsModelSetup: true,
        );
      }
    } on AppException catch (error) {
      if (!disposed) {
        value = value.copyWith(
          phase: RecordingPhase.error,
          error: error.message,
        );
      }
    } catch (_) {
      if (!disposed) {
        value = value.copyWith(
          phase: RecordingPhase.error,
          error: 'On-device transcription failed. Please record again.',
        );
      }
    }
  }

  Future<void> cancel() async {
    if (value.phase == RecordingPhase.transcribing) return;
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _accumulated = Duration.zero;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _audio.cancel();
    if (!disposed) value = const RecordingState();
  }

  /// Clears an error and returns to the ready-to-record value.
  void reset() {
    if (value.phase == RecordingPhase.transcribing) return;
    _timer?.cancel();
    _startedAt = null;
    _accumulated = Duration.zero;
    if (!disposed) value = const RecordingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel().ignore();
    _amplitudeSubscription = null;
    if (!disposed &&
        (value.phase == RecordingPhase.recording ||
            value.phase == RecordingPhase.paused)) {
      _audio.cancel().ignore();
    }
    super.dispose();
  }
}
