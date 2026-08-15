import 'local_speech_service.dart';

/// iOS speech-to-text adapter.
///
/// The `speech_to_text` plugin bridges Apple's `Speech.framework` (SFSpeechRecognizer)
/// on iOS. This thin adapter is a distinct class so the platform contract is
/// explicit and the [SpeechServiceFactory] can route iOS devices here.
class IosSpeechService extends LocalSpeechService {
  /// Speech.framework runs on-device via SFSpeechRecognizer; network-based
  /// recognition (temporary access to on-device resources) is not used.
}