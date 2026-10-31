/// App-wide constants that are safe to reference from any layer.
///
/// Patient data must never be placed here. Runtime preferences live in
/// [SettingsService]; model choices live in `model_config.dart`.
class AppConfig {
  AppConfig._();

  static const String appName = 'Clinical Notes AI';
  static const String appVersion = '1.0.0';

  /// Debounce used by the note editor before writing a draft to disk.
  static const Duration autoSaveDebounce = Duration(seconds: 2);

  /// Debounce used by the note search field.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Context window requested from the on-device language model.
  ///
  /// This covers the prompt, the transcript, and the reply. The transcript is
  /// compacted before it is sent if it would not fit.
  static const int llmContextTokens = 8192;

  /// Maximum number of tokens the model may generate for a structured note.
  static const int llmMaxOutputTokens = 1400;

  /// Hard stop for transcript length stored from one recording. This is a
  /// safety limit, not a clinical limit (~2 hours of speech).
  static const int maxTranscriptCharacters = 240000;

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi',
  };

  static const String defaultLanguageCode = 'en';

  static String languageName(String code) =>
      supportedLanguages[code] ?? supportedLanguages[defaultLanguageCode]!;

  static const String privacySummary =
      'Audio, transcripts, and notes stay on this device. Nothing is sent to '
      'a server. The AI models run locally and the app has no account system.';

  static const String aiDraftDisclaimer =
      'AI-generated notes are drafts. A qualified clinician must review and '
      'correct every section before using the note for care. The model can '
      'omit, mishear, or invent details.';

  static const String audioDeletionNotice =
      'The temporary audio file is deleted immediately after transcription.';

  static const String thinkingModeWarning =
      'Thinking mode asks the model to reason before writing. On a phone this will '
      'take longer — often 30–90 seconds — and uses more battery. Leave it off '
      'unless you need extra help with a complex note.';
}
