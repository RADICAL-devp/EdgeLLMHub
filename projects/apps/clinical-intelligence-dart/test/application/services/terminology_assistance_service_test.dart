import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/application/services/terminology_assistance_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:clinical_intelligence_dart/core/models/processing_mode.dart';
import 'package:clinical_intelligence_dart/core/models/structured_summary.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/stub_llm_adapter.dart';
import 'package:test/test.dart';

void main() {
  late TerminologyAssistanceService service;

  setUp(() {
    service = TerminologyAssistanceService(
      llmPort: StubLlmAdapter(),
      normalizationService: TranscriptNormalizationService(),
    );
  });

  group('TerminologyAssistanceService', () {
    test('does not summarize — output retains key clinical details', () async {
      const input = 'Patient presents with severe headache for three days. '
          'Blood pressure is 140 over 90. Heart rate is 88 beats per minute. '
          'No known drug allergies. Taking aspirin as needed.';

      final result = await service.process(input);

      // All medical facts should be preserved
      expect(result.processedText, contains('headache'));
      expect(result.processedText, contains('three days'));
      expect(result.processedText, contains('140'));
      expect(result.processedText, contains('90'));
      expect(result.processedText, contains('88'));
      expect(result.processedText, contains('aspirin'));
    });

    test('standardizes common medical abbreviations', () async {
      const input = 'Blood pressure is 120 over 80. '
          'Heart rate is 72 beats per minute.';

      final result = await service.process(input);

      // Stub adapter should standardize known abbreviations
      expect(result.processedText, contains('BP'));
      expect(result.processedText, contains('HR'));
      expect(result.processedText, contains('bpm'));
    });

    test('fixes dictation punctuation', () async {
      const input = 'patient presents with headache';
      final result = await service.process(input);

      // Should capitalize and add period
      expect(result.processedText[0], equals('P'));
      expect(result.processedText, endsWith('.'));
    });

    test('does not invent new medical facts', () async {
      const input = 'Patient has a headache.';
      final result = await service.process(input);

      // Should NOT add diagnoses, medications, or new symptoms
      expect(
        result.processedText.toLowerCase(),
        isNot(contains('migraine')),
      );
      expect(
        result.processedText.toLowerCase(),
        isNot(contains('ibuprofen')),
      );
    });

    test('handles empty input gracefully', () async {
      final result = await service.process('');
      expect(result.processedText, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('warns on very short input', () async {
      final result = await service.process('Headache.');
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first,
        contains('very short'),
      );
    });
  });
}
