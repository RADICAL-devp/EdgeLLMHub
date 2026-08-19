/// Patient context for EHR field pre-filling and AI assistance.
///
/// Contains patient demographic and consultation metadata that helps
/// the AI provide more accurate field-level suggestions.
class PatientContext {
  PatientContext({
    required this.patientName,
    required this.sleepLab,
    required this.consultationDate,
    required this.patientId,
    this.age,
    this.gender,
    this.referringDoctor,
  });

  factory PatientContext.fromJson(Map<String, dynamic> json) {
    return PatientContext(
      patientName: json['patientName'] as String? ?? '',
      sleepLab: json['sleepLab'] as String? ?? '',
      consultationDate: json['consultationDate'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      referringDoctor: json['referringDoctor'] as String?,
    );
  }

  /// Full patient name
  final String patientName;

  /// Sleep lab name/identifier
  final String sleepLab;

  /// Consultation date (ISO 8601 format)
  final String consultationDate;

  /// Patient ID
  final String patientId;

  /// Patient age (optional)
  final int? age;

  /// Patient gender (optional)
  final String? gender;

  /// Referring doctor (optional)
  final String? referringDoctor;

  Map<String, dynamic> toJson() => {
        'patientName': patientName,
        'sleepLab': sleepLab,
        'consultationDate': consultationDate,
        'patientId': patientId,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (referringDoctor != null) 'referringDoctor': referringDoctor,
      };

  /// Creates a formatted string for inclusion in LLM prompts
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('Patient: $patientName');
    buffer.writeln('Sleep Lab: $sleepLab');
    buffer.writeln('Date: $consultationDate');
    if (age != null) buffer.writeln('Age: $age');
    if (gender != null) buffer.writeln('Gender: $gender');
    if (referringDoctor != null) buffer.writeln('Referring Dr: $referringDoctor');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientContext &&
          runtimeType == other.runtimeType &&
          patientName == other.patientName &&
          sleepLab == other.sleepLab &&
          consultationDate == other.consultationDate &&
          patientId == other.patientId &&
          age == other.age &&
          gender == other.gender &&
          referringDoctor == other.referringDoctor;

  @override
  int get hashCode =>
      patientName.hashCode ^
      sleepLab.hashCode ^
      consultationDate.hashCode ^
      patientId.hashCode ^
      age.hashCode ^
      gender.hashCode ^
      referringDoctor.hashCode;
}