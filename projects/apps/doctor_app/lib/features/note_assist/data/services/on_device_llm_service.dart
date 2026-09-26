import 'dart:async';

import '../../domain/services/note_assist_service.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';
import 'package:doctor_app/core/observability.dart';

class OnDeviceLlmService implements NoteAssistService {
  final LlmPort _llmPort;
  final JsonLogger _log;

  OnDeviceLlmService(this._llmPort, {JsonLogger? logger})
      : _log = logger ?? JsonLogger(name: 'service.on_device_llm');

  @override
  Stream<String> cleanUpText(String rawText) async* {
    _log.info('call_started', context: {
      'operation': 'cleanUpText',
      'inputChars': rawText.length,
      'mode': ProcessingMode.cleanTranscript.name,
    });
    final result =
        await _llmPort.processText(rawText, ProcessingMode.cleanTranscript);
    yield result;
  }

  @override
  Stream<String> structureNote(String cleanedText) async* {
    _log.info('call_started', context: {
      'operation': 'structureNote',
      'inputChars': cleanedText.length,
      'mode': ProcessingMode.summarize.name,
    });
    final result = await _llmPort.processText(cleanedText, ProcessingMode.summarize);
    yield result;
  }

  @override
  Future<String> extractFields(String structuredText) async {
    _log.info('call_started', context: {
      'operation': 'extractFields',
      'inputChars': structuredText.length,
      'mode': ProcessingMode.summarize.name,
    });
    return _llmPort.processText(structuredText, ProcessingMode.summarize);
  }

  @override
  Future<String> generateRecap(String structuredText) async {
    _log.info('call_started', context: {
      'operation': 'generateRecap',
      'inputChars': structuredText.length,
      'mode': ProcessingMode.generateDoctorNote.name,
    });
    return _llmPort.processText(structuredText, ProcessingMode.generateDoctorNote);
  }
}
