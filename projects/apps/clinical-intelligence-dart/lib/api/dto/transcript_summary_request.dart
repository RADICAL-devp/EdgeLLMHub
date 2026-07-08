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
    final consultationId = json['consultationId'] as String? ?? '';
    final patientId = json['patientId'] as String? ?? '';
    final doctorId = json['doctorId'] as String? ?? '';
    final sleepLabId = json['sleepLabId'] as String?;
    final mode = ConsultationMode.tryParse(json['consultationMode'] as String?);

    // Check if this is the Java ConsultationInput format
    if (json.containsKey('consultation')) {
      final consultation = json['consultation'] as Map<String, dynamic>;
      final transcriptText = _formatConsultationInput(consultation);
      return TranscriptSummaryRequest(
        consultationId: consultationId.isEmpty ? 'C-${DateTime.now().millisecondsSinceEpoch}' : consultationId,
        patientId: patientId.isEmpty ? (consultation['patientId'] as String? ?? '') : patientId,
        doctorId: doctorId.isEmpty ? (consultation['doctorId'] as String? ?? '') : doctorId,
        sleepLabId: sleepLabId ?? consultation['sleepLabId'] as String?,
        transcriptText: transcriptText,
        consultationMode: mode,
      );
    }

    return TranscriptSummaryRequest(
      consultationId: consultationId,
      patientId: patientId,
      doctorId: doctorId,
      sleepLabId: sleepLabId,
      transcriptText: json['transcriptText'] as String? ?? '',
      consultationMode: mode,
    );
  }

  static String _formatConsultationInput(Map<String, dynamic> c) {
    final buffer = StringBuffer();

    if (c['chiefComplaint'] != null) {
      buffer.writeln('Chief Complaint: ${c['chiefComplaint']}');
    }
    if (c['historyOfPresentIllness'] != null) {
      buffer.writeln('History of Present Illness: ${c['historyOfPresentIllness']}');
    }
    if (c['pastMedicalHistory'] != null) {
      buffer.writeln('Past Medical History: ${c['pastMedicalHistory']}');
    }

    final vitals = c['vitals'] as Map<String, dynamic>?;
    if (vitals != null) {
      buffer.write('Vitals: ');
      final parts = <String>[];
      if (vitals['bp'] != null) parts.add('BP: ${vitals['bp']}');
      if (vitals['hr'] != null) parts.add('HR: ${vitals['hr']}');
      if (vitals['spo2'] != null) parts.add('SpO2: ${vitals['spo2']}');
      if (vitals['temp'] != null) parts.add('Temp: ${vitals['temp']}');
      if (vitals['weight'] != null) parts.add('Weight: ${vitals['weight']}');
      if (vitals['height'] != null) parts.add('Height: ${vitals['height']}');
      if (vitals['bmi'] != null) parts.add('BMI: ${vitals['bmi']}');
      buffer.writeln(parts.join(', '));
    }

    if (c['physicalExamination'] != null) {
      buffer.writeln('Physical Examination: ${c['physicalExamination']}');
    }

    final investigations = c['investigationsOrdered'] as List<dynamic>?;
    if (investigations != null && investigations.isNotEmpty) {
      buffer.writeln('Investigations Ordered:');
      for (final inv in investigations) {
        final map = inv as Map<String, dynamic>;
        buffer.write(' - ${map['testName']} (Status: ${map['status']})');
        if (map['results'] != null) {
          buffer.write(' Results: ${map['results']}');
        }
        buffer.writeln();
      }
    }

    final meds = c['currentMedications'] as List<dynamic>?;
    if (meds != null && meds.isNotEmpty) {
      buffer.writeln('Current Medications: ${meds.join(', ')}');
    }

    final allergies = c['allergies'] as List<dynamic>?;
    if (allergies != null && allergies.isNotEmpty) {
      buffer.writeln('Allergies: ${allergies.join(', ')}');
    }

    if (c['notes'] != null) {
      buffer.writeln('Notes: ${c['notes']}');
    }

    return buffer.toString().trim();
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
