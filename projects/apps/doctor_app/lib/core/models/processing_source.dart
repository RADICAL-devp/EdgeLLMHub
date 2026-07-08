/// Source of the input text being processed.
enum ProcessingSource {
  voiceNotes,
  transcript;

  static ProcessingSource? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.toUpperCase().replaceAll('-', '_');
    return switch (normalized) {
      'VOICE_NOTES' || 'VOICENOTES' => ProcessingSource.voiceNotes,
      'TRANSCRIPT' => ProcessingSource.transcript,
      _ => null,
    };
  }

  String toJson() => switch (this) {
        ProcessingSource.voiceNotes => 'VOICE_NOTES',
        ProcessingSource.transcript => 'TRANSCRIPT',
      };
}
