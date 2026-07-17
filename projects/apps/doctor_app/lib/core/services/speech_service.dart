/// Abstract speech-to-text service.
///
/// Implementations:
///   - [LocalSpeechService] — native STT via speech_to_text package
///   - [CloudSpeechService] — HTTP-based STT for simulators
///   - [MockSpeechService] — canned responses for testing
abstract class SpeechService {
  /// Initialize the speech recognition engine.
  ///
  /// Throws [SpeechException] if STT is not available.
  Future<bool> initialize();

  /// Start listening for speech input.
  ///
  /// [onResult] is called with recognized text as it becomes available.
  /// Throws [SpeechException] on failure.
  Future<void> startListening(Function(String) onResult);

  /// Stop listening for speech input.
  Future<void> stopListening();

  /// Whether the service is currently listening.
  bool get isListening;
}
