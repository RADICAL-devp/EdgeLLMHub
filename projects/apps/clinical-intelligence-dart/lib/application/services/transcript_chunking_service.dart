/// Splits long transcripts into processable chunks.
///
/// Chunking strategy (in order of preference):
///   1. Paragraph boundaries (double newline)
///   2. Line boundaries (single newline)
///   3. Hard split at maxChunkSize (last resort)
///
/// This preserves semantic coherence within chunks.
class TranscriptChunkingService {
  TranscriptChunkingService({
    this.maxChunkSize = 3000,
    this.overlapSize = 200,
  });

  /// Maximum characters per chunk.
  final int maxChunkSize;

  /// Overlap between chunks to preserve context at boundaries.
  final int overlapSize;

  /// Whether the text needs chunking.
  bool needsChunking(String text) => text.length > maxChunkSize;

  /// Split text into chunks, preferring natural boundaries.
  List<String> chunk(String text) {
    if (!needsChunking(text)) return [text];

    final chunks = <String>[];

    // First, try paragraph-based splitting
    final paragraphs = text.split(RegExp(r'\n\s*\n'));

    if (paragraphs.length > 1) {
      chunks.addAll(_mergeToChunks(paragraphs, '\n\n'));
    } else {
      // Fall back to line-based splitting
      final lines = text.split('\n');
      if (lines.length > 1) {
        chunks.addAll(_mergeToChunks(lines, '\n'));
      } else {
        // Last resort: hard character split
        chunks.addAll(_hardSplit(text));
      }
    }

    return chunks;
  }

  /// Merge segments into chunks that respect maxChunkSize,
  /// joining with the specified separator.
  List<String> _mergeToChunks(List<String> segments, String separator) {
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;

      if (buffer.isNotEmpty &&
          buffer.length + separator.length + trimmed.length > maxChunkSize) {
        // Flush current buffer as a chunk
        chunks.add(buffer.toString().trim());
        buffer.clear();

        // Add overlap from the end of the previous chunk
        if (chunks.isNotEmpty && overlapSize > 0) {
          final lastChunk = chunks.last;
          if (lastChunk.length > overlapSize) {
            buffer.write(
              lastChunk.substring(lastChunk.length - overlapSize),
            );
            buffer.write(separator);
          }
        }
      }

      if (buffer.isNotEmpty) buffer.write(separator);
      buffer.write(trimmed);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks;
  }

  /// Hard split at character boundaries as last resort.
  List<String> _hardSplit(String text) {
    final chunks = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = start + maxChunkSize;
      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }

      // Try to find a space near the boundary
      final lastSpace = text.lastIndexOf(' ', end);
      if (lastSpace > start + maxChunkSize ~/ 2) {
        end = lastSpace;
      }

      chunks.add(text.substring(start, end).trim());
      
      final prevStart = start;
      start = end - overlapSize;
      if (start < 0) start = 0;
      
      // Avoid infinite loops
      if (start <= prevStart) {
        start = prevStart + 1;
      }
    }

    return chunks;
  }
}
