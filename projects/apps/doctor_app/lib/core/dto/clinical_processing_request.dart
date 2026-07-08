import 'package:doctor_app/core/models/consultation_mode.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/processing_source.dart';

/// Request DTO for the generic clinical text processing endpoint.
///
/// Supports the voice-notes workflow:
///   doctor dictates → app-side STT → raw text → backend processing → result
class ClinicalProcessingRequest {
  ClinicalProcessingRequest({
    required this.inputText,
    required this.processingMode,
    this.consultationId,
    this.patientId,
    this.doctorId,
    this.consultationMode,
    this.source,
  });

  factory ClinicalProcessingRequest.fromJson(Map<String, dynamic> json) {
    return ClinicalProcessingRequest(
      inputText: json['inputText'] as String? ?? '',
      processingMode:
          ProcessingMode.tryParse(json['processingMode'] as String?) ??
              ProcessingMode.vocabAssist,
      consultationId: json['consultationId'] as String?,
      patientId: json['patientId'] as String?,
      doctorId: json['doctorId'] as String?,
      consultationMode:
          ConsultationMode.tryParse(json['consultationMode'] as String?),
      source: ProcessingSource.tryParse(json['source'] as String?),
    );
  }

  final String inputText;
  final ProcessingMode processingMode;
  final String? consultationId;
  final String? patientId;
  final String? doctorId;
  final ConsultationMode? consultationMode;
  final ProcessingSource? source;

  Map<String, dynamic> toJson() => {
        'inputText': inputText,
        'processingMode': processingMode.toJson(),
        if (consultationId != null) 'consultationId': consultationId,
        if (patientId != null) 'patientId': patientId,
        if (doctorId != null) 'doctorId': doctorId,
        if (consultationMode != null)
          'consultationMode': consultationMode!.toJson(),
        if (source != null) 'source': source!.toJson(),
      };
}
