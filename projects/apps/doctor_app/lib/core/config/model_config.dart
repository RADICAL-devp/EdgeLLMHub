import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// The single place to change the default on-device models.
///
/// App code refers to [ModelCatalog.llm] and [ModelCatalog.stt] instead of
/// hardcoding model names anywhere else. To swap models later, update the
/// descriptor(s) below and leave the rest of the app untouched.
///
/// Both artifacts are public (no Hugging Face token) and pinned to a revision
/// so a first launch always downloads the exact file that was tested.
class ModelCatalog {
  ModelCatalog._();

  static const LlmModelDescriptor llm = LlmModelDescriptor(
    // Generic app-facing identity; the upstream artifact keeps its own name.
    displayName: 'Clinical language model',
    description:
        'Runs entirely on the device and turns a transcript into a structured '
        'clinical note. About 345 MB.',
    url:
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/'
        'a3c5d805ae362dff7f580bc25f2dfb9a5a7eaa76/'
        'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    modelType: ModelType.qwen3,
    fileType: ModelFileType.litertlm,
    approximateBytes: 345 * 1024 * 1024,
  );

  static const SttModelDescriptor stt = SttModelDescriptor(
    displayName: 'Clinical speech model',
    description:
        'Whisper base (int8) transcribes English and Hindi on the device. '
        'About 77 MB plus a small tokenizer.',
    modelUrl:
        'https://huggingface.co/litert-community/whisper-base/resolve/'
        'ba2c613646edc2b72f5a51fa0b5b0b322e436101/'
        'whisper_base_30s_i8.tflite',
    tokenizerUrl:
        'https://huggingface.co/openai/whisper-base/resolve/main/tokenizer.json',
    modelType: SttModelType.whisper,
    approximateModelBytes: 77 * 1024 * 1024,
    approximateTokenizerBytes: 2400 * 1024,
    languages: ['en', 'hi'],
  );

  static int get totalBytes =>
      llm.approximateBytes +
      stt.approximateModelBytes +
      stt.approximateTokenizerBytes;

  static String get totalSizeLabel => formatBytes(totalBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.round()} MB';
  }
}

class LlmModelDescriptor {
  const LlmModelDescriptor({
    required this.displayName,
    required this.description,
    required this.url,
    required this.modelType,
    required this.fileType,
    required this.approximateBytes,
  });

  final String displayName;
  final String description;
  final String url;
  final ModelType modelType;
  final ModelFileType fileType;
  final int approximateBytes;

  String get sizeLabel => ModelCatalog.formatBytes(approximateBytes);
}

class SttModelDescriptor {
  const SttModelDescriptor({
    required this.displayName,
    required this.description,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.modelType,
    required this.approximateModelBytes,
    required this.approximateTokenizerBytes,
    required this.languages,
  });

  final String displayName;
  final String description;
  final String modelUrl;
  final String tokenizerUrl;
  final SttModelType modelType;
  final int approximateModelBytes;
  final int approximateTokenizerBytes;
  final List<String> languages;

  int get approximateBytes => approximateModelBytes + approximateTokenizerBytes;

  String get sizeLabel => ModelCatalog.formatBytes(approximateBytes);
}
