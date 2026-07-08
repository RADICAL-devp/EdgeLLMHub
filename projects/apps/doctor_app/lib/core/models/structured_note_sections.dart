/// Structured sections of a clinical note.
///
/// Ported from Java `StructuredNoteSections`.
class StructuredNoteSections {
  StructuredNoteSections({
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.assessment,
    this.planAndFollowUp,
  });

  factory StructuredNoteSections.fromJson(Map<String, dynamic> json) {
    return StructuredNoteSections(
      chiefComplaint: json['chiefComplaint'] as String?,
      historyOfPresentIllness: json['historyOfPresentIllness'] as String?,
      assessment: json['assessment'] as String?,
      planAndFollowUp: json['planAndFollowUp'] as String?,
    );
  }

  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? assessment;
  final String? planAndFollowUp;

  Map<String, dynamic> toJson() => {
        'chiefComplaint': chiefComplaint,
        'historyOfPresentIllness': historyOfPresentIllness,
        'assessment': assessment,
        'planAndFollowUp': planAndFollowUp,
      };
}
