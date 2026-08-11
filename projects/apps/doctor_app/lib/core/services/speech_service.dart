/// Abstract speech-to-text service.
///
/// Implementations:
///   - [LocalSpeechService] — native STT via speech_to_text package
///   - [CloudSpeechService] — HTTP-based STT for simulators
///   - [MockSpeechService] — canned responses for testing
abstract class SpeechService {
  /// Initialize the speech recognition engine.
  ///
  /// [locale] - BCP-47 locale code (e.g., 'en_US', 'en_GB', 'es_ES')
  /// [silenceTimeout] - Duration of silence before auto-stop (VAD)
  /// [listenTimeout] - Maximum total listening duration in seconds
  ///
  /// Returns true if initialization succeeded.
  /// Throws [SpeechException] if STT is not available.
  Future<bool> initialize({
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
  });

  /// Start listening for speech input.
  ///
  /// [onResult] is called with recognized text as it becomes available.
  /// For final results, medical term post-processing is applied.
  /// For partial results, light processing (capitalization only) is applied.
  /// Throws [SpeechException] on failure.
  Future<void> startListening(Function(String) onResult);

  /// Stop listening for speech input.
  Future<void> stopListening();

  /// Whether the service is currently listening.
  bool get isListening;

  /// Configure silence timeout for Voice Activity Detection (VAD).
  /// Only applicable to local STT implementations.
  void setSilenceTimeout(Duration timeout) {}

  /// Configure total listening timeout.
  void setListenTimeout(double seconds) {}
}
