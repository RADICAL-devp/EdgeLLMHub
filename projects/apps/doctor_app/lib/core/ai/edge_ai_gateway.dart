import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../config/app_config.dart';
import '../config/model_config.dart';

/// The narrow edge-AI surface used by [EdgeAiService].
///
/// The real implementation talks to flutter_edge_ai; tests can provide a fake
/// that returns predetermined model text without loading a native runtime.
abstract interface class EdgeAiGateway {
  bool get hasModel;

  Future<String> generate({
    required String systemInstruction,
    required String prompt,
    required bool enableThinking,
    int? maxOutputTokens,
    void Function(String token)? onToken,
  });
}

class FlutterEdgeAiGateway implements EdgeAiGateway {
  @override
  bool get hasModel => FlutterEdgeAi.hasActiveModel();

  @override
  Future<String> generate({
    required String systemInstruction,
    required String prompt,
    required bool enableThinking,
    int? maxOutputTokens,
    void Function(String token)? onToken,
  }) async {
    final model = await FlutterEdgeAi.getActiveModel(
      maxTokens: AppConfig.llmContextTokens,
    );
    final chat = await model.createChat(
      temperature: 0.2,
      topK: 40,
      topP: 0.9,
      tokenBuffer: 512,
      enableThinking: enableThinking,
      modelType: ModelCatalog.llm.modelType,
      maxOutputTokens: maxOutputTokens ?? AppConfig.llmMaxOutputTokens,
      systemInstruction: systemInstruction,
    );

    final buffer = StringBuffer();
    try {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final response in chat.generateChatResponseAsync()) {
        switch (response) {
          case TextResponse():
            buffer.write(response.token);
            onToken?.call(response.token);
          case ThinkingResponse():
            // Chain-of-thought is intentionally never shown or persisted.
            break;
          case FunctionCallResponse():
          case ParallelFunctionCallResponse():
            break;
        }
      }
    } finally {
      try {
        await chat.close();
      } catch (_) {
        // Session teardown is best effort; the model stays loaded.
      }
    }
    return buffer.toString();
  }
}
