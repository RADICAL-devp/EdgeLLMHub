import 'package:shared_models/shared_models.dart';

import '../config/app_config.dart';
import '../exceptions/app_exceptions.dart';
import 'ai_service.dart';
import 'clinical_prompt_builder.dart';
import 'clinical_response_parser.dart';
import 'edge_ai_gateway.dart';

/// Production AI service backed by flutter_edge_ai.
///
/// Short transcripts go through one structuring pass. Long transcripts are
/// first condensed in chunks and then synthesized, so a 30-minute consultation
/// does not silently lose its middle to the context window.
class EdgeAiService implements AIService {
  EdgeAiService({
    EdgeAiGateway? gateway,
    ClinicalPromptBuilder? prompts,
    ClinicalResponseParser? parser,
    int directTranscriptLimit = 16000,
  }) : _gateway = gateway ?? FlutterEdgeAiGateway(),
       _prompts = prompts ?? const ClinicalPromptBuilder(),
       _parser = parser ?? const ClinicalResponseParser(),
       _directTranscriptLimit = directTranscriptLimit;

  final EdgeAiGateway _gateway;
  final ClinicalPromptBuilder _prompts;
  final ClinicalResponseParser _parser;
  final int _directTranscriptLimit;

  @override
  bool get isReady => _gateway.hasModel;

  @override
  Future<StructuredNoteSections> structureNote({
    required String transcript,
    required String languageCode,
    bool enableThinking = false,
    String patientName = '',
    void Function(String token)? onToken,
  }) async {
    if (!isReady) throw const ModelNotReadyException();
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      throw const ValidationException(
        'There is no transcript to structure yet.',
      );
    }

    try {
      if (cleanTranscript.length <= _directTranscriptLimit) {
        final raw = await _gateway.generate(
          systemInstruction: ClinicalPromptBuilder.systemInstruction,
          prompt: _prompts.structurePrompt(
            transcript: cleanTranscript,
            languageCode: languageCode,
            patientName: patientName,
          ),
          enableThinking: enableThinking,
          maxOutputTokens: AppConfig.llmMaxOutputTokens,
          onToken: onToken,
        );
        return _parser.parseStructuredSections(raw);
      }

      final chunks = _prompts.chunkTranscript(cleanTranscript);
      final extractionNotes = <String>[];
      for (final chunk in chunks) {
        final raw = await _gateway.generate(
          systemInstruction: ClinicalPromptBuilder.systemInstruction,
          prompt: _prompts.extractionPrompt(
            transcriptChunk: chunk,
            languageCode: languageCode,
          ),
          enableThinking: false,
          maxOutputTokens: 700,
        );
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) extractionNotes.add(trimmed);
      }
      if (extractionNotes.isEmpty) {
        throw const LlmException(
          'The on-device model could not read this recording. Try again.',
        );
      }

      final raw = await _gateway.generate(
        systemInstruction: ClinicalPromptBuilder.systemInstruction,
        prompt: _prompts.synthesisPrompt(
          extractionNotes: extractionNotes.join('\n\n---\n\n'),
          languageCode: languageCode,
          patientName: patientName,
        ),
        enableThinking: enableThinking,
        maxOutputTokens: AppConfig.llmMaxOutputTokens,
        onToken: onToken,
      );
      return _parser.parseStructuredSections(raw);
    } on AppException {
      rethrow;
    } catch (error) {
      throw LlmException(
        'The on-device model could not create the note. Try again.',
        cause: error,
      );
    }
  }

  @override
  Future<String> cleanTranscript({
    required String transcript,
    required String languageCode,
    bool enableThinking = false,
    void Function(String token)? onToken,
  }) async {
    if (!isReady) throw const ModelNotReadyException();
    final text = transcript.trim();
    if (text.isEmpty) {
      throw const ValidationException('There is no transcript to clean.');
    }
    if (text.length > 16000) {
      throw const LlmException(
        'This transcript is too long for a single clean-up pass. You can edit '
        'it directly, or use Structure note on the full transcript.',
      );
    }

    try {
      final raw = await _gateway.generate(
        systemInstruction: ClinicalPromptBuilder.systemInstruction,
        prompt: _prompts.cleanTranscriptPrompt(
          transcript: text,
          languageCode: languageCode,
        ),
        enableThinking: enableThinking,
        maxOutputTokens: 2000,
        onToken: onToken,
      );
      return _parser.parseCleanedTranscript(raw);
    } on AppException {
      rethrow;
    } catch (error) {
      throw LlmException(
        'The on-device model could not clean this transcript. The original '
        'text was kept.',
        cause: error,
      );
    }
  }
}
