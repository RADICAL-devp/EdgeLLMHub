import 'consultation_mode.dart';
import 'doctor_note.dart';
import 'executive_summary.dart';
import 'structured_summary.dart';
import 'transcript_chunk_summary.dart';

/// The complete output bundle from transcript summarization.
///
/// Contains all generated artifacts: executive summary, structured medical
/// summary, doctor note, and optionally the per-chunk summaries.
class TranscriptSummaryBundle {
  TranscriptSummaryBundle({
    required this.consultationId,
    required this.transcriptId,
    this.executiveSummary,
    this.structuredMedicalSummary,
    this.doctorNote,
    this.chunkSummaries = const [],
    required this.generatedAt,
    this.consultationMode,
  });

  final String consultationId;
  final String transcriptId;
  final ExecutiveSummary? executiveSummary;
  final StructuredSummary? structuredMedicalSummary;
  final DoctorNote? doctorNote;
  final List<TranscriptChunkSummary> chunkSummaries;
  final String generatedAt;
  final ConsultationMode? consultationMode;

  Map<String, dynamic> toJson() => {
        'consultationId': consultationId,
        'transcriptId': transcriptId,
        'executiveSummary': executiveSummary?.toJson(),
        'structuredMedicalSummary': structuredMedicalSummary?.toJson(),
        'doctorNote': doctorNote?.toJson(),
        'chunkSummaries': chunkSummaries.map((c) => c.toJson()).toList(),
        'generatedAt': generatedAt,
        'consultationMode': consultationMode?.toJson(),
      };
}
