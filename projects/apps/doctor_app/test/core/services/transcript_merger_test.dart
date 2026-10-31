import 'package:doctor_app/core/services/transcript_merger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptMerger', () {
    const merger = TranscriptMerger();

    test('returns an empty string when there is no speech', () {
      expect(merger.merge(const []), '');
      expect(merger.merge(const ['', '   ']), '');
    });

    test('normalizes whitespace and joins one part unchanged', () {
      expect(
        merger.merge(const ['  The patient\nhas   chest pain.  ']),
        'The patient has chest pain.',
      );
    });

    test('removes duplicated words at a chunk overlap', () {
      final merged = merger.merge(const [
        'The patient has chest pain',
        'chest pain and shortness of breath.',
      ]);
      expect(merged, 'The patient has chest pain and shortness of breath.');
    });

    test('matches overlap case-insensitively and ignores punctuation', () {
      final merged = merger.merge(const [
        'Reports CHEST PAIN,',
        'chest pain since yesterday.',
      ]);
      expect(merged, 'Reports CHEST PAIN, since yesterday.');
    });

    test('does not remove words that merely occur earlier in the text', () {
      final merged = merger.merge(const [
        'Chest pain started yesterday.',
        'Pain is worse at night.',
      ]);
      expect(merged, 'Chest pain started yesterday. Pain is worse at night.');
    });

    test('honors the maximum overlap window', () {
      const limited = TranscriptMerger(maxOverlapWords: 2);
      final merged = limited.merge(const [
        'one two three four',
        'three four five six',
      ]);
      expect(merged, 'one two three four five six');
    });
  });
}
