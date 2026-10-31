/// Structured sections of a clinical note.
///
/// The six sections mirror the clinical documentation workflow used by the
/// on-device note assistant. All fields are nullable because a section may not
/// be discussed during a consultation; an absent section is not the same as a
/// negative finding.
class StructuredNoteSections {
  StructuredNoteSections({
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.examination,
    this.assessment,
    this.treatmentPlan,
    this.followUp,
  });

  factory StructuredNoteSections.fromJson(Map<String, dynamic> json) {
    final legacyPlan = _asString(json['planAndFollowUp']);
    return StructuredNoteSections(
      chiefComplaint: _asString(
        json['chiefComplaint'] ?? json['chief_complaint'],
      ),
      historyOfPresentIllness: _asString(
        json['historyOfPresentIllness'] ??
            json['history_of_present_illness'] ??
            json['hpi'],
      ),
      examination: _asString(
        json['examination'] ??
            json['physicalExamination'] ??
            json['physical_examination'],
      ),
      assessment: _asString(json['assessment'] ?? json['diagnosis']),
      treatmentPlan: _asString(
        json['treatmentPlan'] ??
            json['treatment_plan'] ??
            json['plan'] ??
            legacyPlan,
      ),
      followUp: _asString(json['followUp'] ?? json['follow_up']),
    );
  }

  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? examination;
  final String? assessment;
  final String? treatmentPlan;
  final String? followUp;

  /// Backwards-compatible view of the older four-section note format.
  ///
  /// Older persisted notes stored the plan and follow-up together. When such a
  /// note is loaded, [fromJson] places the legacy value in [treatmentPlan], so
  /// this getter joins the two fields without losing content.
  String? get planAndFollowUp {
    final parts = [treatmentPlan, followUp]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>();
    if (parts.isEmpty) return null;
    return parts.join('\n\n');
  }

  bool get isEmpty =>
      _isBlank(chiefComplaint) &&
      _isBlank(historyOfPresentIllness) &&
      _isBlank(examination) &&
      _isBlank(assessment) &&
      _isBlank(treatmentPlan) &&
      _isBlank(followUp);

  StructuredNoteSections copyWith({
    String? chiefComplaint,
    String? historyOfPresentIllness,
    String? examination,
    String? assessment,
    String? treatmentPlan,
    String? followUp,
  }) {
    return StructuredNoteSections(
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      historyOfPresentIllness:
          historyOfPresentIllness ?? this.historyOfPresentIllness,
      examination: examination ?? this.examination,
      assessment: assessment ?? this.assessment,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      followUp: followUp ?? this.followUp,
    );
  }

  Map<String, dynamic> toJson() => {
        'chiefComplaint': chiefComplaint,
        'historyOfPresentIllness': historyOfPresentIllness,
        'examination': examination,
        'assessment': assessment,
        'treatmentPlan': treatmentPlan,
        'followUp': followUp,
        // Kept for readers of the older four-section format.
        'planAndFollowUp': planAndFollowUp,
      };

  /// Plain-text rendering suitable for sharing or printing.
  String toPlainText() {
    final buffer = StringBuffer();
    void write(String label, String? value) {
      if (_isBlank(value)) return;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(label);
      buffer.writeln(value!.trim());
    }

    write('Chief complaint', chiefComplaint);
    write('History of present illness', historyOfPresentIllness);
    write('Examination', examination);
    write('Assessment', assessment);
    write('Treatment plan', treatmentPlan);
    write('Follow-up', followUp);
    return buffer.toString().trim();
  }

  static bool _isBlank(String? value) =>
      value == null || value.trim().isEmpty;

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  String toString() => 'StructuredNoteSections(${toJson()})';
}
