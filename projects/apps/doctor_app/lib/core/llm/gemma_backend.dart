import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'package:doctor_app/core/config/environment.dart';
import 'package:doctor_app/core/observability.dart';

/// Result of one flutter_gemma generation: final answer text plus any
/// thinking trace the model produced (Qwen3 thinking mode).
class GemmaGeneration {
  const GemmaGeneration({required this.text, this.thinking = ''});

  final String text;
  final String thinking;
}

/// Thin seam over the flutter_gemma statics so the adapter and the
/// ModelManagerCubit stay unit-testable without loading native libraries.
abstract class GemmaBackend {
  Future<void> initialize();

  Future<bool> isModelInstalled(String fileName);

  Future<void> installFromNetwork(
    String url, {
    required void Function(int progressPercent) onProgress,
  });

  Future<void> installFromFile(String path);

  Future<GemmaGeneration> generate({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  });

  Stream<String> generateStream({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  });

  Future<void> close();
}

/// Production [GemmaBackend] backed by flutter_gemma + LiteRT-LM.
///
/// Model identity (URL / file name) comes from [EnvironmentConfig]; engine
/// registration happens once in `main()` via `FlutterGemma.initialize`.
class FlutterGemmaBackend implements GemmaBackend {
  FlutterGemmaBackend({JsonLogger? logger})
      : _log = logger ?? JsonLogger(name: 'llm.gemma_backend');

  final JsonLogger _log;

  static const int maxTokens = 2048;

  Future<void> _ensureInitialized() async {
    // initialize() is idempotent in flutter_gemma; registering the engine
    // twice is a no-op via the registry dedup.
    await FlutterGemma.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
    );
  }

  @override
  Future<void> initialize() => _ensureInitialized();

  @override
  Future<bool> isModelInstalled(String fileName) async {
    await _ensureInitialized();
    return FlutterGemma.isModelInstalled(fileName);
  }

  @override
  Future<void> installFromNetwork(
    String url, {
    required void Function(int progressPercent) onProgress,
  }) async {
    await _ensureInitialized();
    await FlutterGemma.installModel(
      modelType: ModelType.qwen3,
      // Must be explicit: the default routes to MediaPipe, which cannot
      // read .litertlm files.
      fileType: ModelFileType.litertlm,
    ).fromNetwork(url).withProgress(onProgress).install();
  }

  @override
  Future<void> installFromFile(String path) async {
    await _ensureInitialized();
    await FlutterGemma.installModel(
      modelType: ModelType.qwen3,
      fileType: ModelFileType.litertlm,
    ).fromFile(path).install();
  }

  Future<InferenceModel> _activeModel() {
    return FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  @override
  Future<GemmaGeneration> generate({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async {
    final model = await _activeModel();
    try {
      final chat = await model.createChat(
        temperature: 0.2,
        systemInstruction: systemInstruction,
        maxOutputTokens: maxOutputTokens,
        isThinking: enableThinking,
        modelType: ModelType.qwen3,
      );
      try {
        await chat.addQueryChunk(
          Message.text(text: prompt, isUser: true),
        );
        final response = await chat.generateChatResponse();
        return _splitResponse(response, onThinking);
      } finally {
        await chat.close();
      }
    } finally {
      await model.close();
    }
  }

  @override
  Stream<String> generateStream({
    String? systemInstruction,
    required String prompt,
    int? maxOutputTokens,
    bool enableThinking = false,
    void Function(String thinkingChunk)? onThinking,
  }) async* {
    final model = await _activeModel();
    try {
      final chat = await model.createChat(
        temperature: 0.2,
        systemInstruction: systemInstruction,
        maxOutputTokens: maxOutputTokens,
        isThinking: enableThinking,
        modelType: ModelType.qwen3,
      );
      try {
        await chat.addQueryChunk(
          Message.text(text: prompt, isUser: true),
        );
        final buffer = StringBuffer();
        await for (final event in chat.generateChatResponseAsync()) {
          if (event is ThinkingResponse) {
            onThinking?.call(event.content);
            _log.info('thinking_chunk',
                context: {'chars': event.content.length});
          } else if (event is TextResponse) {
            buffer.write(event.token);
            yield buffer.toString();
          }
        }
      } finally {
        await chat.close();
      }
    } finally {
      await model.close();
    }
  }

  @override
  Future<void> close() async {}

  GemmaGeneration _splitResponse(
    ModelResponse response,
    void Function(String thinkingChunk)? onThinking,
  ) {
    if (response is ThinkingResponse) {
      onThinking?.call(response.content);
      _log.info('thinking_block',
          context: {'chars': response.content.length});
      return GemmaGeneration(text: '', thinking: response.content);
    }
    if (response is TextResponse) {
      return GemmaGeneration(text: response.token);
    }
    // FunctionCallResponse and future variants carry no plain text for our
    // clinical flows — surface honestly instead of fabricating content.
    _log.warn('unexpected_response_type',
        context: {'type': response.runtimeType.toString()});
    return const GemmaGeneration(text: '');
  }
}
