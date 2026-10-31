import 'dart:math' as math;
import 'dart:typed_data';

import 'package:doctor_app/core/services/vad_segmenter.dart';
import 'package:flutter_test/flutter_test.dart';

const int _sampleRate = 16000;

Uint8List _pcm({required int milliseconds, double amplitude = 0}) {
  final sampleCount = (_sampleRate * milliseconds / 1000).round();
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    final value = amplitude == 0
        ? 0
        : (math.sin(2 * math.pi * 220 * i / _sampleRate) * amplitude).round();
    data.setInt16(i * 2, value, Endian.little);
  }
  return bytes;
}

Uint8List _concat(List<Uint8List> parts) {
  final length = parts.fold<int>(0, (sum, part) => sum + part.length);
  final out = Uint8List(length);
  var offset = 0;
  for (final part in parts) {
    out.setAll(offset, part);
    offset += part.length;
  }
  return out;
}

void main() {
  group('VadSegmenter', () {
    const vad = VadSegmenter();

    test('returns no segments for silence', () {
      expect(vad.segment(_pcm(milliseconds: 2000)), isEmpty);
    });

    test('keeps speech surrounded by silence', () {
      final pcm = _concat([
        _pcm(milliseconds: 1500),
        _pcm(milliseconds: 1000, amplitude: 8000),
        _pcm(milliseconds: 1500),
      ]);

      final segments = vad.segment(pcm);
      expect(segments, hasLength(1));
      expect(segments.single.startSample, greaterThan(0));
      expect(segments.single.endSample, lessThan(pcm.length ~/ 2));
      expect(
        segments.single.durationAt(_sampleRate).inMilliseconds,
        greaterThanOrEqualTo(1000),
      );
      expect(segments.single.bytes, isNotEmpty);
    });

    test('drops clicks shorter than the minimum speech duration', () {
      expect(vad.segment(_pcm(milliseconds: 20, amplitude: 10000)), isEmpty);
    });

    test('splits long continuous speech into Whisper-safe segments', () {
      final segments = vad.segment(_pcm(milliseconds: 60000, amplitude: 8000));

      expect(segments.length, greaterThanOrEqualTo(3));
      for (final segment in segments) {
        expect(
          segment.durationAt(_sampleRate),
          lessThanOrEqualTo(const Duration(milliseconds: 25000)),
        );
      }
      // Consecutive chunks overlap so a word cut at the boundary survives.
      expect(segments[1].startSample, lessThan(segments[0].endSample));
    });

    test(
      'ignores a trailing partial frame instead of taking the whole file',
      () {
        final pcm = _pcm(milliseconds: 5, amplitude: 8000);
        expect(vad.segment(pcm), hasLength(1));
        expect(vad.segment(Uint8List(0)), isEmpty);
      },
    );
  });
}
