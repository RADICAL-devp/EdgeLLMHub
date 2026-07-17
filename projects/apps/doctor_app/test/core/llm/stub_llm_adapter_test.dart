import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/llm/stub_llm_adapter.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';

void main() {
  late StubLlmAdapter adapter;

  setUp(() {
    adapter = StubLlmAdapter();
  });

  group('StubLlmAdapter', () {
    test('processText returns offline-prefixed response', () async {
      final result = await adapter.processText('test input', ProcessingMode.vocabAssist);
      expect(result, contains('[OFFLINE MODE]'));
      expect(result, contains('test input'));
    });

    test('generateStructuredSummary returns valid StructuredSummary', () async {
      final result = await adapter.generateStructuredSummary('test transcript');
      expect(result, isA<StructuredSummary>());
      expect(result.complaint, contains('[OFFLINE MODE]'));
      expect(result.advice, contains('[OFFLINE MODE]'));
    });

    test('generateContextEnrichedSummary returns valid StructuredSummary', () async {
      final result = await adapter.generateContextEnrichedSummary(
        'test transcript',
        'past context',
      );
      expect(result, isA<StructuredSummary>());
      expect(result.complaint, contains('[OFFLINE MODE]'));
    });

    test('generateExecutiveSummary returns offline message', () async {
      final result = await adapter.generateExecutiveSummary('test');
      expect(result, contains('[OFFLINE MODE]'));
    });

    test('generateDoctorNote returns offline message with preserved transcript', () async {
      final result = await adapter.generateDoctorNote('patient transcript here');
      expect(result, contains('[OFFLINE MODE]'));
      expect(result, contains('patient transcript here'));
    });

    test('all methods complete without throwing', () async {
      // Stub should NEVER throw — it's the last-resort fallback
      await expectLater(
        adapter.processText('x', ProcessingMode.vocabAssist),
        completes,
      );
      await expectLater(
        adapter.generateStructuredSummary('x'),
        completes,
      );
      await expectLater(
        adapter.generateContextEnrichedSummary('x', 'y'),
        completes,
      );
      await expectLater(
        adapter.generateExecutiveSummary('x'),
        completes,
      );
      await expectLater(
        adapter.generateDoctorNote('x'),
        completes,
      );
    });
  });
}
