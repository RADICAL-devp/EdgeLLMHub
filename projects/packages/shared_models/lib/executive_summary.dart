/// A concise executive-level summary of a consultation.
class ExecutiveSummary {
  ExecutiveSummary({
    this.overview,
    this.keyFindings,
    this.primaryDiagnosis,
    this.recommendedActions,
    this.urgencyLevel,
  });

  factory ExecutiveSummary.fromJson(Map<String, dynamic> json) {
    return ExecutiveSummary(
      overview: json['overview'] as String?,
      keyFindings: (json['keyFindings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      primaryDiagnosis: json['primaryDiagnosis'] as String?,
      recommendedActions: (json['recommendedActions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      urgencyLevel: json['urgencyLevel'] as String?,
    );
  }

  final String? overview;
  final List<String>? keyFindings;
  final String? primaryDiagnosis;
  final List<String>? recommendedActions;
  final String? urgencyLevel;

  Map<String, dynamic> toJson() => {
        'overview': overview,
        'keyFindings': keyFindings,
        'primaryDiagnosis': primaryDiagnosis,
        'recommendedActions': recommendedActions,
        'urgencyLevel': urgencyLevel,
      };
}
