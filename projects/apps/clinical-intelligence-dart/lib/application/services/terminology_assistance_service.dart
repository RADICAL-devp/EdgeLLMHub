import '../ports/llm_port.dart';
import '../../core/models/processing_mode.dart';
import 'transcript_normalization_service.dart';

/// VOCAB_ASSIST processing service.
///
/// Conservative terminology assistance:
///   - Improve dictated clinical text without changing medical meaning
///   - Fix obvious dictation, wording, punctuation, and formatting issues
///   - Standardize terminology where appropriate
///   - Preserve clinical intent
///   - Do NOT hallucinate facts not present in the input
///   - Do NOT invent diagnoses, medications, symptoms, or measurements
class TerminologyAssistanceService {
  TerminologyAssistanceService({
    required this.llmPort,
    required this.normalizationService,
  });

  final LlmPort llmPort;
  final TranscriptNormalizationService normalizationService;

  /// Process text with VOCAB_ASSIST mode.
  ///
  /// Steps:
  ///   1. Normalize whitespace
  ///   2. Send to LLM with vocab-assist prompt
  ///   3. Return improved text
  Future<TerminologyAssistResult> process(String inputText) async {
    // 1. Normalize
    final normalized = normalizationService.normalize(inputText);

    if (normalized.isEmpty) {
      return TerminologyAssistResult(
        processedText: '',
        warnings: ['Input text was empty after normalization.'],
      );
    }

    // 2. Process via LLM
    final processed = await llmPort.processText(
      normalized,
      ProcessingMode.vocabAssist,
    );

    // 3. Build result with warnings
    final warnings = <String>[];
    if (normalized.length < 10) {
      warnings.add('Input text is very short; limited improvement possible.');
    }

    return TerminologyAssistResult(
      processedText: processed,
      warnings: warnings,
    );
  }
}

class TerminologyAssistResult {
  TerminologyAssistResult({
    required this.processedText,
    this.warnings = const [],
  });

  final String processedText;
  final List<String> warnings;
}
