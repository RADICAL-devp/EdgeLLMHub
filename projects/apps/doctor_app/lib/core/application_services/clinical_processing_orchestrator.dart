import 'package:doctor_app/core/dto/clinical_processing_request.dart';
import 'package:doctor_app/core/dto/clinical_processing_response.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'terminology_assistance_service.dart';
import 'transcript_cleanup_service.dart';
import 'validation_service.dart';

/// Orchestrates the clinical text processing pipeline (API Family A).
///
/// Routes processing to the appropriate service based on the requested mode.
/// Flow: validate → normalize → process → respond
class ClinicalProcessingOrchestrator {
  ClinicalProcessingOrchestrator({
    required this.validationService,
    required this.terminologyAssistanceService,
    required this.transcriptCleanupService,
  });

  final ValidationService validationService;
  final TerminologyAssistanceService terminologyAssistanceService;
  final TranscriptCleanupService transcriptCleanupService;

  /// Process the request and return a response.
  ///
  /// Throws [ValidationException] if the request is invalid.
  Future<ClinicalProcessingResponse> process(
    ClinicalProcessingRequest request,
  ) async {
    // 1. Validate
    validationService.validateClinicalProcessingRequest(request);

    // 2. Route to appropriate service based on mode
    final result = switch (request.processingMode) {
      ProcessingMode.vocabAssist => await _processVocabAssist(request),
      ProcessingMode.cleanTranscript =>
        await _processCleanTranscript(request),
      _ => throw ValidationException(
          'Processing mode ${request.processingMode.toJson()} '
          'is not yet implemented.',
        ),
    };

    return result;
  }

  Future<ClinicalProcessingResponse> _processVocabAssist(
    ClinicalProcessingRequest request,
  ) async {
    final result =
        await terminologyAssistanceService.process(request.inputText);

    return ClinicalProcessingResponse(
      processedText: result.processedText,
      processingMode: ProcessingMode.vocabAssist,
      warnings: result.warnings,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        if (request.consultationId != null)
          'consultationId': request.consultationId,
        if (request.source != null) 'source': request.source!.toJson(),
      },
    );
  }

  Future<ClinicalProcessingResponse> _processCleanTranscript(
    ClinicalProcessingRequest request,
  ) async {
    final result =
        await transcriptCleanupService.process(request.inputText);

    return ClinicalProcessingResponse(
      processedText: result.processedText,
      processingMode: ProcessingMode.cleanTranscript,
      warnings: result.warnings,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        'hasSpeakerLabels': result.hasSpeakerLabels,
        if (result.detectedSpeakers.isNotEmpty)
          'detectedSpeakers': result.detectedSpeakers,
        if (request.consultationId != null)
          'consultationId': request.consultationId,
        if (request.source != null) 'source': request.source!.toJson(),
      },
    );
  }
}
