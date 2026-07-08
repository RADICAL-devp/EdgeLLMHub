import '../../api/dto/clinical_processing_request.dart';
import '../../core/models/processing_mode.dart';

/// Validates incoming requests.
///
/// Ported from Java `ValidationService` and extended for the clinical
/// processing endpoint.
class ValidationService {
  static const int maxPayloadBytes = 10 * 1024 * 1024; // 10MB

  /// Validate a clinical processing request.
  ///
  /// Throws [ValidationException] if validation fails.
  void validateClinicalProcessingRequest(ClinicalProcessingRequest request) {
    if (request.inputText.trim().isEmpty) {
      throw const ValidationException('inputText must not be empty.');
    }

    // Validate that the mode is a supported Milestone 1 mode, or a known mode.
    // M1 supports: VOCAB_ASSIST, CLEAN_TRANSCRIPT
    // M2 will add: SUMMARIZE, GENERATE_DOCTOR_NOTE, FULL_BUNDLE
    final supportedModes = {
      ProcessingMode.vocabAssist,
      ProcessingMode.cleanTranscript,
    };

    if (!supportedModes.contains(request.processingMode)) {
      throw ValidationException(
        'Unsupported processing mode: ${request.processingMode.toJson()}. '
        'Supported modes: ${supportedModes.map((m) => m.toJson()).join(', ')}',
      );
    }

    validatePayloadSize(request.inputText);
  }

  /// Validate that the serialized payload doesn't exceed the 10MB limit.
  void validatePayloadSize(String payload) {
    final sizeBytes = payload.codeUnits.length;
    if (sizeBytes > maxPayloadBytes) {
      throw const ValidationException(
        'Payload exceeds maximum allowed size of 10MB.',
      );
    }
  }

  /// Validate a transcript summary request (Milestone 2).
  void validateTranscriptSummaryRequest({
    required String consultationId,
    required String patientId,
    required String doctorId,
    required String transcriptText,
  }) {
    if (consultationId.trim().isEmpty) {
      throw const ValidationException('consultationId is required.');
    }
    if (patientId.trim().isEmpty) {
      throw const ValidationException('patientId is required.');
    }
    if (doctorId.trim().isEmpty) {
      throw const ValidationException('doctorId is required.');
    }
    if (transcriptText.trim().isEmpty) {
      throw const ValidationException(
        'transcriptText must not be empty.',
      );
    }
    validatePayloadSize(transcriptText);
  }
}

/// Exception thrown when validation fails.
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}
