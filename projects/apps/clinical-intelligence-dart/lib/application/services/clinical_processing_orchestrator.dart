import '../../api/dto/clinical_processing_request.dart';
import '../../api/dto/clinical_processing_response.dart';
import '../../core/models/processing_mode.dart';
import 'terminology_assistance_service.dart';
import 'transcript_cleanup_service.dart';
import 'validation_service.dart';
import '../ports/llm_port.dart';

/// Orchestrates the clinical text processing pipeline (API Family A).
///
/// Routes processing to the appropriate service based on the requested mode.
/// Flow: validate → normalize → process → respond
class ClinicalProcessingOrchestrator {
  ClinicalProcessingOrchestrator({
    required this.validationService,
    required this.terminologyAssistanceService,
    required this.transcriptCleanupService,
    required this.llmPort,
  });

  final ValidationService validationService;
  final TerminologyAssistanceService terminologyAssistanceService;
  final TranscriptCleanupService transcriptCleanupService;
  final LlmPort llmPort;

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
      ProcessingMode.cleanTranscript => await _processCleanTranscript(request),
      ProcessingMode.summarize => await _processSummarize(request),
      ProcessingMode.generateDoctorNote => await _processGenerateDoctorNote(request),
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

  Future<ClinicalProcessingResponse> _processSummarize(
    ClinicalProcessingRequest request,
  ) async {
    final result = await llmPort.processText(request.inputText, ProcessingMode.summarize);

    return ClinicalProcessingResponse(
      processedText: result,
      processingMode: ProcessingMode.summarize,
      warnings: [],
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        if (request.consultationId != null)
          'consultationId': request.consultationId,
        if (request.source != null) 'source': request.source!.toJson(),
      },
    );
  }

  Future<ClinicalProcessingResponse> _processGenerateDoctorNote(
    ClinicalProcessingRequest request,
  ) async {
    final result = await llmPort.processText(request.inputText, ProcessingMode.generateDoctorNote);

    return ClinicalProcessingResponse(
      processedText: result,
      processingMode: ProcessingMode.generateDoctorNote,
      warnings: [],
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        if (request.consultationId != null)
          'consultationId': request.consultationId,
        if (request.source != null) 'source': request.source!.toJson(),
      },
    );
  }
}
