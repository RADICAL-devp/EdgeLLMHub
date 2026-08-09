/// Extracted clinical fields attached to a doctor note.
class ExtractedFields {
  const ExtractedFields({
    this.symptoms = const [],
    this.duration,
    this.medications = const [],
    this.allergies = const [],
    this.testsRecommended = const [],
    this.followUpActions = const [],
    this.provisionalDiagnosis,
  });

  factory ExtractedFields.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) =>
        (value as List<dynamic>? ?? const []).cast<String>();
    return ExtractedFields(
      symptoms: asStringList(json['symptoms']),
      duration: json['duration'] as String?,
      medications: asStringList(json['medications']),
      allergies: asStringList(json['allergies']),
      testsRecommended: asStringList(json['testsRecommended']),
      followUpActions: asStringList(json['followUpActions']),
      provisionalDiagnosis: json['provisionalDiagnosis'] as String?,
    );
  }

  final List<String> symptoms;
  final String? duration;
  final List<String> medications;
  final List<String> allergies;
  final List<String> testsRecommended;
  final List<String> followUpActions;
  final String? provisionalDiagnosis;

  Map<String, dynamic> toJson() => {
        'symptoms': symptoms,
        'duration': duration,
        'medications': medications,
        'allergies': allergies,
        'testsRecommended': testsRecommended,
        'followUpActions': followUpActions,
        'provisionalDiagnosis': provisionalDiagnosis,
      };
}

/// Doctor note synced from the mobile app (wire-compatible with the
/// doctor_app DoctorNote model).
class DoctorNote {
  const DoctorNote({
    required this.noteId,
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
    required this.rawText,
    this.richTextDelta,
    this.status = 'draft',
    this.extractedFields,
    this.patientRecap,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DoctorNote.fromJson(Map<String, dynamic> json) {
    return DoctorNote(
      noteId: json['noteId'] as String,
      consultationId: json['consultationId'] as String,
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      rawText: json['rawText'] as String? ?? '',
      richTextDelta: json['richTextDelta'] as String?,
      status: json['status'] as String? ?? 'draft',
      extractedFields: json['extractedFields'] != null
          ? ExtractedFields.fromJson(
              json['extractedFields'] as Map<String, dynamic>,
            )
          : null,
      patientRecap: json['patientRecap'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String noteId;
  final String consultationId;
  final String patientId;
  final String doctorId;
  final String rawText;

  /// Serialized Quill Delta JSON for the rich-text editor.
  final String? richTextDelta;
  final String status;
  final ExtractedFields? extractedFields;
  final String? patientRecap;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'noteId': noteId,
        'consultationId': consultationId,
        'patientId': patientId,
        'doctorId': doctorId,
        'rawText': rawText,
        'richTextDelta': richTextDelta,
        'status': status,
        'extractedFields': extractedFields?.toJson(),
        'patientRecap': patientRecap,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
