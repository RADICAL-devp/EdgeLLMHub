import '../../application/ports/llm_port.dart';
import '../../core/models/processing_mode.dart';
import '../../core/models/structured_summary.dart';

/// Stub LLM adapter that performs on-device text processing without
/// requiring any external API or model.
///
/// Provides meaningful (non-trivial) text processing:
///   - VOCAB_ASSIST: regex-based punctuation/whitespace fixes, known
///     abbreviation expansion, capitalization
///   - CLEAN_TRANSCRIPT: whitespace normalization, paragraph formatting,
///     speaker label standardization
///   - Summary/Note modes: returns placeholder structured output
///
/// This adapter keeps the system fully runnable without API keys.
/// For production, swap to [OllamaLlmAdapter] or another LLM provider.
class StubLlmAdapter implements LlmPort {
  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    return switch (mode) {
      ProcessingMode.vocabAssist => _vocabAssist(input),
      ProcessingMode.cleanTranscript => _cleanTranscript(input),
      _ => input,
    };
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
    String transcriptText,
  ) async {
    // Stub: return placeholder indicating LLM not connected
    return StructuredSummary(
      complaint: '[Stub] See transcript for chief complaint.',
      pastHistory: '[Stub] See transcript for past medical history.',
      vitals: '[Stub] See transcript for vital signs.',
      physicalExamination: '[Stub] See transcript for physical examination.',
      investigationOrdered: '[Stub] See transcript for investigations.',
      diagnosis: '[Stub] LLM not connected — diagnosis not generated.',
      advice: '[Stub] LLM not connected — advice not generated.',
    );
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) async {
    return generateStructuredSummary(transcriptText);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    return '[Stub] Executive summary not generated — LLM not connected. '
        'Input length: ${transcriptText.length} chars.';
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    return '[Stub] Doctor note not generated — LLM not connected. '
        'Input length: ${transcriptText.length} chars.';
  }

  /// On-device VOCAB_ASSIST processing (no LLM required).
  String _vocabAssist(String input) {
    var result = input;

    // 1. Fix common dictation spacing issues
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');

    // 2. Capitalize first letter of sentences
    result = result.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );

    // 3. Ensure sentences end with punctuation
    result = result.trim();
    if (result.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(result)) {
      result = '$result.';
    }

    // 4. Standardize common medical abbreviations
    final abbreviations = <String, String>{
      'blood pressure': 'BP',
      'heart rate': 'HR',
      'respiratory rate': 'RR',
      'beats per minute': 'bpm',
      'milligrams': 'mg',
      'milliliters': 'mL',
      'twice daily': 'BID',
      'three times daily': 'TID',
      'four times daily': 'QID',
      'as needed': 'PRN',
      'by mouth': 'PO',
      'every day': 'daily',
      'history of present illness': 'HPI',
      'review of systems': 'ROS',
      'no known drug allergies': 'NKDA',
    };

    for (final entry in abbreviations.entries) {
      result = result.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }

    // 5. Fix common clinical punctuation: "BP 120 / 80" → "BP 120/80"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s*/\s*(\d+)'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );

    return result;
  }

  /// On-device CLEAN_TRANSCRIPT processing (no LLM required).
  String _cleanTranscript(String input) {
    var result = input;

    // 1. Normalize line endings
    result = result.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Collapse excessive blank lines (max 1 blank line)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 3. Collapse multiple spaces within lines
    result = result.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    // 4. Standardize speaker labels
    result = result.replaceAllMapped(
      RegExp(r'^(doctor|patient|nurse|clinician)\s*:\s*', 
        multiLine: true, caseSensitive: false),
      (m) {
        final speaker = m.group(1)!;
        final capitalized =
            speaker[0].toUpperCase() + speaker.substring(1).toLowerCase();
        return '$capitalized: ';
      },
    );

    // 5. Trim each line
    final lines = result.split('\n');
    result = lines.map((l) => l.trim()).join('\n');

    // 6. Trim the whole result
    result = result.trim();

    return result;
  }
}
