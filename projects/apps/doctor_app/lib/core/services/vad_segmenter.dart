import 'dart:math' as math;
import 'dart:typed_data';

/// A contiguous slice of 16-bit PCM audio selected by [VadSegmenter].
class PcmSegment {
  const PcmSegment({
    required this.bytes,
    required this.startSample,
    required this.endSample,
  });

  final Uint8List bytes;
  final int startSample;
  final int endSample;

  int get sampleCount => endSample - startSample;

  Duration durationAt(int sampleRate) =>
      Duration(milliseconds: (sampleCount * 1000 / sampleRate).round());
}

/// Energy-based voice activity detection.
///
/// Whisper's LiteRT profile processes 30-second windows, so long consultations
/// must be cut at natural pauses. The segmenter also avoids sending minutes of
/// silence to the recognizer, which is both slower and more error-prone.
///
/// The implementation is pure Dart so it can be unit-tested with synthetic
/// PCM. It is intentionally conservative: quiet speech is kept rather than
/// discarded, and padding is added around each detected region.
class VadSegmenter {
  const VadSegmenter({
    this.sampleRate = 16000,
    this.frameMs = 20,
    this.silenceMs = 450,
    this.minSpeechMs = 200,
    this.maxSegmentMs = 25000,
    this.paddingMs = 180,
    this.overlapMs = 400,
  });

  final int sampleRate;
  final int frameMs;
  final int silenceMs;
  final int minSpeechMs;
  final int maxSegmentMs;
  final int paddingMs;
  final int overlapMs;

  int get _frameSamples => (sampleRate * frameMs) ~/ 1000;

  /// Returns an empty list when the audio contains no detectable speech.
  List<PcmSegment> segment(Uint8List pcmBytes) {
    if (pcmBytes.length < 4) return const [];

    final totalSamples = pcmBytes.length ~/ 2;
    final samples = _readInt16(pcmBytes, totalSamples);
    final frameSamples = _frameSamples;
    if (frameSamples <= 0 || totalSamples < frameSamples) {
      return _fallback(samples, pcmBytes, totalSamples);
    }

    final frameCount = totalSamples ~/ frameSamples;
    if (frameCount == 0) return const [];

    final rms = List<double>.filled(frameCount, 0);
    for (var frame = 0; frame < frameCount; frame++) {
      var sum = 0.0;
      final offset = frame * frameSamples;
      for (var i = 0; i < frameSamples; i++) {
        final value = samples[offset + i] / 32768.0;
        sum += value * value;
      }
      rms[frame] = math.sqrt(sum / frameSamples);
    }

    final peak = rms.reduce(math.max);
    if (peak < 0.0005) return const [];

    final noiseFloor = _percentile(rms, 0.15);
    final adaptive = math.max(noiseFloor * 1.8, 0.0037); // ~120/32768
    final threshold = math.min(adaptive, math.max(peak * 0.35, 0.0037));

    final speech = List<bool>.generate(frameCount, (i) => rms[i] >= threshold);

    // Remove isolated clicks shorter than the minimum speech duration.
    final minFrames = math.max(2, (minSpeechMs / frameMs).round());
    _dropShortRuns(speech, minFrames);

    // Join runs separated by a short pause so a sentence is not chopped in two.
    final gapFrames = math.max(1, (silenceMs / frameMs).round());
    _fillShortGaps(speech, gapFrames);

    final runs = _runs(speech);
    if (runs.isEmpty) return const [];

    final paddingFrames = math.max(0, (paddingMs / frameMs).round());
    final merged = <_Run>[];
    for (final run in runs) {
      final padded = _Run(
        math.max(0, run.start - paddingFrames),
        math.min(frameCount, run.end + paddingFrames),
      );
      if (merged.isNotEmpty && padded.start <= merged.last.end) {
        merged[merged.length - 1] = _Run(
          merged.last.start,
          math.max(merged.last.end, padded.end),
        );
      } else {
        merged.add(padded);
      }
    }

    final maxFrames = math.max(1, (maxSegmentMs / frameMs).round());
    final overlapFrames = math.max(0, (overlapMs / frameMs).round());
    final result = <PcmSegment>[];

    for (final run in merged) {
      var start = run.start;
      while (start < run.end) {
        var end = math.min(run.end, start + maxFrames);
        if (end - start < minFrames) break;
        final startSample = start * frameSamples;
        final endSample = math.min(totalSamples, end * frameSamples);
        if (endSample > startSample) {
          result.add(
            PcmSegment(
              bytes: Uint8List.sublistView(
                pcmBytes,
                startSample * 2,
                endSample * 2,
              ),
              startSample: startSample,
              endSample: endSample,
            ),
          );
        }
        if (end >= run.end) break;
        final next = end - overlapFrames;
        start = next > start ? next : end;
      }
    }
    return result;
  }

  List<PcmSegment> _fallback(
    List<int> samples,
    Uint8List bytes,
    int totalSamples,
  ) {
    if (samples.isEmpty) return const [];
    var sum = 0.0;
    for (final value in samples) {
      final normalized = value / 32768.0;
      sum += normalized * normalized;
    }
    final rms = math.sqrt(sum / samples.length);
    if (rms < 0.0037) return const [];
    return [PcmSegment(bytes: bytes, startSample: 0, endSample: totalSamples)];
  }

  static List<int> _readInt16(Uint8List bytes, int sampleCount) {
    final samples = List<int>.filled(sampleCount, 0);
    for (var i = 0; i < sampleCount; i++) {
      final raw = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      samples[i] = raw >= 0x8000 ? raw - 0x10000 : raw;
    }
    return samples;
  }

  static double _percentile(List<double> values, double fraction) {
    final sorted = List<double>.from(values)..sort();
    final index = ((sorted.length - 1) * fraction).round();
    return sorted[index];
  }

  static void _dropShortRuns(List<bool> flags, int minLength) {
    var i = 0;
    while (i < flags.length) {
      if (!flags[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j < flags.length && flags[j]) {
        j++;
      }
      if (j - i < minLength) {
        for (var k = i; k < j; k++) {
          flags[k] = false;
        }
      }
      i = j;
    }
  }

  static void _fillShortGaps(List<bool> flags, int maxGap) {
    var i = 0;
    while (i < flags.length) {
      if (flags[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j < flags.length && !flags[j]) {
        j++;
      }
      final isInternal = i > 0 && j < flags.length;
      if (isInternal && j - i <= maxGap) {
        for (var k = i; k < j; k++) {
          flags[k] = true;
        }
      }
      i = j;
    }
  }

  static List<_Run> _runs(List<bool> flags) {
    final runs = <_Run>[];
    var i = 0;
    while (i < flags.length) {
      if (!flags[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j < flags.length && flags[j]) {
        j++;
      }
      runs.add(_Run(i, j));
      i = j;
    }
    return runs;
  }
}

class _Run {
  const _Run(this.start, this.end);

  final int start;
  final int end;
}
