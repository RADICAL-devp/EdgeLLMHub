/// Unified exception hierarchy for the app.
///
/// All domain-specific exceptions extend [AppException]. No other file should
/// define competing exception classes.
library;

class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// ---------------------------------------------------------------------------
// Model / inference exceptions
// ---------------------------------------------------------------------------

/// Base type for on-device AI failures.
class LlmException extends AppException {
  const LlmException(super.message, {super.cause});
}

/// The model could not be loaded or initialized.
class LlmInitializationException extends LlmException {
  const LlmInitializationException(super.message, {super.cause});
}

/// The model returned text that could not be parsed into a note.
class LlmParseException extends LlmException {
  const LlmParseException(super.message, {super.cause});
}

/// No model is installed/active yet.
class ModelNotReadyException extends LlmException {
  const ModelNotReadyException([
    super.message = 'The on-device AI model is not installed yet.',
  ]);
}

/// A model download or install failed.
class ModelInstallException extends AppException {
  const ModelInstallException(super.message, {super.cause});
}

/// The user cancelled a model download.
class DownloadCancelledException extends AppException {
  const DownloadCancelledException([
    super.message = 'Model download cancelled.',
  ]);
}

// ---------------------------------------------------------------------------
// Network exceptions (only used by the parked Agora integration)
// ---------------------------------------------------------------------------

class NetworkException extends AppException {
  final int? statusCode;
  final bool isTransient;

  const NetworkException(
    super.message, {
    super.cause,
    this.statusCode,
    this.isTransient = false,
  });
}

// ---------------------------------------------------------------------------
// Speech / transcription exceptions
// ---------------------------------------------------------------------------

class SpeechException extends AppException {
  const SpeechException(super.message, {super.cause});
}

class SpeechUnavailableException extends SpeechException {
  const SpeechUnavailableException([
    super.message =
        'Speech recognition is not available on this device or simulator.',
  ]);
}

class TranscriptionException extends SpeechException {
  const TranscriptionException(super.message, {super.cause});
}

class NoSpeechDetectedException extends TranscriptionException {
  const NoSpeechDetectedException([
    super.message = 'No speech was detected in the recording.',
  ]);
}

class MicrophonePermissionException extends SpeechException {
  const MicrophonePermissionException([
    super.message =
        'Microphone access is required to record a consultation. Enable it in '
        'the system settings and try again.',
  ]);
}

// ---------------------------------------------------------------------------
// Storage exceptions
// ---------------------------------------------------------------------------

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

class EncryptionException extends AppException {
  const EncryptionException(super.message, {super.cause});
}

// ---------------------------------------------------------------------------
// Validation / platform exceptions
// ---------------------------------------------------------------------------

class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

class UnsupportedPlatformException extends AppException {
  const UnsupportedPlatformException(super.message, {super.cause});
}

/// The user asked for a Wi-Fi-only download while not on Wi-Fi.
class WifiRequiredException extends AppException {
  const WifiRequiredException([
    super.message =
        'Model downloads are set to Wi-Fi only. Connect to Wi-Fi or allow '
        'mobile data for this download.',
  ]);
}

/// There is no network connection for a first-launch model download.
class NoNetworkException extends AppException {
  const NoNetworkException([
    super.message =
        'An internet connection is required once to download the on-device '
        'models.',
  ]);
}
