/// Processing modes for the clinical text processing endpoint.
///
/// The backend is mode-driven: each mode triggers different processing logic.
enum ProcessingMode {
  /// Conservative terminology assistance — improves dictated clinical text
  /// without changing medical meaning.
  vocabAssist,

  /// Transcript cleanup — normalize whitespace, improve readability,
  /// preserve original meaning and speaker labels.
  cleanTranscript,

  /// Full summarization — generate structured clinical summary.
  summarize,

  /// Generate a doctor note from clinical text.
  generateDoctorNote,

  /// Full processing bundle — all outputs in one request.
  fullBundle;

  /// Parse from JSON string, case-insensitive.
  static ProcessingMode? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.toUpperCase().replaceAll('-', '_');
    return switch (normalized) {
      'VOCAB_ASSIST' || 'VOCABASSIST' => ProcessingMode.vocabAssist,
      'CLEAN_TRANSCRIPT' || 'CLEANTRANSCRIPT' => ProcessingMode.cleanTranscript,
      'SUMMARIZE' => ProcessingMode.summarize,
      'GENERATE_DOCTOR_NOTE' || 'GENERATEDOCTORNOTE' =>
        ProcessingMode.generateDoctorNote,
      'FULL_BUNDLE' || 'FULLBUNDLE' => ProcessingMode.fullBundle,
      _ => null,
    };
  }

  String toJson() => switch (this) {
        ProcessingMode.vocabAssist => 'VOCAB_ASSIST',
        ProcessingMode.cleanTranscript => 'CLEAN_TRANSCRIPT',
        ProcessingMode.summarize => 'SUMMARIZE',
        ProcessingMode.generateDoctorNote => 'GENERATE_DOCTOR_NOTE',
        ProcessingMode.fullBundle => 'FULL_BUNDLE',
      };
}
