import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_cleanup_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:clinical_intelligence_dart/core/models/processing_mode.dart';
import 'package:clinical_intelligence_dart/core/models/structured_summary.dart';
import 'package:test/test.dart';

/// Stub LLM that returns the input unchanged (for testing cleanup service).
class _PassthroughLlm implements LlmPort {
  @override
  Future<String> processText(String input, ProcessingMode mode) async => input;

  @override
  Future<StructuredSummary> generateStructuredSummary(String t) async =>
      StructuredSummary();

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String t,
    String c,
  ) async =>
      StructuredSummary();

  @override
  Future<String> generateExecutiveSummary(String t) async => '';

  @override
  Future<String> generateDoctorNote(String t) async => '';
}

void main() {
  late TranscriptCleanupService service;

  setUp(() {
    service = TranscriptCleanupService(
      llmPort: _PassthroughLlm(),
      normalizationService: TranscriptNormalizationService(),
    );
  });

  group('TranscriptCleanupService', () {
    test('preserves meaning — output contains all key terms', () async {
      const input =
          'Patient has   severe  headache  and   nausea  for  3  days';
      final result = await service.process(input);

      expect(result.processedText, contains('headache'));
      expect(result.processedText, contains('nausea'));
      expect(result.processedText, contains('3'));
      expect(result.processedText, contains('days'));
    });

    test('preserves speaker labels', () async {
      const input =
          'Doctor: How are you today?\nPatient: I have a headache.';
      final result = await service.process(input);

      expect(result.processedText, contains('Doctor:'));
      expect(result.processedText, contains('Patient:'));
      expect(result.hasSpeakerLabels, isTrue);
      expect(result.detectedSpeakers, containsAll(['Doctor', 'Patient']));
    });

    test('does not summarize — output length comparable to input', () async {
      const input = '''Doctor: Good morning. How can I help you today?
Patient: I've been having this terrible headache for the past three days.
It's mostly on the right side and gets worse in the morning.
Doctor: Have you taken anything for it?
Patient: Just some over the counter painkillers but they don't help much.
Doctor: Any nausea or vision changes?
Patient: Some nausea yes but no vision problems.''';

      final result = await service.process(input);

      // Should not significantly reduce length (i.e., not summarizing)
      final inputWords = input.split(RegExp(r'\s+')).length;
      final outputWords = result.processedText.split(RegExp(r'\s+')).length;

      // Output should retain at least 80% of words (not summarized)
      expect(outputWords, greaterThan(inputWords * 0.8));
    });

    test('handles empty input', () async {
      final result = await service.process('');
      expect(result.processedText, isEmpty);
      expect(result.warnings, isNotEmpty);
    });
  });
}
