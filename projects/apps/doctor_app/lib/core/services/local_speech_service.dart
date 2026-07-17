import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'speech_service.dart';

/// Local speech-to-text service using the native speech_to_text package.
///
/// Wraps the speech_to_text plugin with proper error propagation:
///   - Throws [SpeechUnavailableException] if STT is not available
///     (e.g., on simulators) instead of silently printing.
///   - Throws [SpeechException] on runtime errors.
class LocalSpeechService implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          // Log but don't throw — errors during active listening are
          // handled via the stream/callback mechanism
          throw SpeechException(
            'Speech recognition error: ${error.errorMsg}',
          );
        },
        onStatus: (status) {
          // Status updates are informational
        },
      );
    } catch (e) {
      if (e is SpeechException) rethrow;
      throw SpeechException(
        'Failed to initialize speech recognition: $e',
        cause: e,
      );
    }

    if (!_isInitialized) {
      throw const SpeechUnavailableException(
        message: 'Speech recognition is not available on this device. '
            'This may be a simulator or a device without microphone support.',
      );
    }

    return _isInitialized;
  }

  @override
  Future<void> startListening(Function(String) onResult) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isInitialized && !_speech.isListening) {
      try {
        await _speech.listen(
          onResult: (result) {
            onResult(result.recognizedWords);
          },
        );
      } catch (e) {
        throw SpeechException(
          'Failed to start speech recognition: $e',
          cause: e,
        );
      }
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  @override
  bool get isListening => _speech.isListening;
}
