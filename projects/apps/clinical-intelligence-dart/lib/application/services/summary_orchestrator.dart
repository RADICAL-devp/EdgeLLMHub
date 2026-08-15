import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';

import '../../application/ports/embedding_service.dart';
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
///   5. Retrieve similar past consultations from the vector store
///   6. Run LLM generation (context-enriched structured summary,
///      executive summary, doctor note)
///   7. Aggregate chunk outputs if chunked
///   8. Generate embeddings for vector store
///   9. Persist summary bundle
///   10. Return response
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
    required this.embeddingService,
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
  final EmbeddingService embeddingService;
  final LlmPort llmPort;

  /// How many past consultations to retrieve as context, at most.
  static const int retrievalTopK = 3;

  /// Maximum characters of each retrieved past consultation to include.
  static const int retrievalTranscriptLimit = 2000;

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

    // 5. Retrieve similar past consultations from the vector store and use
    //    them as context for a context-enriched summary.
    final pastContext = await buildPastContext(normalizedText);

    // 6. Generate structured summary
    // For single chunk, generate directly. For multiple, aggregate.
    final generationInput = chunks.length == 1 ? chunks.first : normalizedText;
    final structuredSummary = pastContext.isEmpty
        ? await summaryGenerationService.generate(generationInput)
        : await llmPort.generateContextEnrichedSummary(
            generationInput,
            pastContext,
          );

    // 6b. Generate doctor note
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

  /// Build a context block from the most similar past consultations.
  ///
  /// Returns an empty string when no similar consultations exist (or the
  /// vector store is unavailable), so callers can skip context enrichment.
  Future<String> buildPastContext(
    String transcriptText, {
    int k = retrievalTopK,
  }) async {
    try {
      final query = await embeddingService.embed(transcriptText);
      final matches = await vectorStore.search(queryEmbedding: query, k: k);
      _log('Retrieved ${matches.length} similar past consultation(s)');

      final blocks = <String>[];
      for (final match in matches) {
        try {
          final metadata = match.metadata;
          final text = (metadata['transcriptText'] as String?) ?? '';
          final summary = metadata['structuredSummary'];
          if (text.isEmpty && summary == null) continue;
          blocks.add('Consultation ${match.id}:\n'
              '${text.length > retrievalTranscriptLimit ? text.substring(0, retrievalTranscriptLimit) : text}\n'
              'Summary: $summary');
        } catch (e) {
          _log('Skipping malformed vector match ${match.id}: $e');
        }
      }
      return blocks.join('\n\n---\n\n');
    } catch (e) {
      _log('Failed to retrieve past context (continuing without it): $e');
      return '';
    }
  }

  /// Store embeddings in vector store for future context-enriched queries.
  Future<void> _storeEmbeddings({
    required String consultationId,
    required String transcriptId,
    required String transcriptText,
    required StructuredSummary structuredSummary,
  }) async {
    try {
      final embedding = await embeddingService.embed(transcriptText);

      await vectorStore.add(
        id: consultationId,
        embedding: embedding,
        metadata: {
          'consultationId': consultationId,
          'transcriptId': transcriptId,
          'transcriptText':
              transcriptText.substring(0, 500), // Truncate for storage
          'structuredSummary': structuredSummary.toJson(),
          'resource_type': 'consultation',
          'resource_id': consultationId,
        },
      );
    } catch (e) {
      // Don't fail the request if vector store fails
      _log('Failed to store embedding: $e');
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[SummaryOrchestrator] $message');
  }

  /// Retrieve a previously generated summary.
  Future<TranscriptSummaryResponse?> getSummary(String consultationId) async {
    final bundle = await summaryRepository.findByConsultationId(consultationId);
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
