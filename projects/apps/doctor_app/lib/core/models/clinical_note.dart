import 'package:equatable/equatable.dart';
import 'package:shared_models/shared_models.dart';

enum NoteStatus { draft, finalized }

/// The app's clinical note entity.
///
/// This is deliberately separate from the wire/persistence format: the
/// repository encrypts [title], [patientName], [transcript], and the
/// structured sections before they touch SQLite.
class ClinicalNote extends Equatable {
  const ClinicalNote({
    required this.id,
    required this.title,
    required this.patientName,
    required this.transcript,
    required this.sections,
    required this.status,
    required this.languageCode,
    required this.createdAt,
    required this.updatedAt,
    this.cleanedTranscript,
    this.thinkingModeUsed = false,
    this.modelName,
  });

  factory ClinicalNote.create({
    required String id,
    String title = '',
    String patientName = '',
    String transcript = '',
    StructuredNoteSections? sections,
    String languageCode = 'en',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return ClinicalNote(
      id: id,
      title: title.trim(),
      patientName: patientName.trim(),
      transcript: transcript,
      sections: sections ?? StructuredNoteSections(),
      status: NoteStatus.draft,
      languageCode: languageCode,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  final String id;
  final String title;
  final String patientName;

  /// Current transcript text.
  ///
  /// This starts as the raw speech-to-text output and is replaced by the
  /// accepted cleaned transcript after the user edits or accepts a cleanup.
  final String transcript;

  /// The accepted cleaned transcript, if a cleanup was applied.
  final String? cleanedTranscript;

  final StructuredNoteSections sections;
  final NoteStatus status;
  final String languageCode;
  final bool thinkingModeUsed;

  /// Non-PHI technical metadata (for support/debugging). Never log content.
  final String? modelName;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasTranscript => transcript.trim().isNotEmpty;
  bool get hasStructuredContent => !sections.isEmpty;

  String get displayTitle =>
      title.trim().isEmpty ? 'Untitled note' : title.trim();

  String get displayPatient =>
      patientName.trim().isEmpty ? 'No patient name' : patientName.trim();

  /// The text used by the in-memory search. Kept lowercase for comparisons.
  String get searchableText => [
    title,
    patientName,
    transcript,
    cleanedTranscript ?? '',
    sections.toPlainText(),
  ].join('\n').toLowerCase();

  /// A short, non-identifying list preview.
  String get snippet {
    final source = sections.chiefComplaint?.trim().isNotEmpty == true
        ? sections.chiefComplaint!.trim()
        : transcript.trim();
    if (source.isEmpty) return 'No transcript yet';
    final singleLine = source.replaceAll(RegExp(r'\s+'), ' ');
    return singleLine.length > 140
        ? '${singleLine.substring(0, 140)}…'
        : singleLine;
  }

  ClinicalNote copyWith({
    String? title,
    String? patientName,
    String? transcript,
    String? cleanedTranscript,
    StructuredNoteSections? sections,
    NoteStatus? status,
    String? languageCode,
    bool? thinkingModeUsed,
    String? modelName,
    DateTime? updatedAt,
  }) {
    return ClinicalNote(
      id: id,
      title: title ?? this.title,
      patientName: patientName ?? this.patientName,
      transcript: transcript ?? this.transcript,
      cleanedTranscript: cleanedTranscript ?? this.cleanedTranscript,
      sections: sections ?? this.sections,
      status: status ?? this.status,
      languageCode: languageCode ?? this.languageCode,
      thinkingModeUsed: thinkingModeUsed ?? this.thinkingModeUsed,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    patientName,
    transcript,
    cleanedTranscript,
    sections.toJson().toString(),
    status,
    languageCode,
    thinkingModeUsed,
    modelName,
    createdAt,
    updatedAt,
  ];
}
