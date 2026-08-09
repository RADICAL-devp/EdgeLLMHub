import 'dart:convert';

import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'prompts/clinical_prompts.dart';

/// Shared JSON-parsing logic for native LLM adapters.
///
/// Both Android (MLC) and iOS (MLC) adapters parse the same structured
/// JSON from their respective models, so this mixin avoids duplication.
mixin NativeLlmParsing {
  /// Build a prompt string for the given processing mode.
  String buildPrompt(String input, ProcessingMode mode) {
    final cleanInput = ClinicalPrompts.sanitize(input);
    return switch (mode) {
      ProcessingMode.vocabAssist => '${ClinicalPrompts.vocabAssist}\n$cleanInput',
      ProcessingMode.cleanTranscript =>
        '${ClinicalPrompts.cleanTranscript}\n$cleanInput',
      ProcessingMode.summarize =>
        '${ClinicalPrompts.structuredSummary}\n$cleanInput',
      ProcessingMode.generateDoctorNote =>
        '${ClinicalPrompts.doctorNote}\n$cleanInput',
      _ => cleanInput,
    };
  }

  /// Parse LLM response as a [StructuredSummary] JSON.
  ///
  /// Tolerates markdown code fences and preamble text before the JSON.
  StructuredSummary parseStructuredSummary(String response) {
    var cleaned = response.trim();

    // Strip markdown code fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }

    // Find JSON block if the model produced preamble text
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
        advice: response.trim(),
      );
    }
  }
}
