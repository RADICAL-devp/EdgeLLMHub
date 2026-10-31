import 'dart:math' as math;

/// Joins chunk transcripts while removing duplicate words at chunk boundaries.
///
/// VAD segments normally meet at silence and have no overlap, but long regions
/// are split with a small overlap so a word cut at the 25-second boundary is
/// not lost. Deduplicating the overlapping words keeps the final transcript
/// readable.
class TranscriptMerger {
  const TranscriptMerger({this.maxOverlapWords = 12});

  final int maxOverlapWords;

  String merge(List<String> parts) {
    final cleaned = parts
        .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) return cleaned.first;

    final words = <String>[];
    for (final part in cleaned) {
      final next = part.split(' ').where((word) => word.isNotEmpty).toList();
      if (words.isEmpty) {
        words.addAll(next);
        continue;
      }

      var overlap = 0;
      final limit = math.min(
        maxOverlapWords,
        math.min(words.length, next.length),
      );
      for (var candidate = limit; candidate >= 1; candidate--) {
        final suffix = words
            .sublist(words.length - candidate)
            .map(_normalize)
            .toList();
        final prefix = next.take(candidate).map(_normalize).toList();
        if (_listEquals(suffix, prefix)) {
          overlap = candidate;
          break;
        }
      }
      words.addAll(next.skip(overlap));
    }

    return words.join(' ').trim();
  }

  static String _normalize(String word) => word.toLowerCase().replaceAll(
    RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true),
    '',
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
