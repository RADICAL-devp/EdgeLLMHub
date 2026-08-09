import 'dart:math' as math;

import 'package:uuid/uuid.dart';
import 'package:shared_models/shared_models.dart';

import '../../api/dto/transcript_summary_request.dart';
import '../../api/dto/transcript_summary_response.dart';
import '../../application/ports/vector_store_port.dart';
import '../ports/llm_port.dart';
import '../ports/transcript_repository.dart';
import '../ports/transcript_summary_repository.dart';
import 'doctor_note_generation_service.dart';
import 'summary_generation_service.dart';
import 'transcript_chunking_service.dart';
import 'transcript_normalization_service.dart';
import 'transcript_summary_aggregation_service.dart';
import 'validation_service.dart';

/// Orchestrates the full transcript summarization pipeline (API Family B).
///
/// Preserves the conceptual flow from the existing Micronaut backend:
///   1. Validate request
///   2. Persist transcript
///   3. Normalize transcript
///   4. Chunk transcript if needed
///   5. Run LLM generation (structured summary, executive summary, doctor note)
///   6. Aggregate chunk outputs if chunked
///   7. Generate embeddings for vector store
///   8. Persist summary bundle
///   9. Return response
///
/// Milestone 2: Partially implemented / scaffolded.
class SummaryOrchestrator {
  SummaryOrchestrator({
    required this.validationService,
    required this.normalizationService,
    required this.chunkingService,
    required this.summaryGenerationService,
    required this.doctorNoteGenerationService,
    required this.aggregationService,
    required this.transcriptRepository,
    required this.summaryRepository,
    required this.vectorStore,
    required this.llmPort,
  });

  final ValidationService validationService;
  final TranscriptNormalizationService normalizationService;
  final TranscriptChunkingService chunkingService;
  final SummaryGenerationService summaryGenerationService;
  final DoctorNoteGenerationService doctorNoteGenerationService;
  final TranscriptSummaryAggregationService aggregationService;
  final TranscriptRepository transcriptRepository;
  final TranscriptSummaryRepository summaryRepository;
  final VectorStorePort vectorStore;
  final LlmPort llmPort;

  /// Generate a full summary bundle from a transcript.
  Future<TranscriptSummaryResponse> generateSummary(
    TranscriptSummaryRequest request,
  ) async {
    // 1. Validate
    validationService.validateTranscriptSummaryRequest(
      consultationId: request.consultationId,
      patientId: request.patientId,
      doctorId: request.doctorId,
      transcriptText: request.transcriptText,
    );

    // 2. Persist transcript
    final transcriptId = const Uuid().v4();
    final transcript = ConsultationTranscript(
      transcriptId: transcriptId,
      consultationId: request.consultationId,
      patientId: request.patientId,
      doctorId: request.doctorId,
      sleepLabId: request.sleepLabId,
      transcriptText: request.transcriptText,
      consultationMode: request.consultationMode,
      createdAt: DateTime.now().toUtc(),
    );
    await transcriptRepository.save(transcript);

    // 3. Normalize
    final normalizedText =
        normalizationService.normalize(request.transcriptText);

    // 4. Chunk if needed
    final chunks = chunkingService.chunk(normalizedText);

    // 5. Generate structured summary
    // For single chunk, generate directly. For multiple, aggregate.
    final structuredSummary = await summaryGenerationService.generate(
      chunks.length == 1 ? chunks.first : normalizedText,
    );

    // 6. Generate doctor note
    final doctorNote = await doctorNoteGenerationService.generate(
      normalizedText: normalizedText,
      consultationId: request.consultationId,
      patientId: request.patientId,
      doctorId: request.doctorId,
    );

    // 7. Generate embeddings and store in vector store for context-enriched summaries
    await _storeEmbeddings(
      consultationId: request.consultationId,
      transcriptId: transcriptId,
      transcriptText: normalizedText,
      structuredSummary: structuredSummary,
    );

    // 8. Persist summary bundle
    final generatedAt = DateTime.now().toUtc().toIso8601String();
    final bundle = TranscriptSummaryBundle(
      consultationId: request.consultationId,
      transcriptId: transcriptId,
      structuredMedicalSummary: structuredSummary,
      doctorNote: doctorNote,
      generatedAt: generatedAt,
      consultationMode: request.consultationMode,
    );
    await summaryRepository.save(bundle);

    // 9. Return response
    return TranscriptSummaryResponse(
      consultationId: request.consultationId,
      transcriptId: transcriptId,
      structuredMedicalSummary: structuredSummary,
      doctorNote: doctorNote,
      generatedAt: generatedAt,
      consultationMode: request.consultationMode,
    );
  }

  /// Store embeddings in vector store for future context-enriched queries.
  Future<void> _storeEmbeddings({
    required String consultationId,
    required String transcriptId,
    required String transcriptText,
    required StructuredSummary structuredSummary,
  }) async {
    try {
      // Create embedding from transcript text (in production, use a proper embedding model)
      // For now, we'll use a simple hash-based approach as placeholder
      final embedding = _createPlaceholderEmbedding(transcriptText);

      await vectorStore.add(
        id: consultationId,
        embedding: embedding,
        metadata: {
          'consultationId': consultationId,
          'transcriptId': transcriptId,
          'transcriptText': transcriptText.substring(0, 500), // Truncate for storage
          'structuredSummary': structuredSummary.toJson(),
          'resource_type': 'consultation',
          'resource_id': consultationId,
        },
      );
    } catch (e) {
      // Don't fail the request if vector store fails
      print('[SummaryOrchestrator] Failed to store embedding: $e');
    }
  }

  /// Placeholder embedding generation.
  /// In production, replace with proper embedding model (e.g., sentence-transformers via Python bridge).
  List<double> _createPlaceholderEmbedding(String text) {
    final hash = text.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final random = List<double>.generate(960, (i) {
      return ((hash * (i + 1) * 16807) % 2147483647) / 2147483647.0;
    });
    // Normalize
    final norm = math.sqrt(random.fold(0.0, (a, b) => a + b * b));
    return random.map((v) => v / norm).toList();
  }

  /// Retrieve a previously generated summary.
  Future<TranscriptSummaryResponse?> getSummary(String consultationId) async {
    final bundle =
        await summaryRepository.findByConsultationId(consultationId);
    if (bundle == null) return null;

    return TranscriptSummaryResponse(
      consultationId: bundle.consultationId,
      transcriptId: bundle.transcriptId,
      executiveSummary: bundle.executiveSummary,
      structuredMedicalSummary: bundle.structuredMedicalSummary,
      doctorNote: bundle.doctorNote,
      generatedAt: bundle.generatedAt,
      consultationMode: bundle.consultationMode,
    );
  }

  /// Regenerate a summary for an existing transcript.
  Future<TranscriptSummaryResponse> regenerateSummary(
    String consultationId,
  ) async {
    final transcript =
        await transcriptRepository.findByConsultationId(consultationId);
    if (transcript == null) {
      throw ValidationException(
        'No transcript found for consultation: $consultationId',
      );
    }

    return generateSummary(
      TranscriptSummaryRequest(
        consultationId: transcript.consultationId,
        patientId: transcript.patientId ?? '',
        doctorId: transcript.doctorId ?? '',
        sleepLabId: transcript.sleepLabId,
        transcriptText: transcript.transcriptText,
        consultationMode: transcript.consultationMode,
      ),
    );
  }
}
