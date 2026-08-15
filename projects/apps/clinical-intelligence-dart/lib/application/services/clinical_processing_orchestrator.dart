import 'package:shared_models/shared_models.dart';
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
      ProcessingMode.fullBundle => await _processFullBundle(request),
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

  /// Process all modes in one request (FULL_BUNDLE).
  Future<ClinicalProcessingResponse> _processFullBundle(
    ClinicalProcessingRequest request,
  ) async {
    // Run all processing modes in parallel
    final results = await Future.wait([
      terminologyAssistanceService.process(request.inputText),
      transcriptCleanupService.process(request.inputText),
      llmPort.processText(request.inputText, ProcessingMode.summarize),
      llmPort.processText(request.inputText, ProcessingMode.generateDoctorNote),
    ]);

    final vocabResult = results[0] as TerminologyAssistResult;
    final cleanupResult = results[1] as TranscriptCleanupResult;
    final summaryResult = results[2] as String;
    final doctorNoteResult = results[3] as String;

    // Collect all warnings
    final allWarnings = <String>[
      ...vocabResult.warnings,
      ...cleanupResult.warnings,
    ];

    // Combine all outputs
    final combinedOutput = StringBuffer();
    combinedOutput.writeln('=== VOCAB_ASSIST ===');
    combinedOutput.writeln(vocabResult.processedText);
    combinedOutput.writeln('');
    combinedOutput.writeln('=== CLEAN_TRANSCRIPT ===');
    combinedOutput.writeln(cleanupResult.processedText);
    combinedOutput.writeln('');
    combinedOutput.writeln('=== SUMMARY ===');
    combinedOutput.writeln(summaryResult);
    combinedOutput.writeln('');
    combinedOutput.writeln('=== DOCTOR_NOTE ===');
    combinedOutput.writeln(doctorNoteResult);

    return ClinicalProcessingResponse(
      processedText: combinedOutput.toString(),
      processingMode: ProcessingMode.fullBundle,
      warnings: allWarnings,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      metadata: {
        if (request.consultationId != null)
          'consultationId': request.consultationId,
        if (request.source != null) 'source': request.source!.toJson(),
        'vocabAssist': vocabResult.processedText,
        'cleanTranscript': cleanupResult.processedText,
        'summary': summaryResult,
        'doctorNote': doctorNoteResult,
        'hasSpeakerLabels': cleanupResult.hasSpeakerLabels,
        if (cleanupResult.detectedSpeakers.isNotEmpty)
          'detectedSpeakers': cleanupResult.detectedSpeakers,
      },
    );
  }
}
