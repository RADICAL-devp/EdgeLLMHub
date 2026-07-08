import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_repository.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_summary_repository.dart';
import 'package:clinical_intelligence_dart/application/services/clinical_processing_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/doctor_note_generation_service.dart';
import 'package:clinical_intelligence_dart/application/services/summary_generation_service.dart';
import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/terminology_assistance_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_chunking_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_cleanup_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_summary_aggregation_service.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/stub_llm_adapter.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/ollama_llm_adapter.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/in_memory_summary_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/in_memory_transcript_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// Root middleware: dependency injection and CORS.
///
/// Provides all services to route handlers via Dart Frog's
/// [provider] middleware.
Handler middleware(Handler handler) {
  // --- Infrastructure ---
  final LlmPort llmPort = OllamaLlmAdapter();
  // To use Ollama for on-device LLM, uncomment:
  // final LlmPort llmPort = OllamaLlmAdapter();

  final transcriptRepository = InMemoryTranscriptRepository();
  final summaryRepository = InMemorySummaryRepository();

  // --- Application Services ---
  final validationService = ValidationService();
  final normalizationService = TranscriptNormalizationService();
  final chunkingService = TranscriptChunkingService();
  final aggregationService = TranscriptSummaryAggregationService();

  final terminologyAssistanceService = TerminologyAssistanceService(
    llmPort: llmPort,
    normalizationService: normalizationService,
  );

  final transcriptCleanupService = TranscriptCleanupService(
    llmPort: llmPort,
    normalizationService: normalizationService,
  );

  final summaryGenerationService = SummaryGenerationService(
    llmPort: llmPort,
  );

  final doctorNoteGenerationService = DoctorNoteGenerationService(
    llmPort: llmPort,
  );

  final clinicalProcessingOrchestrator = ClinicalProcessingOrchestrator(
    validationService: validationService,
    terminologyAssistanceService: terminologyAssistanceService,
    transcriptCleanupService: transcriptCleanupService,
  );

  final summaryOrchestrator = SummaryOrchestrator(
    validationService: validationService,
    normalizationService: normalizationService,
    chunkingService: chunkingService,
    summaryGenerationService: summaryGenerationService,
    doctorNoteGenerationService: doctorNoteGenerationService,
    aggregationService: aggregationService,
    transcriptRepository: transcriptRepository,
    summaryRepository: summaryRepository,
  );

  return handler
      .use(provider<ClinicalProcessingOrchestrator>(
        (_) => clinicalProcessingOrchestrator,
      ))
      .use(provider<SummaryOrchestrator>((_) => summaryOrchestrator))
      .use(provider<TranscriptRepository>((_) => transcriptRepository))
      .use(provider<TranscriptSummaryRepository>(
        (_) => summaryRepository,
      ))
      .use(_corsMiddleware());
}

/// CORS middleware for development.
Middleware _corsMiddleware() {
  return (handler) {
    return (context) async {
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    };
  };
}
