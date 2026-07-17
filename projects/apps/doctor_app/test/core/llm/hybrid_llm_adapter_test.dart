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
  late MockLlmPort mockCloud;
  late MockLlmPort mockStub;

  setUp(() {
    mockNative = MockLlmPort();
    mockCloud = MockLlmPort();
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

  HybridLlmAdapter createAdapter({bool cloudEnabled = false}) {
    return HybridLlmAdapter(
      nativeAdapter: mockNative,
      cloudAdapter: mockCloud,
      stubAdapter: mockStub,
      cloudEnabled: cloudEnabled,
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
      verifyNever(() => mockCloud.processText(any(), any()));
      verifyNever(() => mockStub.processText(any(), any()));
    });
  });

  group('Tier 2: Cloud fallback', () {
    test('falls back to cloud when native throws LlmInitializationException', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmInitializationException('not initialized'));
      when(() => mockCloud.processText(any(), any()))
          .thenAnswer((_) async => 'cloud result');

      final adapter = createAdapter(cloudEnabled: true);
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, 'cloud result');
    });

    test('skips cloud when cloudEnabled is false', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmInitializationException('not initialized'));

      final adapter = createAdapter(cloudEnabled: false);
      final result = await adapter.processText('test', ProcessingMode.vocabAssist);

      expect(result, '[STUB] result');
      verifyNever(() => mockCloud.processText(any(), any()));
    });
  });

  group('Tier 3: Stub fallback', () {
    test('falls back to stub when both native and cloud fail', () async {
      when(() => mockNative.processText(any(), any()))
          .thenThrow(const LlmException('native died'));
      when(() => mockCloud.processText(any(), any()))
          .thenThrow(const NetworkException('cloud died', isTransient: false));

      final adapter = createAdapter(cloudEnabled: true);
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
  });

  group('All LlmPort methods', () {
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
  });
}
