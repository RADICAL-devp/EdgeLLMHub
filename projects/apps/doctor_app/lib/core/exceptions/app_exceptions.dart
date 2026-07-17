/// Unified exception hierarchy for the Doctor App.
///
/// All domain-specific exceptions extend [AppException] so callers can
/// catch broadly (AppException) or narrowly (LlmException, etc.).
///
/// This is the SINGLE SOURCE OF TRUTH for exception types — no other
/// file should define competing exception classes.

/// Base exception for all app-level errors.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// ---------------------------------------------------------------------------
// LLM Exceptions
// ---------------------------------------------------------------------------

/// Thrown when LLM inference fails (on-device or cloud).
class LlmException extends AppException {
  final LlmProvider? provider;

  const LlmException(
    super.message, {
    super.cause,
    this.provider,
  });
}

/// Thrown when LLM model initialization or loading fails.
class LlmInitializationException extends LlmException {
  const LlmInitializationException(
    super.message, {
    super.cause,
    super.provider,
  });
}

/// Thrown when LLM inference produces an unparseable or invalid response.
class LlmParseException extends LlmException {
  const LlmParseException(
    super.message, {
    super.cause,
    super.provider,
  });
}

/// The LLM provider that generated an error.
enum LlmProvider {
  /// On-device MLC LLM (iOS)
  mlc,

  /// On-device Google AI Edge / flutter_gemma (Android)
  gemma,

  /// Cloud backend (Dart Frog + Ollama)
  cloud,

  /// Offline stub
  stub,
}

// ---------------------------------------------------------------------------
// Network Exceptions
// ---------------------------------------------------------------------------

/// Thrown on HTTP/network failures.
class NetworkException extends AppException {
  /// HTTP status code, if available.
  final int? statusCode;

  /// Whether this failure is transient and may succeed on retry.
  final bool isTransient;

  const NetworkException(
    super.message, {
    super.cause,
    this.statusCode,
    this.isTransient = false,
  });
}

/// Thrown when the circuit breaker is open and calls are being rejected.
class CircuitBreakerOpenException extends NetworkException {
  const CircuitBreakerOpenException({
    super.cause,
  }) : super(
          'Circuit breaker is open — too many consecutive failures',
          isTransient: true,
        );
}

// ---------------------------------------------------------------------------
// Speech Exceptions
// ---------------------------------------------------------------------------

/// Thrown when speech-to-text fails or is unavailable.
class SpeechException extends AppException {
  const SpeechException(super.message, {super.cause});
}

/// Thrown when STT is not available on the current device/simulator.
class SpeechUnavailableException extends SpeechException {
  const SpeechUnavailableException({
    String message =
        'Speech recognition is not available on this device or simulator.',
    super.cause,
  }) : super(message);
}

// ---------------------------------------------------------------------------
// Database Exceptions
// ---------------------------------------------------------------------------

/// Thrown on database read/write failures.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

/// Thrown when a database migration fails.
class DatabaseMigrationException extends DatabaseException {
  final int fromVersion;
  final int toVersion;

  const DatabaseMigrationException({
    required this.fromVersion,
    required this.toVersion,
    super.cause,
  }) : super('Database migration failed from v$fromVersion to v$toVersion');
}

// ---------------------------------------------------------------------------
// Validation Exceptions
// ---------------------------------------------------------------------------

/// Thrown when input validation fails (length, charset, prompt injection).
class ValidationException extends AppException {
  final ValidationFailureReason reason;

  const ValidationException(
    super.message, {
    super.cause,
    required this.reason,
  });
}

/// Why validation failed.
enum ValidationFailureReason {
  tooLong,
  invalidCharacters,
  emptyInput,
  promptInjection,
}

// ---------------------------------------------------------------------------
// Platform Exceptions
// ---------------------------------------------------------------------------

/// Thrown when the current platform does not support an operation.
class UnsupportedPlatformException extends AppException {
  const UnsupportedPlatformException(super.message, {super.cause});
}

// ---------------------------------------------------------------------------
// Compliance Exceptions
// ---------------------------------------------------------------------------

/// Thrown when an operation is blocked by compliance policy (e.g., PHI
/// cannot leave the device without legal sign-off).
class ComplianceException extends AppException {
  const ComplianceException(super.message, {super.cause});
}
