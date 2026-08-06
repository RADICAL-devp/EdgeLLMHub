/// Consultation mode — metadata for how the consultation was conducted.
///
/// Does NOT create separate processing engines; this is informational only.
enum ConsultationMode {
  inPerson,
  online;

  /// Parse from JSON string, case-insensitive.
  static ConsultationMode? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.toUpperCase().replaceAll('-', '_');
    return switch (normalized) {
      'IN_PERSON' || 'INPERSON' => ConsultationMode.inPerson,
      'ONLINE' => ConsultationMode.online,
      _ => null,
    };
  }

  String toJson() => switch (this) {
        ConsultationMode.inPerson => 'IN_PERSON',
        ConsultationMode.online => 'ONLINE',
      };
}
