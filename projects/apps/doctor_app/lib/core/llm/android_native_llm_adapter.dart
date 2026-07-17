import 'dart:convert';

import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'prompts/clinical_prompts.dart';

/// Shared JSON-parsing logic for native LLM adapters.
///
/// Both Android (Gemma) and iOS (MLC) adapters parse the same structured
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

/// Android native LLM adapter using Google AI Edge / flutter_gemma.
///
/// No platform branching — this class is only instantiated on Android
/// by [LlmPortFactory].
class AndroidNativeLlmAdapter with NativeLlmParsing implements LlmPort {
  // Lazily imported to avoid pulling flutter_gemma on iOS.
  // The factory ensures this class is never instantiated on iOS.

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = buildPrompt(input, mode);
    return _generate(prompt);
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
      String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = '${ClinicalPrompts.structuredSummary}\n$cleanText';
    final response = await _generate(prompt);
    return parseStructuredSummary(response);
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final cleanContext = ClinicalPrompts.sanitize(pastContext);
    final prompt = 'PAST CONTEXT from this doctor\'s consultations:\n'
        '$cleanContext\n\n---\n\n'
        '${ClinicalPrompts.structuredSummary}\n$cleanText';
    final response = await _generate(prompt);
    return parseStructuredSummary(response);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = '${ClinicalPrompts.executiveSummary}\n$cleanText';
    return _generate(prompt);
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = '${ClinicalPrompts.doctorNote}\n$cleanText';
    return _generate(prompt);
  }

  Future<String> _generate(String prompt) async {
    try {
      // Dynamic import to avoid compile-time dependency on iOS
      final gemma = await _getGemmaPlugin();
      final response = await gemma.getResponse(prompt: prompt);
      return response ?? '';
    } catch (e) {
      throw LlmException(
        'Android native LLM inference failed: $e',
        cause: e,
        provider: LlmProvider.gemma,
      );
    }
  }

  /// Lazily access the flutter_gemma plugin instance.
  Future<dynamic> _getGemmaPlugin() async {
    try {
      // Use flutter_gemma's static accessor
      final module = await Future.value(
        _gemmaInstance ??= _initGemma(),
      );
      return module;
    } catch (e) {
      throw LlmInitializationException(
        'Failed to initialize Gemma plugin: $e',
        cause: e,
        provider: LlmProvider.gemma,
      );
    }
  }

  dynamic _gemmaInstance;

  dynamic _initGemma() {
    // flutter_gemma is already a pubspec dependency.
    // This class is only instantiated on Android by LlmPortFactory,
    // so this import is safe even though it would fail on iOS at runtime.
    return _FlutterGemmaProxy();
  }
}

/// Proxy to isolate flutter_gemma usage to Android-only codepath.
///
/// flutter_gemma is listed in pubspec.yaml and compiles on all platforms,
/// but only works at runtime on Android. [LlmPortFactory] ensures this
/// class is never instantiated on iOS.
class _FlutterGemmaProxy {
  Future<String?> getResponse({required String prompt}) async {
    try {
      // Access flutter_gemma via the existing pubspec dependency.
      // The package compiles on all platforms but only functions on Android.
      final gemma = FlutterGemmaPlugin.instance;
      return await gemma.getResponse(prompt: prompt);
    } catch (e) {
      throw LlmInitializationException(
        'flutter_gemma not available: $e',
        cause: e,
        provider: LlmProvider.gemma,
      );
    }
  }
}

