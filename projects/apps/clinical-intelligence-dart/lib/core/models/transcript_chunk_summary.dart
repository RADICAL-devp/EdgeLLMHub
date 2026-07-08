import 'structured_summary.dart';

/// Summary generated for one chunk of a transcript.
class TranscriptChunkSummary {
  TranscriptChunkSummary({
    required this.chunkIndex,
    required this.chunkText,
    this.structuredSummary,
    this.rawSummaryText,
  });

  final int chunkIndex;
  final String chunkText;
  final StructuredSummary? structuredSummary;
  final String? rawSummaryText;

  Map<String, dynamic> toJson() => {
        'chunkIndex': chunkIndex,
        'chunkText': chunkText,
        'structuredSummary': structuredSummary?.toJson(),
        'rawSummaryText': rawSummaryText,
      };
}
