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
import 'package:clinical_intelligence_dart/infrastructure/llm/ollama_llm_adapter.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/clinical_database.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_summary_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_transcript_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// Root middleware: dependency injection, auth, audit, and CORS.
Handler middleware(Handler handler) {
  // --- Infrastructure ---
  final LlmPort llmPort = OllamaLlmAdapter();

  final database = ClinicalDatabase();

  // --- Crypto ---
  final aesGcmService = AesGcmService(
    masterKeyB64: Platform.environment['AES_MASTER_KEY'] ?? _devMasterKey,
  );

  // --- Repositories (with encryption) ---
  final transcriptRepository = DriftTranscriptRepository(database, aesGcmService);
  final summaryRepository = DriftSummaryRepository(database, aesGcmService);

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
    llmPort: llmPort,
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
      .use(provider<JwtService>((_) => jwtService))
      .use(provider<AuditLogger>((_) => auditLogger))
      .use(provider<ClinicalProcessingOrchestrator>(
        (_) => clinicalProcessingOrchestrator,
      ))
      .use(provider<SummaryOrchestrator>((_) => summaryOrchestrator))
      .use(provider<TranscriptRepository>((_) => transcriptRepository))
      .use(provider<TranscriptSummaryRepository>(
        (_) => summaryRepository,
      ))
      .use(authMiddleware(jwtService))
      .use(auditMiddleware(auditLogger))
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
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDZ9V8K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K9K
-----END PRIVATE KEY-----''';

const _devPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2fVfCvSvgvSvgvSvgvSv
gvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvg
vSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgv
SvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvS
vgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvg
vgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvg
vgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvg
vgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvgvSvg
vg==
-----END PUBLIC KEY-----''';

/// Development-only AES master key (256-bit, base64url encoded).
/// In production, key MUST come from environment variable.
/// Generate with: `openssl rand -base64 32 | tr '+/' '-_' | tr -d '='`
const _devMasterKey = 'dev-master-key-32-bytes-base64url-encoded-for-testing-only';
