import '../../core/models/consultation_mode.dart';
import '../../core/models/doctor_note.dart';
import '../../core/models/executive_summary.dart';
import '../../core/models/structured_summary.dart';

/// Response DTO for the transcript summary endpoint (Milestone 2).
class TranscriptSummaryResponse {
  TranscriptSummaryResponse({
    required this.consultationId,
    required this.transcriptId,
    this.executiveSummary,
    this.structuredMedicalSummary,
    this.doctorNote,
    required this.generatedAt,
    this.consultationMode,
  });

  final String consultationId;
  final String transcriptId;
  final ExecutiveSummary? executiveSummary;
  final StructuredSummary? structuredMedicalSummary;
  final DoctorNote? doctorNote;
  final String generatedAt;
  final ConsultationMode? consultationMode;

  Map<String, dynamic> toJson() => {
        'consultationId': consultationId,
        'transcriptId': transcriptId,
        'executiveSummary': executiveSummary?.toJson(),
        'structuredMedicalSummary': structuredMedicalSummary?.toJson(),
        'doctorNote': doctorNote?.toJson(),
        'generatedAt': generatedAt,
        'consultationMode': consultationMode?.toJson(),
      };
}
