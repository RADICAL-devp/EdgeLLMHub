import 'package:uuid/uuid.dart';

import '../../api/dto/transcript_summary_request.dart';
import '../../api/dto/transcript_summary_response.dart';
import '../../core/models/consultation_transcript.dart';
import '../../core/models/transcript_summary_bundle.dart';
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
///   7. Persist summary bundle
///   8. Return response
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
  });

  final ValidationService validationService;
  final TranscriptNormalizationService normalizationService;
  final TranscriptChunkingService chunkingService;
  final SummaryGenerationService summaryGenerationService;
  final DoctorNoteGenerationService doctorNoteGenerationService;
  final TranscriptSummaryAggregationService aggregationService;
  final TranscriptRepository transcriptRepository;
  final TranscriptSummaryRepository summaryRepository;

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

    // 7. Persist summary bundle
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

    // 8. Return response
    return TranscriptSummaryResponse(
      consultationId: request.consultationId,
      transcriptId: transcriptId,
      structuredMedicalSummary: structuredSummary,
      doctorNote: doctorNote,
      generatedAt: generatedAt,
      consultationMode: request.consultationMode,
    );
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
