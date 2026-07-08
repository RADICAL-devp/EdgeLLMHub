import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'prompts/clinical_prompts.dart';

/// Native LLM adapter for true on-device mobile execution.
///
/// Android: Uses Google AI Edge LiteRT-LM (via flutter_gemma) with Gemma 3n.
/// iOS: Uses MethodChannel to native MLC LLM (Llama 3.2).
class NativeLlmAdapter implements LlmPort {
  static const MethodChannel _iosChannel = MethodChannel('com.example.clinical/llm');

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = switch (mode) {
      ProcessingMode.vocabAssist => '${ClinicalPrompts.vocabAssist}\n$input',
      ProcessingMode.cleanTranscript => '${ClinicalPrompts.cleanTranscript}\n$input',
      ProcessingMode.summarize => '${ClinicalPrompts.structuredSummary}\n$input',
      ProcessingMode.generateDoctorNote => '${ClinicalPrompts.doctorNote}\n$input',
      _ => input,
    };

    return _generate(prompt, expectJson: false);
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) async {
    final prompt = '${ClinicalPrompts.structuredSummary}\n$transcriptText';
    final response = await _generate(prompt, expectJson: true);
    return _parseStructuredSummary(response);
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) async {
    final prompt = 'PAST CONTEXT from this doctor\'s consultations:\n'
        '$pastContext\n\n---\n\n'
        '${ClinicalPrompts.structuredSummary}\n$transcriptText';
    final response = await _generate(prompt, expectJson: true);
    return _parseStructuredSummary(response);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    final prompt = '${ClinicalPrompts.executiveSummary}\n$transcriptText';
    return _generate(prompt, expectJson: true);
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    final prompt = '${ClinicalPrompts.doctorNote}\n$transcriptText';
    return _generate(prompt, expectJson: false);
  }

  /// Platform-aware generation.
  Future<String> _generate(String prompt, {bool expectJson = false}) async {
    try {
      if (Platform.isAndroid) {
        // Use flutter_gemma for LiteRT-LM inference on Android
        final response = await FlutterGemmaPlugin.instance.getResponse(prompt);
        return response ?? '';
      } else if (Platform.isIOS) {
        // Use MethodChannel for MLC LLM on iOS
        final response = await _iosChannel.invokeMethod<String>('generate', {
          'prompt': prompt,
          'expectJson': expectJson,
        });
        return response ?? '';
      }
      return 'Unsupported platform for Native LLM';
    } catch (e) {
      print('Native LLM Error: $e');
      throw Exception('Failed to generate text natively: $e');
    }
  }

  /// Parse LLM response as StructuredSummary JSON.
  StructuredSummary _parseStructuredSummary(String response) {
    var cleaned = response.trim();

    // Aggressively strip markdown code fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }

    // Try to find a JSON block if the model babbled before the JSON
    final startIndex = cleaned.indexOf('{');
    final endIndex = cleaned.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      cleaned = cleaned.substring(startIndex, endIndex + 1);
    }

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return StructuredSummary.fromJson(json);
    } catch (_) {
      // Fallback: if the LLM doesn't return valid JSON
      return StructuredSummary(
        complaint: 'See raw output',
        pastHistory: 'See raw output',
        vitals: 'See raw output',
        physicalExamination: 'See raw output',
        investigationOrdered: 'See raw output',
        diagnosis: 'See raw output',
        advice: response.trim(), // Put original response here
      );
    }
  }
}
