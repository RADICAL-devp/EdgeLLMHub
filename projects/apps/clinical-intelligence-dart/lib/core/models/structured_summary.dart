/// The 7-field structured output from clinical summarization.
///
/// Ported from Java `StructuredSummary`. Each field must be a non-empty string
/// for the summary to be considered complete.
class StructuredSummary {
  StructuredSummary({
    this.complaint,
    this.pastHistory,
    this.vitals,
    this.physicalExamination,
    this.investigationOrdered,
    this.diagnosis,
    this.advice,
  });

  factory StructuredSummary.fromJson(Map<String, dynamic> json) {
    return StructuredSummary(
      complaint: json['complaint'] as String?,
      pastHistory: json['pastHistory'] as String?,
      vitals: json['vitals'] as String?,
      physicalExamination: json['physicalExamination'] as String?,
      investigationOrdered: json['investigationOrdered'] as String?,
      diagnosis: json['diagnosis'] as String?,
      advice: json['advice'] as String?,
    );
  }

  final String? complaint;
  final String? pastHistory;
  final String? vitals;
  final String? physicalExamination;
  final String? investigationOrdered;
  final String? diagnosis;
  final String? advice;

  /// Whether all 7 required fields are non-null and non-empty.
  bool get isComplete =>
      _isPresent(complaint) &&
      _isPresent(pastHistory) &&
      _isPresent(vitals) &&
      _isPresent(physicalExamination) &&
      _isPresent(investigationOrdered) &&
      _isPresent(diagnosis) &&
      _isPresent(advice);

  bool _isPresent(String? value) => value != null && value.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'complaint': complaint,
        'pastHistory': pastHistory,
        'vitals': vitals,
        'physicalExamination': physicalExamination,
        'investigationOrdered': investigationOrdered,
        'diagnosis': diagnosis,
        'advice': advice,
      };
}
