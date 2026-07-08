import '../../core/models/processing_mode.dart';
import '../../core/models/structured_summary.dart';

/// Port for LLM-based text processing.
///
/// Abstracts the LLM provider (Ollama, OpenAI, or stub).
/// All implementations MUST be conservative and healthcare-safe:
///   - Do not hallucinate facts
///   - Do not infer unsupported diagnoses
///   - Preserve uncertainty and speaker intent
///   - Preserve medical meaning
///   - Clearly distinguish input-derived content from generated formatting
abstract class LlmPort {
  /// Process text according to the specified mode.
  ///
  /// Used by the generic clinical processing endpoint (API Family A).
  Future<String> processText(String input, ProcessingMode mode);

  /// Generate a structured 7-field clinical summary from transcript text.
  ///
  /// Used by the transcript summary endpoint (API Family B).
  Future<StructuredSummary> generateStructuredSummary(String transcriptText);

  /// Generate a context-enriched summary using past consultation context.
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  );

  /// Generate an executive summary from transcript text.
  Future<String> generateExecutiveSummary(String transcriptText);

  /// Generate a doctor note from transcript text.
  Future<String> generateDoctorNote(String transcriptText);
}
