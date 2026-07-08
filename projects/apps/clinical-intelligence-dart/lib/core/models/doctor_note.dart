import 'extracted_clinical_fields.dart';
import 'structured_note_sections.dart';

/// A doctor note entity combining raw text, cleaned text, and structured output.
///
/// Ported from Java `DoctorNote` and Flutter `DoctorNote`.
class DoctorNote {
  DoctorNote({
    required this.noteId,
    this.consultationId,
    this.patientId,
    this.doctorId,
    this.rawText,
    this.cleanedText,
    this.structuredSections,
    this.extractedFields,
    this.recap,
    this.status = 'draft',
    this.modelVersion,
    this.aiGeneratedFields = const [],
    this.doctorEditedFields = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory DoctorNote.fromJson(Map<String, dynamic> json) {
    return DoctorNote(
      noteId: json['noteId'] as String,
      consultationId: json['consultationId'] as String?,
      patientId: json['patientId'] as String?,
      doctorId: json['doctorId'] as String?,
      rawText: json['rawText'] as String?,
      cleanedText: json['cleanedText'] as String?,
      structuredSections: json['structuredSections'] != null
          ? StructuredNoteSections.fromJson(
              json['structuredSections'] as Map<String, dynamic>,
            )
          : null,
      extractedFields: json['extractedFields'] != null
          ? ExtractedClinicalFields.fromJson(
              json['extractedFields'] as Map<String, dynamic>,
            )
          : null,
      recap: json['recap'] as String?,
      status: json['status'] as String? ?? 'draft',
      modelVersion: json['modelVersion'] as String?,
      aiGeneratedFields: (json['aiGeneratedFields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      doctorEditedFields: (json['doctorEditedFields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  final String noteId;
  final String? consultationId;
  final String? patientId;
  final String? doctorId;
  final String? rawText;
  final String? cleanedText;
  final StructuredNoteSections? structuredSections;
  final ExtractedClinicalFields? extractedFields;
  final String? recap;
  final String status;
  final String? modelVersion;
  final List<String> aiGeneratedFields;
  final List<String> doctorEditedFields;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'noteId': noteId,
        'consultationId': consultationId,
        'patientId': patientId,
        'doctorId': doctorId,
        'rawText': rawText,
        'cleanedText': cleanedText,
        'structuredSections': structuredSections?.toJson(),
        'extractedFields': extractedFields?.toJson(),
        'recap': recap,
        'status': status,
        'modelVersion': modelVersion,
        'aiGeneratedFields': aiGeneratedFields,
        'doctorEditedFields': doctorEditedFields,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
