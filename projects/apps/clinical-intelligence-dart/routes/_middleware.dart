import 'dart:io';

import 'package:clinical_intelligence_dart/application/ports/doctor_note_repository.dart';
import 'package:clinical_intelligence_dart/application/ports/embedding_service.dart';
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
import 'package:clinical_intelligence_dart/core/audit/audit_logger.dart';
import 'package:clinical_intelligence_dart/core/audit/audit_middleware.dart';
import 'package:clinical_intelligence_dart/core/auth/auth_middleware.dart';
import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';
import 'package:clinical_intelligence_dart/core/observability/metric_registry.dart';
import 'package:clinical_intelligence_dart/core/observability/metrics_middleware.dart';
import 'package:clinical_intelligence_dart/infrastructure/embeddings/hash_embedding_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/embeddings/ollama_embedding_service.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/ollama_llm_adapter.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/stub_llm_adapter.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/clinical_database.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_doctor_note_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_summary_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_transcript_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/sqlite_vec_store.dart';
import 'package:dart_frog/dart_frog.dart';

/// Root middleware: dependency injection, auth, audit, metrics, and CORS.
Handler middleware(Handler handler) {
  // --- Observability ---
  final metricRegistry = MetricRegistry();

  // --- Infrastructure ---
  // Dev/CI default is the stub adapter (deterministic, no external deps).
  // Set OLLAMA_BASE_URL to use the Ollama adapter against a local model.
  final LlmPort llmPort = Platform.environment.containsKey('OLLAMA_BASE_URL')
      ? OllamaLlmAdapter(baseUrl: Platform.environment['OLLAMA_BASE_URL']!)
      : StubLlmAdapter();

  // Wrap the port so every LLM call is timed at a single central point.
  final instrumentedLlmPort = InstrumentedLlmPort(llmPort, metricRegistry);

  final database = ClinicalDatabase();

  // --- Embeddings (vector store) ---
  // Deterministic hashing by default; switch to Ollama embeddings by
  // setting OLLAMA_BASE_URL (and optionally OLLAMA_EMBEDDING_MODEL).
  final EmbeddingService embeddingService =
      Platform.environment.containsKey('OLLAMA_BASE_URL')
          ? OllamaEmbeddingService(
              baseUrl: Platform.environment['OLLAMA_BASE_URL']!,
              model: Platform.environment['OLLAMA_EMBEDDING_MODEL'] ??
                  'nomic-embed-text',
            )
          : HashEmbeddingService();

  // --- Crypto ---
  // Keys MUST come from environment variables. No hardcoded keys.
  final aesGcmService = AesGcmService(
    masterKeyB64: Platform.environment['AES_MASTER_KEY']
        ?? (throw StateError('AES_MASTER_KEY env var required')),
  );

  // --- Auth ---
  final jwtService = JwtService(
    privateKeyPem: Platform.environment['JWT_PRIVATE_KEY']
        ?? (throw StateError('JWT_PRIVATE_KEY env var required')),
    publicKeyPem: Platform.environment['JWT_PUBLIC_KEY']
        ?? (throw StateError('JWT_PUBLIC_KEY env var required')),
  );

  // --- Audit ---
  final auditLogger = AuditLogger(database);

  // --- Application Services ---
  final validationService = ValidationService();
  final normalizationService = TranscriptNormalizationService();
  final chunkingService = TranscriptChunkingService();
  final aggregationService = TranscriptSummaryAggregationService();

  final terminologyAssistanceService = TerminologyAssistanceService(
    llmPort: instrumentedLlmPort,
    normalizationService: normalizationService,
  );

  final transcriptCleanupService = TranscriptCleanupService(
    llmPort: instrumentedLlmPort,
    normalizationService: normalizationService,
  );

  final summaryGenerationService = SummaryGenerationService(
    llmPort: instrumentedLlmPort,
  );

  final doctorNoteGenerationService = DoctorNoteGenerationService(
    llmPort: instrumentedLlmPort,
  );

  final clinicalProcessingOrchestrator = ClinicalProcessingOrchestrator(
    validationService: validationService,
    terminologyAssistanceService: terminologyAssistanceService,
    transcriptCleanupService: transcriptCleanupService,
    llmPort: instrumentedLlmPort,
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
    vectorStore: SqliteVecStore(),
    embeddingService: embeddingService,
    llmPort: instrumentedLlmPort,
  );

  return handler
      .use(provider<JwtService>((_) => jwtService))
      .use(provider<AuditLogger>((_) => auditLogger))
      .use(provider<LlmPort>((_) => instrumentedLlmPort))
      .use(provider<MetricRegistry>((_) => metricRegistry))
      .use(provider<ClinicalProcessingOrchestrator>(
        (_) => clinicalProcessingOrchestrator,
      ))
      .use(provider<SummaryOrchestrator>((_) => summaryOrchestrator))
      .use(provider<TranscriptRepository>((_) => transcriptRepository))
      .use(provider<TranscriptSummaryRepository>(
        (_) => summaryRepository,
      ))
      .use(provider<DoctorNoteRepository>((_) => doctorNoteRepository))
      .use(authMiddleware(
        jwtService,
        exemptPaths: [
          'api/v1/auth/token',
          // Prometheus scrape endpoint — no bearer credentials required.
          'metrics',
        ],
      ))
      .use(auditMiddleware(auditLogger))
      .use(metricsMiddleware(metricRegistry))
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


