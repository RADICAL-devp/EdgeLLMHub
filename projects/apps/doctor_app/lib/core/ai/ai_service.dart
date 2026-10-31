import 'package:shared_models/shared_models.dart';

/// The app-facing AI contract. Implementations must be fully on-device.
abstract interface class AIService {
  bool get isReady;

  /// Turns a transcript into the six clinical sections.
  ///
  /// [onToken] receives only final-answer tokens (never hidden reasoning), so
  /// callers can show a live draft without storing chain-of-thought.
  Future<StructuredNoteSections> structureNote({
    required String transcript,
    required String languageCode,
    bool enableThinking = false,
    String patientName = '',
    void Function(String token)? onToken,
  });

  /// Removes filler and fixes punctuation without changing clinical meaning.
  Future<String> cleanTranscript({
    required String transcript,
    required String languageCode,
    bool enableThinking = false,
    void Function(String token)? onToken,
  });
}
