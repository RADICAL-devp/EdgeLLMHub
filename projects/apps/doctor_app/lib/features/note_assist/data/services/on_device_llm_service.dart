import 'dart:async';

import '../../domain/services/note_assist_service.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';

class OnDeviceLlmService implements NoteAssistService {
  final LlmPort _llmPort;

  OnDeviceLlmService(this._llmPort);

  @override
  Stream<String> cleanUpText(String rawText) async* {
    final result = await _llmPort.processText(rawText, ProcessingMode.cleanTranscript);
    yield result;
  }

  @override
  Stream<String> structureNote(String cleanedText) async* {
    final result = await _llmPort.processText(cleanedText, ProcessingMode.summarize);
    yield result;
  }

  @override
  Future<String> extractFields(String structuredText) async {
    return await _llmPort.processText(
      "Extract fields from this text:\n$structuredText", 
      ProcessingMode.vocabAssist
    );
  }

  @override
  Future<String> generateRecap(String structuredText) async {
    return await _llmPort.processText(
      "Provide a friendly recap:\n$structuredText", 
      ProcessingMode.summarize
    );
  }
}
