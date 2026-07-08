/// Extracted clinical fields from unstructured text.
///
/// Ported from Java `ExtractedClinicalFields` and Flutter `ExtractedFields`.
class ExtractedClinicalFields {
  ExtractedClinicalFields({
    this.symptoms = const [],
    this.duration,
    this.medications = const [],
    this.allergies = const [],
    this.testsRecommended = const [],
    this.followUpActions = const [],
    this.provisionalDiagnosis,
  });

  factory ExtractedClinicalFields.fromJson(Map<String, dynamic> json) {
    return ExtractedClinicalFields(
      symptoms: _parseStringList(json['symptoms']),
      duration: json['duration'] as String?,
      medications: _parseStringList(json['medications']),
      allergies: _parseStringList(json['allergies']),
      testsRecommended: _parseStringList(json['testsRecommended']),
      followUpActions: _parseStringList(json['followUpActions']),
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

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

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
