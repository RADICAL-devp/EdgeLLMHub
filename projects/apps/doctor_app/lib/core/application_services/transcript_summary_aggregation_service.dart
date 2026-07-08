import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/models/transcript_chunk_summary.dart';

/// Aggregates summaries from multiple chunks into a single summary.
///
/// Deterministic: given the same chunk summaries, always produces the same
/// aggregate output.
///
/// TODO: Implement LLM-based aggregation for Milestone 2.
class TranscriptSummaryAggregationService {
  /// Aggregate multiple chunk summaries into a single structured summary.
  ///
  /// Strategy: concatenate fields from each chunk, separated by section markers.
  /// For production, this should use LLM-based merging.
  StructuredSummary aggregate(List<TranscriptChunkSummary> chunkSummaries) {
    if (chunkSummaries.isEmpty) {
      return StructuredSummary();
    }

    if (chunkSummaries.length == 1) {
      return chunkSummaries.first.structuredSummary ?? StructuredSummary();
    }

    // Deterministic aggregation: merge fields from all chunks
    final summaries = chunkSummaries
        .where((c) => c.structuredSummary != null)
        .map((c) => c.structuredSummary!)
        .toList();

    if (summaries.isEmpty) return StructuredSummary();

    return StructuredSummary(
      complaint: _mergeField(summaries, (s) => s.complaint),
      pastHistory: _mergeField(summaries, (s) => s.pastHistory),
      vitals: _mergeField(summaries, (s) => s.vitals),
      physicalExamination:
          _mergeField(summaries, (s) => s.physicalExamination),
      investigationOrdered:
          _mergeField(summaries, (s) => s.investigationOrdered),
      diagnosis: _mergeField(summaries, (s) => s.diagnosis),
      advice: _mergeField(summaries, (s) => s.advice),
    );
  }

  String _mergeField(
    List<StructuredSummary> summaries,
    String? Function(StructuredSummary) extractor,
  ) {
    final parts = summaries
        .map(extractor)
        .where((v) => v != null && v.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first!;

    // Deduplicate identical entries
    final unique = parts.toSet().toList();
    return unique.join(' | ');
  }
}
