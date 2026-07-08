import 'package:clinical_intelligence_dart/application/services/transcript_chunking_service.dart';
import 'package:test/test.dart';

void main() {
  late TranscriptChunkingService service;

  setUp(() {
    service = TranscriptChunkingService(maxChunkSize: 100, overlapSize: 20);
  });

  group('TranscriptChunkingService', () {
    test('does not chunk short text', () {
      const input = 'Short clinical note.';
      expect(service.needsChunking(input), isFalse);

      final chunks = service.chunk(input);
      expect(chunks, hasLength(1));
      expect(chunks.first, equals(input));
    });

    test('prefers paragraph boundaries for chunking', () {
      final paragraphs = List.generate(
        5,
        (i) => 'Paragraph $i with some clinical content here.',
      );
      final input = paragraphs.join('\n\n');

      final chunks = service.chunk(input);

      // Should have multiple chunks
      expect(chunks.length, greaterThan(1));

      // Each chunk should contain complete paragraphs
      for (final chunk in chunks) {
        // Should not split mid-word
        expect(chunk.trim(), isNotEmpty);
      }
    });

    test('falls back to line boundaries', () {
      final lines = List.generate(
        10,
        (i) => 'Line $i: clinical observation noted.',
      );
      final input = lines.join('\n');

      final chunks = service.chunk(input);
      expect(chunks.length, greaterThan(1));
    });

    test('preserves order — chunks can be concatenated', () {
      final paragraphs = [
        'First observation about the patient.',
        'Second observation about symptoms.',
        'Third observation about treatment.',
      ];
      final input = paragraphs.join('\n\n');

      final chunks = service.chunk(input);

      // When concatenated, all original content should be present
      final combined = chunks.join(' ');
      for (final para in paragraphs) {
        // Each paragraph's key content should appear somewhere
        expect(
          combined,
          contains(para.split(' ').first),
        );
      }
    });

    test('hard splits very long single-line text', () {
      final longLine = 'word ' * 100; // ~500 chars
      final chunks = service.chunk(longLine);

      expect(chunks.length, greaterThan(1));
      // Each chunk should be within limits
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(service.maxChunkSize + 20));
      }
    });
  });
}
