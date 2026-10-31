import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Captures 16 kHz mono PCM, the format expected by the bundled Whisper model.
///
/// Nothing is uploaded. The caller is responsible for deleting the temporary
/// file as soon as transcription finishes; [deleteTemporaryFile] is provided
/// for that purpose and [dispose] also removes any leftover file.
class AudioCaptureService {
  AudioCaptureService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const int sampleRate = 16000;
  static const int numChannels = 1;

  final AudioRecorder _recorder;
  String? _currentPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final StreamController<Amplitude> _amplitudeController =
      StreamController<Amplitude>.broadcast();

  bool get isRecording => _currentPath != null;
  String? get currentPath => _currentPath;
  Stream<Amplitude> get amplitudeStream => _amplitudeController.stream;

  Future<bool> ensurePermission({bool request = true}) =>
      _recorder.hasPermission(request: request);

  Future<String> start() async {
    if (_currentPath != null) {
      throw StateError('A recording is already in progress.');
    }
    final directory = await getTemporaryDirectory();
    final path = p.join(
      directory.path,
      'consultation_${DateTime.now().microsecondsSinceEpoch}.pcm',
    );
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        audioInterruption: AudioInterruptionMode.pause,
      ),
      path: path,
    );
    _currentPath = path;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_amplitudeController.add);
    return path;
  }

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  /// Stops and returns the temporary PCM path (if a recording was active).
  Future<String?> stop() async {
    final path = _currentPath;
    _currentPath = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final returned = await _recorder.stop();
    return returned ?? path;
  }

  /// Stops and discards the current recording.
  Future<void> cancel() async {
    final path = _currentPath;
    _currentPath = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      // The recorder may already be stopped.
    }
    await deleteTemporaryFile(path);
  }

  /// Removes any recording left behind by an interrupted session.
  ///
  /// This runs once at startup, before any new recording can begin. The audio
  /// file is temporary by contract, so an orphan from a crash is safe to drop.
  static Future<void> deleteStaleTemporaryFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('consultation_') || !name.endsWith('.pcm')) {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {
          // The OS will clear its own temporary directory eventually.
        }
      }
    } catch (_) {
      // Cleanup is best effort and must never block startup.
    }
  }

  Future<void> deleteTemporaryFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover temp file is removed by the OS; never surface its path.
    }
  }

  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _amplitudeController.close();
    try {
      await _recorder.dispose();
    } catch (_) {
      // Ignore platform teardown races.
    }
    await deleteTemporaryFile(_currentPath);
  }
}
