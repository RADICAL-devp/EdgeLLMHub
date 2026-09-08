import 'dart:async';

import '../../domain/services/note_assist_service.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/llm/prompts/clinical_prompts.dart';

class OnDeviceLlmService implements NoteAssistService {
  final LlmPort _llmPort;

  OnDeviceLlmService(this._llmPort);

  @override
  Stream<String> cleanUpText(String rawText) async* {
    final prompt = '${ClinicalPrompts.cleanTranscript}\n${ClinicalPrompts.sanitize(rawText)}';
    final result = await _llmPort.processText(prompt, ProcessingMode.cleanTranscript);
    yield result;
  }

  @override
  Stream<String> structureNote(String cleanedText) async* {
    final prompt = '${ClinicalPrompts.structuredSummary}\n${ClinicalPrompts.sanitize(cleanedText)}';
    final result = await _llmPort.processText(prompt, ProcessingMode.summarize);
    yield result;
  }

  @override
  Future<String> extractFields(String structuredText) async {
    final prompt = '${ClinicalPrompts.structuredSummary}\n${ClinicalPrompts.sanitize(structuredText)}';
    return await _llmPort.processText(prompt, ProcessingMode.summarize);
  }

  @override
  Future<String> generateRecap(String structuredText) async {
    final prompt = '${ClinicalPrompts.doctorNote}\n${ClinicalPrompts.sanitize(structuredText)}';
    return await _llmPort.processText(prompt, ProcessingMode.generateDoctorNote);
  }
}
