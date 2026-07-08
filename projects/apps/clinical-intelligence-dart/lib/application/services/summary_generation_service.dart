import '../ports/llm_port.dart';
import '../../core/models/structured_summary.dart';

/// Generates structured clinical summaries via LLM (Milestone 2).
///
/// TODO: Implement full summary generation with validation.
class SummaryGenerationService {
  SummaryGenerationService({required this.llmPort});

  final LlmPort llmPort;

  /// Generate a structured summary from normalized transcript text.
  Future<StructuredSummary> generate(String normalizedText) async {
    return llmPort.generateStructuredSummary(normalizedText);
  }
}
