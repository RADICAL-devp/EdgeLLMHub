import 'local_speech_service.dart';

/// Android speech-to-text adapter.
///
/// The `speech_to_text` plugin bridges Android `RecognizerIntent` (Google
/// speech services) on Android. This thin adapter is a distinct class so the
/// platform contract is explicit and the [SpeechServiceFactory] can route
/// Android devices here.
class AndroidSpeechService extends LocalSpeechService {}