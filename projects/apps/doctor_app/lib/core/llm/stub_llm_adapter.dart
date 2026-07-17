import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';

/// Offline fallback LLM adapter.
///
/// Returns hardcoded, clearly-marked placeholder responses when neither
/// native on-device nor cloud inference is available. All outputs are
/// prefixed with `[OFFLINE MODE]` so the user knows they are not real
/// AI-generated content.
class StubLlmAdapter implements LlmPort {
  static const _prefix = '[OFFLINE MODE]';

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    return '$_prefix Processed text is unavailable offline. '
        'Original input has been preserved:\n\n$input';
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
      String transcriptText) async {
    return StructuredSummary(
      complaint: '$_prefix Not available offline.',
      pastHistory: '$_prefix Not available offline.',
      vitals: '$_prefix Not available offline.',
      physicalExamination: '$_prefix Not available offline.',
      investigationOrdered: '$_prefix Not available offline.',
      diagnosis: '$_prefix Not available offline.',
      advice:
          '$_prefix AI summarization is unavailable offline. '
          'Your transcript has been saved locally and will be processed '
          'when connectivity is restored.',
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
    return '$_prefix Executive summary is unavailable offline. '
        'Your transcript has been saved and will be processed when '
        'connectivity is restored.';
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    return '$_prefix Doctor note generation is unavailable offline.\n\n'
        'Your raw transcript has been preserved:\n$transcriptText';
  }
}
