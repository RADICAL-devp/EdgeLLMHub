import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:doctor_app/core/llm/hybrid_llm_adapter.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

class MockLlmPort extends Mock implements LlmPort {}

void main() {
  setUpAll(() {
    registerFallbackValue(ProcessingMode.vocabAssist);
  });

  late MockLlmPort mockNative;
  late MockLlmPort mockStub;

  setUp(() {
    mockNative = MockLlmPort();
    mockStub = MockLlmPort();

    // Default stub responses
    when(() => mockStub.processText(any(), any()))
        .thenAnswer((_) async => '[STUB] result');
    when(() => mockStub.generateStructuredSummary(any()))
        .thenAnswer((_) async => StructuredSummary(
              complaint: 'stub',
              pastHistory: 'stub',
              vitals: 'stub',
              physicalExamination: 'stub',
              investigationOrdered: 'stub',
              diagnosis: 'stub',
              advice: 'stub',
            ));
    when(() => mockStub.generateExecutiveSummary(any()))
        .thenAnswer((_) async => '[STUB] summary');
    when(() => mockStub.generateDoctorNote(any()))
        .thenAnswer((_) async => '[STUB] note');
    when(() => mockStub.generateContextEnrichedSummary(any(), any()))
        .thenAnswer((_) async => StructuredSummary(
              complaint: 'stub',
              pastHistory: 'stub',
              vitals: 'stub',
              physicalExamination: 'stub',
              investigationOrdered: 'stub',
              diagnosis: 'stub',
              advice: 'stub',
            ));
  });

  HybridLlmAdapter createAdapter() {
    return HybridLlmAdapter(
      nativeAdapter: mockNative,
      stubAdapter: mockStub,
    );
  }

  group('Tier 1: Native adapter', () {
    test('uses native when available', () async {
      when(() => mockNative.processText(any(), any()))
          .thenAnswer((_) async => 'native result');

      final adapter = createAdapter();
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, 'native result');
      verify(() => mockNative.processText('test', ProcessingMode.vocabAssist)).called(1);
      verifyNever(() => mockStub.processText(any(), any()));
    });

    test('uses native for generateStructuredSummary when available', () async {
      when(() => mockNative.generateStructuredSummary(any()))
          .thenAnswer((_) async => StructuredSummary(
                complaint: 'native',
                pastHistory: 'native',
                vitals: 'native',
                physicalExamination: 'native',
                investigationOrdered: 'native',
                diagnosis: 'native',
                advice: 'native',
              ));

      final adapter = createAdapter();
      final result = await adapter.generateStructuredSummary('text');

      expect(result.complaint, 'native');
      verifyNever(() => mockStub.generateStructuredSummary(any()));
    });
  });

  group('Tier 2: Stub fallback', () {
    test('falls back to stub when native throws LlmInitializationException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmInitializationException('not initialized'));

      final adapter = createAdapter();
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, '[STUB] result');
    });

    test('falls back to stub when native throws LlmException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmException('native died'));

      final adapter = createAdapter();
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, '[STUB] result');
    });

    test('falls back to stub when native throws UnsupportedPlatformException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const UnsupportedPlatformException('not supported'));

      final adapter = createAdapter();
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, '[STUB] result');
    });

    test('falls back to stub when native throws unexpected error', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(Exception('unexpected'));

      final adapter = createAdapter();
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, '[STUB] result');
    });
  });

  group('Availability tracking', () {
    test('marks native unavailable after UnsupportedPlatformException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const UnsupportedPlatformException('not supported'));

      final adapter = createAdapter();

      // First call — tries native, fails, uses stub
      await adapter.processText('test1', ProcessingMode.vocabAssist);
      verify(() => mockNative.processText(any(), any())).called(1);

      // Second call — skips native entirely
      await adapter.processText('test2', ProcessingMode.vocabAssist);
      verifyNever(() => mockNative.processText('test2', ProcessingMode.vocabAssist));
    });

    test('marks native unavailable after LlmInitializationException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmInitializationException('not initialized'));

      final adapter = createAdapter();

      await adapter.processText('test1', ProcessingMode.vocabAssist);
      verify(() => mockNative.processText(any(), any())).called(1);

      await adapter.processText('test2', ProcessingMode.vocabAssist);
      verifyNever(() => mockNative.processText('test2', ProcessingMode.vocabAssist));
    });

    test('resetAvailability restores native tier', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const UnsupportedPlatformException('not supported'));

      final adapter = createAdapter();
      await adapter.processText('test1', ProcessingMode.vocabAssist);

      // Reset and re-register native
      adapter.resetAvailability();
      when(() => mockNative.processText(any(), any()))
          .thenAnswer((_) async => 'native recovered');

      final result = await adapter.processText('test2', ProcessingMode.vocabAssist);
      expect(result, 'native recovered');
    });

    test('does not disable native for transient LlmException', () async {
      // First call fails with LlmException
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmException('transient failure'));

      final adapter = createAdapter();
      await adapter.processText('test1', ProcessingMode.vocabAssist);

      // Second call should still try native (LlmException doesn't permanently disable)
      when(() => mockNative.processText(any(), any()))
          .thenAnswer((_) async => 'native recovered');
      final result = await adapter.processText('test2', ProcessingMode.vocabAssist);
      expect(result, 'native recovered');
    });
  });

  group('All LlmPort methods use fallback chain', () {
    test('generateStructuredSummary uses fallback chain', () async {
      when(() => mockNative.generateStructuredSummary(any()))
          .thenThrow(const LlmException('fail'));

      final adapter = createAdapter();
      final result = await adapter.generateStructuredSummary('text');

      expect(result.complaint, 'stub');
    });

    test('generateExecutiveSummary uses fallback chain', () async {
      when(() => mockNative.generateExecutiveSummary(any()))
          .thenAnswer((_) async => 'native summary');

      final adapter = createAdapter();
      final result = await adapter.generateExecutiveSummary('text');

      expect(result, 'native summary');
    });

    test('generateDoctorNote uses fallback chain', () async {
      when(() => mockNative.generateDoctorNote(any()))
          .thenThrow(const LlmInitializationException('fail'));

      final adapter = createAdapter();
      final result = await adapter.generateDoctorNote('text');

      expect(result, '[STUB] note');
    });

    test('generateContextEnrichedSummary uses native when available', () async {
      when(() => mockNative.generateContextEnrichedSummary(any(), any()))
          .thenAnswer((_) async => StructuredSummary(
                complaint: 'native',
                pastHistory: 'native',
                vitals: 'native',
                physicalExamination: 'native',
                investigationOrdered: 'native',
                diagnosis: 'native',
                advice: 'native',
              ));

      final adapter = createAdapter();
      final result =
          await adapter.generateContextEnrichedSummary('text', 'context');

      expect(result.complaint, 'native');
      verifyNever(() => mockStub.generateContextEnrichedSummary(any(), any()));
    });

    test('generateContextEnrichedSummary falls back to stub when native fails', () async {
      when(() => mockNative.generateContextEnrichedSummary(any(), any()))
          .thenThrow(const LlmInitializationException('fail'));

      final adapter = createAdapter();
      final result =
          await adapter.generateContextEnrichedSummary('text', 'context');

      expect(result.complaint, 'stub');
    });

    test('generateStructuredSummary falls back to stub when native fails', () async {
      when(() => mockNative.generateStructuredSummary(any()))
          .thenThrow(const LlmInitializationException('fail'));

      final adapter = createAdapter();
      final result = await adapter.generateStructuredSummary('text');

      expect(result.complaint, 'stub');
    });

    test('generateExecutiveSummary falls back to stub when native fails', () async {
      when(() => mockNative.generateExecutiveSummary(any()))
          .thenThrow(const LlmException('native died'));

      final adapter = createAdapter();
      final result = await adapter.generateExecutiveSummary('text');

      expect(result, '[STUB] summary');
    });
  });
}