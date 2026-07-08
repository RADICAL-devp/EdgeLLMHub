/// Normalizes transcript text for processing.
///
/// Responsibilities:
///   - Normalize whitespace (collapse multiple spaces/newlines)
///   - Preserve speaker labels (e.g., "Doctor:", "Patient:")
///   - Preserve original meaning and ordering
///   - Trim leading/trailing whitespace
///   - Normalize line endings
class TranscriptNormalizationService {
  /// Speaker label pattern: e.g., "Doctor:", "Patient:", "Dr. Smith:", "Nurse:"
  static final _speakerLabelPattern =
      RegExp(r'^((?:Dr\.|Doctor|Patient|Nurse|Clinician)\s*[^:]*):',
          multiLine: true, caseSensitive: false);

  /// Normalize the given text, preserving order and speaker labels.
  String normalize(String text) {
    if (text.trim().isEmpty) return '';

    // 1. Normalize line endings to \n
    var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Process line-by-line to preserve speaker labels
    final lines = normalized.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        // Preserve paragraph breaks (one blank line max)
        if (result.isNotEmpty && result.last.isNotEmpty) {
          result.add('');
        }
        continue;
      }

      // Collapse multiple spaces within a line
      final collapsed = trimmed.replaceAll(RegExp(r'\s{2,}'), ' ');
      result.add(collapsed);
    }

    // Remove trailing blank lines
    while (result.isNotEmpty && result.last.isEmpty) {
      result.removeLast();
    }

    return result.join('\n');
  }

  /// Check if the text contains speaker labels.
  bool containsSpeakerLabels(String text) {
    return _speakerLabelPattern.hasMatch(text);
  }

  /// Extract speaker labels found in the text.
  List<String> extractSpeakerLabels(String text) {
    return _speakerLabelPattern
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }
}
