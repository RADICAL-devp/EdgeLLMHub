import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../exceptions/app_exceptions.dart';
import 'audio_capture_service.dart';
import 'transcript_merger.dart';
import 'vad_segmenter.dart';

class TranscriptionProgress {
  const TranscriptionProgress({
    required this.segmentIndex,
    required this.segmentCount,
    required this.overall,
  });

  final int segmentIndex;
  final int segmentCount;

  /// 0..1
  final double overall;
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.segmentCount,
    required this.audioDuration,
    required this.languageCode,
  });

  final String text;
  final int segmentCount;
  final Duration audioDuration;
  final String languageCode;
}

abstract interface class TranscriptionService {
  bool get isReady;

  Future<TranscriptionResult> transcribeFile(
    String path, {
    required String languageCode,
    void Function(TranscriptionProgress progress)? onProgress,
  });

  Future<void> dispose();
}

typedef SpeechRecognizerLoader =
    Future<SpeechRecognizer> Function(String languageCode);

/// On-device Whisper transcription with VAD chunking and transcript merging.
class WhisperTranscriptionService implements TranscriptionService {
  WhisperTranscriptionService({
    VadSegmenter? vad,
    TranscriptMerger? merger,
    SpeechRecognizerLoader? recognizerLoader,
    bool Function()? isModelReady,
  }) : _vad = vad ?? const VadSegmenter(),
       _merger = merger ?? const TranscriptMerger(),
       _recognizerLoader =
           recognizerLoader ??
           ((languageCode) =>
               FlutterEdgeAi.getActiveStt(language: languageCode)),
       _isModelReady = isModelReady ?? (() => FlutterEdgeAi.hasActiveStt());

  final VadSegmenter _vad;
  final TranscriptMerger _merger;
  final SpeechRecognizerLoader _recognizerLoader;
  final bool Function() _isModelReady;

  SpeechRecognizer? _recognizer;
  String? _recognizerLanguage;

  @override
  bool get isReady => _isModelReady();

  @override
  Future<TranscriptionResult> transcribeFile(
    String path, {
    required String languageCode,
    void Function(TranscriptionProgress progress)? onProgress,
  }) async {
    if (!isReady) {
      throw const ModelNotReadyException(
        'The on-device speech model is not installed yet.',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw const TranscriptionException(
        'The temporary recording could not be read. Please record again.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      await _deleteQuietly(path);
      throw const NoSpeechDetectedException();
    }

    final duration = Duration(
      milliseconds: (bytes.length / 2 / AudioCaptureService.sampleRate * 1000)
          .round(),
    );

    try {
      final segments = _vad.segment(bytes);
      if (segments.isEmpty) {
        throw const NoSpeechDetectedException();
      }

      final recognizer = await _recognizerFor(languageCode);
      final parts = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final text = await recognizer.transcribe(
          segments[i].bytes,
          language: languageCode,
        );
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) parts.add(trimmed);
        onProgress?.call(
          TranscriptionProgress(
            segmentIndex: i + 1,
            segmentCount: segments.length,
            overall: (i + 1) / segments.length,
          ),
        );
      }

      final merged = _merger.merge(parts);
      if (merged.trim().isEmpty) {
        throw const NoSpeechDetectedException();
      }

      return TranscriptionResult(
        text: merged,
        segmentCount: segments.length,
        audioDuration: duration,
        languageCode: languageCode,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw TranscriptionException(
        'On-device transcription failed. Please record again.',
        cause: error,
      );
    } finally {
      // The audio is temporary by design: remove it on success and failure.
      await _deleteQuietly(path);
    }
  }

  Future<SpeechRecognizer> _recognizerFor(String languageCode) async {
    if (_recognizer != null && _recognizerLanguage == languageCode) {
      return _recognizer!;
    }
    try {
      await _recognizer?.close();
    } catch (_) {
      // Switching languages is best effort; a stale recognizer is replaced.
    }
    _recognizer = null;
    _recognizerLanguage = null;

    try {
      final recognizer = await _recognizerLoader(languageCode);
      _recognizer = recognizer;
      _recognizerLanguage = languageCode;
      return recognizer;
    } catch (error) {
      throw TranscriptionException(
        'The speech model could not be prepared. Try again or reinstall it '
        'from Settings.',
        cause: error,
      );
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Never log or surface a temporary path; the OS cleans up on restart.
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recognizer?.close();
    } catch (_) {
      // Ignore teardown races.
    }
    _recognizer = null;
    _recognizerLanguage = null;
  }
}
