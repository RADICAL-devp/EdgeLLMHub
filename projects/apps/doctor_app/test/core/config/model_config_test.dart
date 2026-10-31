import 'package:doctor_app/core/config/model_config.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalog', () {
    test('uses the pinned Qwen3 LiteRT-LM artifact as the default LLM', () {
      expect(ModelCatalog.llm.displayName, 'Clinical language model');
      expect(ModelCatalog.llm.modelType, ModelType.qwen3);
      expect(ModelCatalog.llm.fileType, ModelFileType.litertlm);
      expect(ModelCatalog.llm.url, contains('Qwen3-0.6B'));
      expect(
        ModelCatalog.llm.url,
        contains('a3c5d805ae362dff7f580bc25f2dfb9a5a7eaa76'),
      );
      expect(ModelCatalog.llm.url, endsWith('.litertlm'));
    });

    test('uses the pinned Whisper base int8 speech model', () {
      expect(ModelCatalog.stt.modelType, SttModelType.whisper);
      expect(ModelCatalog.stt.modelUrl, contains('whisper_base_30s_i8.tflite'));
      expect(ModelCatalog.stt.tokenizerUrl, endsWith('tokenizer.json'));
      expect(ModelCatalog.stt.languages, containsAll(['en', 'hi']));
    });

    test('builds a human-readable combined model size', () {
      expect(ModelCatalog.totalBytes, greaterThan(0));
      expect(ModelCatalog.totalSizeLabel, isNotEmpty);
      expect(ModelCatalog.formatBytes(0), '0 MB');
      expect(ModelCatalog.formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });
  });
}
