import 'package:equatable/equatable.dart';

enum NoteStatus { draft, aiSuggested, finalized }

class ExtractedFields extends Equatable {
  final List<String> symptoms;
  final String? duration;
  final List<String> medications;
  final List<String> allergies;
  final List<String> testsRecommended;
  final List<String> followUpActions;
  final String? provisionalDiagnosis;

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
    return ExtractedFields(
      symptoms: List<String>.from(json['symptoms'] ?? []),
      duration: json['duration'] as String?,
      medications: List<String>.from(json['medications'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      testsRecommended: List<String>.from(json['testsRecommended'] ?? []),
      followUpActions: List<String>.from(json['followUpActions'] ?? []),
      provisionalDiagnosis: json['provisionalDiagnosis'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symptoms': symptoms,
      'duration': duration,
      'medications': medications,
      'allergies': allergies,
      'testsRecommended': testsRecommended,
      'followUpActions': followUpActions,
      'provisionalDiagnosis': provisionalDiagnosis,
    };
  }

  @override
  List<Object?> get props => [
        symptoms,
        duration,
        medications,
        allergies,
        testsRecommended,
        followUpActions,
        provisionalDiagnosis,
      ];
}

class DoctorNote extends Equatable {
  final String noteId;
  final String consultationId;
  final String patientId;
  final String doctorId;
  final String rawText;
  final NoteStatus status;
  final ExtractedFields? extractedFields;
  final String? patientRecap;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DoctorNote({
    required this.noteId,
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
    required this.rawText,
    this.status = NoteStatus.draft,
    this.extractedFields,
    this.patientRecap,
    required this.createdAt,
    required this.updatedAt,
  });

  DoctorNote copyWith({
    String? noteId,
    String? consultationId,
    String? patientId,
    String? doctorId,
    String? rawText,
    NoteStatus? status,
    ExtractedFields? extractedFields,
    String? patientRecap,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorNote(
      noteId: noteId ?? this.noteId,
      consultationId: consultationId ?? this.consultationId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
      extractedFields: extractedFields ?? this.extractedFields,
      patientRecap: patientRecap ?? this.patientRecap,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        noteId,
        consultationId,
        patientId,
        doctorId,
        rawText,
        status,
        extractedFields,
        patientRecap,
        createdAt,
        updatedAt,
      ];
}
