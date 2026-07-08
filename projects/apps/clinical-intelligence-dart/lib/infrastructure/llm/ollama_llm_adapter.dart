import 'dart:convert';
import 'dart:io';

import '../../application/ports/llm_port.dart';
import '../../core/models/processing_mode.dart';
import '../../core/models/structured_summary.dart';
import 'prompts/clinical_prompts.dart';

/// Ollama LLM adapter for on-device model execution.
///
/// Connects to a locally running Ollama instance.
/// Default: http://localhost:11434
///
/// Requirements:
///   - Ollama must be installed and running locally
///   - A model must be pulled (e.g., `ollama pull llama3.2` or `ollama pull mistral`)
///
/// Configuration:
///   - [baseUrl]: Ollama API base URL (default: http://localhost:11434)
///   - [model]: Model name (default: llama3.2)
///   - [temperature]: Generation temperature (default: 0.1 for clinical safety)
class OllamaLlmAdapter implements LlmPort {
  OllamaLlmAdapter({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'llama3.2',
    this.temperature = 0.1,
  });

  final String baseUrl;
  final String model;
  final double temperature;

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = switch (mode) {
      ProcessingMode.vocabAssist =>
        '${ClinicalPrompts.vocabAssist}\n$input',
      ProcessingMode.cleanTranscript =>
        '${ClinicalPrompts.cleanTranscript}\n$input',
      ProcessingMode.summarize =>
        '${ClinicalPrompts.structuredSummary}\n$input',
      ProcessingMode.generateDoctorNote =>
        '${ClinicalPrompts.doctorNote}\n$input',
      _ => input,
    };

    return _generate(prompt);
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
    String transcriptText,
  ) async {
    final prompt =
        '${ClinicalPrompts.structuredSummary}\n$transcriptText';
    final response = await _generate(prompt);
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
    final response = await _generate(prompt);
    return _parseStructuredSummary(response);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    final prompt =
        '${ClinicalPrompts.executiveSummary}\n$transcriptText';
    return _generate(prompt);
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    final prompt = '${ClinicalPrompts.doctorNote}\n$transcriptText';
    return _generate(prompt);
  }

  /// Call the Ollama /api/generate endpoint.
  Future<String> _generate(String prompt) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/generate'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': temperature,
        },
      }));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception(
          'Ollama API error (${response.statusCode}): $body',
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['response'] as String? ?? '').trim();
    } finally {
      client.close();
    }
  }

  /// Parse LLM response as StructuredSummary JSON.
  StructuredSummary _parseStructuredSummary(String response) {
    var cleaned = response.trim();

    // Strip markdown code fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
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
        advice: cleaned,
      );
    }
  }
}
