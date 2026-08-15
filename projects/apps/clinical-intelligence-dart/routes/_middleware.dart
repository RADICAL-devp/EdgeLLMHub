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
  final aesGcmService = AesGcmService(
    masterKeyB64: Platform.environment['AES_MASTER_KEY'] ?? _devMasterKey,
  );

  // --- Repositories (with encryption) ---
  final transcriptRepository =
      DriftTranscriptRepository(database, aesGcmService);
  final summaryRepository = DriftSummaryRepository(database, aesGcmService);
  final doctorNoteRepository =
      DriftDoctorNoteRepository(database, aesGcmService);

  // --- Auth ---
  final jwtService = JwtService(
    privateKeyPem: Platform.environment['JWT_PRIVATE_KEY'] ?? _devPrivateKey,
    publicKeyPem: Platform.environment['JWT_PUBLIC_KEY'] ?? _devPublicKey,
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

/// Development-only RSA keypair.
/// In production, keys MUST come from environment variables.
const _devPrivateKey = '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDBezQrknoUxPW4
xF+qZHtYE5BeSBPZMYbzhiBktPscpZZeCZqMrwNIu7oFbDdFoOQAaiKAe6boWnch
1EBL5u9Yr6PW/XVQD9RTsY02AyDpYTw2HJSFyRss6FA5Y7tm4Xb4A2l8aIiU0GVH
ItsEJC5iEpMUVB/uJyir8z6Gj7vUSG5EgIyQPFf07ovB70jHk2B67OUTV0mbxpHv
kcbNa3Z4o9OA8n0a8m7ss08aLR47t02RzCpSVj/hX01RvELFTwd9jNRLmWokqJHF
GpL5UpgUMbYqhml0yPH6V3bHZRNRfrFBm51tADFkTrxSEOfVFoJOyrRfZ3Q2AK9h
76VlhNp9AgMBAAECggEBAJLeRxfcNLeXWz9KMaRSah7NmwU2iXqRUfOBmQ1ZJFT2
jVIM0DiCkWeguPBs2PgNzYVTC6WkN2qhYVVYnQYA4ybbDO+hrm971J1DZgHeFhmS
KfaZc1Sq9+n63wrxXcwW0gwp6uT5JNRx7K83EjHulRb1Kph/000ghIsiNhBHAzl7
/9dUsmUDVLuqzBKExNoCRZaEqmR2p9pYT9KD6F2U4ffV9vDgzkiVVQZeBPt8hzOk
ndbeD9IDymB0guezcFDByAal3MIWMDhzMNwNOZHDj4T/iGcNfTReMlfUaeMOVpiP
q4/oAcp4a5h/ClCuP+mNK12OFvrdJt5pSfcxrc7I7YECgYEA5JcoVfWdJDi2LnxD
48l5Oh/mWINaT50vgfMM6PsJNNB/MW0wXj7Mi1CyVcozDoEnMtjnVtmrRotItiQw
u4yY3GChGnOjOZZwv0CxynzZXhLnjkvl+Hi0MOJcmfKy2YWVpaktMLGiFsz2VN2/
IhfnKF78etWA1o5izoMY9Qnz6DkCgYEA2K5UcAYZ7xf23kOA/seu6R1oJwmh+WR1
S0DGrbB52QaktiG3IhWeqo2EjGqqiFk+cOi13Fex2NANeajkLqtU5/y31l94SaIv
893lja8FekO9Jl/SNiWUuuM1qVqH0JP+RDk2koLKxoB72v4K1nmAA6gAghIk2icS
B8/6n3oEHGUCgYAwjWqj12dpKiKH/RzuZPy6u8vRQRUNk/VjRJyZX7i03xQlC2wa
mHwZmypFzozJp+ULh8abS+B1O2BWT5mKPHK7XErbs3QX5zxLYxJgT+Rbduh38OcH
v5uGRo4kpMgYK6d9aFGQ5innbeFkZTUTqMAQcxxteqvC5rtV4cKLSXHlAQKBgBK6
1v+r91fsiWFjEmZzmlH6QcOGGKM3JNBxc/sVkyLIaTp5JZxjpAh4HSoKGl2Y4UXf
R8EZL31fVpral4bVNoyrErUMIZiz1VNOLgaWR3HvIw2LIN+fVgDlnQDbm3vTHxqE
m4wElESeXJZseUFa1U77mbekm9zjnbJhLvfUE0DlAoGAS8V0oCRNkMPpxAvejK49
8uDAHg9zoZyGarTdL9WD86aPbYwAF3WaeloVBehugOxrK0Wr5CP6PVA445MJwgMm
2nEaPCuNTvO/y9ubAUFSeRqEMRHo+mxLppKmyGNp/hQZVyVrITCT2BDXnsq1GdD+
hFVSurtGYXaHhwgtno+3ddw=
-----END PRIVATE KEY-----''';

const _devPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwXs0K5J6FMT1uMRfqmR7
WBOQXkgT2TGG84YgZLT7HKWWXgmajK8DSLu6BWw3RaDkAGoigHum6Fp3IdRAS+bv
WK+j1v11UA/UU7GNNgMg6WE8NhyUhckbLOhQOWO7ZuF2+ANpfGiIlNBlRyLbBCQu
YhKTFFQf7icoq/M+ho+71EhuRICMkDxX9O6Lwe9Ix5NgeuzlE1dJm8aR75HGzWt2
eKPTgPJ9GvJu7LNPGi0eO7dNkcwqUlY/4V9NUbxCxU8HfYzUS5lqJKiRxRqS+VKY
FDG2KoZpdMjx+ld2x2UTUX6xQZudbQAxZE68UhDn1RaCTsq0X2d0NgCvYe+lZYTa
fQIDAQAB
-----END PUBLIC KEY-----''';

/// Development-only AES master key (256-bit, base64url encoded).
/// In production, key MUST come from environment variable.
/// Generate with: `openssl rand -base64 32 | tr '+/' '-_' | tr -d '='`
const _devMasterKey = '7DOi+T/bVoL8yBQpYcLlXOqNb4MwmeOQ8J0hOR/xCjM=';
