import 'dart:async';

import 'package:doctor_app/core/llm/flutter_gemma_llm_adapter.dart';
import 'package:doctor_app/core/llm/gemma_backend.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGemmaBackend implements GemmaBackend {
  _FakeGemmaBackend({
    this.text = '{"complaint": "cough"}',
    this.thinking = '',
    this.error,
    this.streamTokens = const [],
  });

  String text;
  String thinking;
  Object? error;
  List<String> streamTokens;

  final List<String> thinkingSeen = [];
  int generateCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isModelInstalled(String fileName) async => true;

  @override
  Future<void> installFromNetwork(
    String url, {
    required void Function(int progressPercent) onProgress,
  }) async {}

  @override
  Future<void> installFromFile(String path) async {}

  @override
  Future<GemmaGeneration> generate({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async {
    generateCalls++;
    if (error != null) throw error!;
    if (thinking.isNotEmpty) {
      thinkingSeen.add(thinking);
      onThinking?.call(thinking);
    }
    return GemmaGeneration(text: text, thinking: thinking);
  }

  @override
  Stream<String> generateStream({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async* {
    if (error != null) throw error!;
    if (thinking.isNotEmpty) {
      thinkingSeen.add(thinking);
      onThinking?.call(thinking);
    }
    for (final token in streamTokens) {
      yield token;
    }
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('FlutterGemmaLlmAdapter', () {
    test('processText returns validated response', () async {
      final backend = _FakeGemmaBackend(text: 'cleaned transcript');
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      final result = await adapter.processText(
        'raw input',
        ProcessingMode.cleanTranscript,
      );

      expect(result, isNotEmpty);
      expect(backend.generateCalls, 1);
    });

    test('generateField parses the requested field', () async {
      final backend = _FakeGemmaBackend(
        text: '{"complaint": "persistent cough"}',
      );
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      final result = await adapter.generateField('complaint', 'transcript');

      expect(result, 'persistent cough');
    });

    test('generateField rejects unknown fields', () async {
      final adapter =
          FlutterGemmaLlmAdapter(backend: _FakeGemmaBackend());

      expect(
        () => adapter.generateField('nope', 'transcript'),
        throwsArgumentError,
      );
    });

    test('empty model output surfaces LlmException with gemma provider',
        () async {
      final backend = _FakeGemmaBackend(text: '');
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      try {
        await adapter.generateField('complaint', 'transcript');
        fail('expected LlmException');
      } on LlmException catch (e) {
        expect(e.provider, LlmProvider.gemma);
      }
    });

    test('backend errors surface as LlmException with gemma provider',
        () async {
      final backend = _FakeGemmaBackend(error: Exception('engine gone'));
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      try {
        await adapter.generateExecutiveSummary('transcript');
        fail('expected LlmException');
      } on LlmException catch (e) {
        expect(e.provider, LlmProvider.gemma);
      }
    });

    test('thinking traces are recorded and forwarded, parsers see final text',
        () async {
      final backend = _FakeGemmaBackend(
        text: '{"diagnosis": "viral URI"}',
        thinking: 'considering symptoms...',
      );
      final adapter = FlutterGemmaLlmAdapter(backend: backend);
      final sunk = <String>[];
      adapter.onThinkingSink = sunk.add;

      final result = await adapter.generateField('diagnosis', 'transcript');

      expect(result, 'viral URI');
      expect(backend.thinkingSeen, ['considering symptoms...']);
      expect(sunk, ['considering symptoms...']);
    });

    test('generateFieldStream emits parsed partial values', () async {
      final backend = _FakeGemmaBackend(
        streamTokens: ['{"complaint":', ' "cough"}'],
      );
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      final values = await adapter
          .generateFieldStream('complaint', 'transcript')
          .toList();

      expect(values, isNotEmpty);
      expect(values.last, contains('cough'));
    });

    test('generateFieldStream surfaces backend errors', () async {
      final backend = _FakeGemmaBackend(error: Exception('stream died'));
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      expect(
        adapter.generateFieldStream('complaint', 'transcript').toList(),
        throwsA(isA<LlmException>()),
      );
    });

    test('generateFields returns one value per field', () async {
      final backend = _FakeGemmaBackend(text: 'shared answer');
      final adapter = FlutterGemmaLlmAdapter(backend: backend);

      final result = await adapter.generateFields(
        ['complaint', 'diagnosis'],
        'transcript',
      );

      expect(result.keys, {'complaint', 'diagnosis'});
      expect(backend.generateCalls, 2);
    });
  });
}
