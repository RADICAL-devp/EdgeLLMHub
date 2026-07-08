import '../../core/models/consultation_mode.dart';

/// Request DTO for the transcript summary endpoint (Milestone 2).
class TranscriptSummaryRequest {
  TranscriptSummaryRequest({
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
    this.sleepLabId,
    required this.transcriptText,
    this.consultationMode,
  });

  factory TranscriptSummaryRequest.fromJson(Map<String, dynamic> json) {
    return TranscriptSummaryRequest(
      consultationId: json['consultationId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      sleepLabId: json['sleepLabId'] as String?,
      transcriptText: json['transcriptText'] as String? ?? '',
      consultationMode:
          ConsultationMode.tryParse(json['consultationMode'] as String?),
    );
  }

  final String consultationId;
  final String patientId;
  final String doctorId;
  final String? sleepLabId;
  final String transcriptText;
  final ConsultationMode? consultationMode;

  Map<String, dynamic> toJson() => {
        'consultationId': consultationId,
        'patientId': patientId,
        'doctorId': doctorId,
        if (sleepLabId != null) 'sleepLabId': sleepLabId,
        'transcriptText': transcriptText,
        if (consultationMode != null)
          'consultationMode': consultationMode!.toJson(),
      };
}
