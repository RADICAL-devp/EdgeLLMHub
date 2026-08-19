import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/patient_context.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'prompts/clinical_prompts.dart';

/// Android native LLM adapter using MLC Android runtime via MethodChannel.
///
/// Communicates with [MLCLLMHandler.kt] which wraps the real MLC Android engine.
/// No platform branching — this class is only instantiated on Android
/// by [LlmPortFactory].
class SmolLLMAdapter implements LlmPort {
  static const _codec = StandardMethodCodec();
  static const _methodChannel = MethodChannel(
    'com.example.clinical/llm',
    _codec,
  );
  static const _streamChannel = EventChannel(
    'com.example.clinical/llm_stream',
    _codec,
  );
  static const _generationTimeout = Duration(seconds: 20);

  /// Serializes concurrent [initialize] calls so the engine is loaded once.
  Future<void>? _initialization;

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = _buildPrompt(input, mode);
    return _generate(prompt);
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = '${ClinicalPrompts.structuredSummary}\n$cleanText';
    final response = await _generate(prompt);
    return _parseStructuredSummary(response);
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
    return _parseStructuredSummary(response);
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

  // ============ FIELD-LEVEL GENERATION ============

  static const _validFieldNames = {
    'complaint',
    'pastHistory',
    'vitals',
    'physicalExamination',
    'investigationOrdered',
    'diagnosis',
    'advice',
    'manualPrescription',
  };

  String _buildFieldPrompt(
    String fieldName,
    String transcriptText,
    PatientContext? patientContext,
  ) {
    final fieldPrompt = ClinicalPrompts.fieldPrompts[fieldName];
    if (fieldPrompt == null) {
      throw ArgumentError(
          'Unknown field: $fieldName. Valid fields: ${_validFieldNames.join(', ')}');
    }

    final buffer = StringBuffer();
    if (patientContext != null) {
      buffer.writeln(patientContext.toPromptContext());
      buffer.writeln('---');
    }
    buffer.write(fieldPrompt);
    buffer.write(transcriptText);
    return buffer.toString();
  }

  @override
  Future<String> generateField(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = _buildFieldPrompt(fieldName, cleanText, patientContext);
    final response = await _generate(prompt);
    return _parseFieldValue(response, fieldName);
  }

  @override
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = _buildFieldPrompt(fieldName, cleanText, patientContext);

    final controller = StreamController<String>();
    StreamSubscription? subscription;

    _ensureInitialized().then((_) {
      subscription = _streamChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is String) {
            if (event == '[DONE]') {
              subscription?.cancel();
              controller.close();
            } else {
              final buffer = StringBuffer();
              buffer.write(event);
              // Emit incremental field value
              final current = _parseFieldValue(buffer.toString(), fieldName);
              if (current.isNotEmpty) {
                controller.add(current);
              }
            }
          }
        },
        onError: (Object error) {
          controller.addError(LlmException(
            'MLC Android LLM stream error: $error',
            cause: error,
            provider: LlmProvider.mlc,
          ));
          subscription?.cancel();
          controller.close();
        },
        onDone: () {
          controller.close();
        },
      );

      _methodChannel
          .invokeMethod<void>('generateStream', {'prompt': prompt})
          .timeout(_generationTimeout)
          .catchError((error) {
            subscription?.cancel();
            controller.addError(LlmException(
              'MLC Android LLM inference error: $error',
              cause: error,
              provider: LlmProvider.mlc,
            ));
            controller.close();
          });
    }).catchError((error) {
      controller.addError(LlmException(
        'Failed to initialize Android native LLM: $error',
        cause: error,
        provider: LlmProvider.mlc,
      ));
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<Map<String, String>> generateFields(
    List<String> fieldNames,
    String transcriptText, {
    PatientContext? patientContext,
  }) async {
    final results = <String, String>{};
    for (final fieldName in fieldNames) {
      results[fieldName] = await generateField(fieldName, transcriptText,
          patientContext: patientContext);
    }
    return results;
  }

  /// Parse a single field value from the LLM response.
  String _parseFieldValue(String response, String fieldName) {
    var cleaned = response.trim();
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
      return (json[fieldName] as String? ?? '').trim();
    } catch (_) {
      // Fallback: return cleaned response
      return cleaned;
    }
  }

  String _buildPrompt(String input, ProcessingMode mode) {
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

  Future<String> _generate(String prompt) async {
    StreamSubscription? subscription;

    try {
      await _ensureInitialized();

      final completer = Completer<String>();
      final buffer = StringBuffer();

      // Subscribe first so native has an EventSink before generation starts.
      subscription = _streamChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is String) {
            if (event == '[DONE]') {
              subscription?.cancel();
              if (!completer.isCompleted) {
                completer.complete(buffer.toString());
              }
            } else {
              buffer.write(event);
            }
          }
        },
        onError: (Object error) {
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(LlmException(
              'MLC Android LLM stream error: $error',
              cause: error,
              provider: LlmProvider.mlc,
            ));
          }
        },
        onDone: () {
          // Stream closed without [DONE] — complete with what we have
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      await _methodChannel
          .invokeMethod<void>('generateStream', {'prompt': prompt})
          .timeout(_generationTimeout);

      return await completer.future.timeout(_generationTimeout);
    } on TimeoutException catch (e) {
      await subscription?.cancel();
      await _cancelNativeGeneration();
      throw LlmException(
        'MLC Android LLM inference timed out after '
        '${_generationTimeout.inSeconds}s.',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on PlatformException catch (e) {
      throw LlmException(
        'MLC Android LLM platform error: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on MissingPluginException catch (e) {
      throw LlmInitializationException(
        'MLC Android LLM handler not registered. Ensure MLCLLMHandler is '
        'configured in MainActivity.kt. Error: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } catch (e) {
      if (e is LlmException) rethrow;
      throw LlmException(
        'Android native LLM inference failed: $e',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } finally {
      await subscription?.cancel();
    }
  }

  /// Lazily ensure the native engine is initialized before first use.
  Future<void> _ensureInitialized() async {
    if (await isAvailable()) return;
    _initialization ??= initialize();
    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  /// Check if the MLC engine is initialized and ready.
  Future<bool> isAvailable() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Initialize the MLC engine on the native side.
  Future<void> initialize() async {
    try {
      await _methodChannel
          .invokeMethod<void>('initialize')
          .timeout(const Duration(seconds: 60)); // Model loading can take time
    } on TimeoutException catch (e) {
      throw LlmInitializationException(
        'Timed out initializing MLC engine after 60s.',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on PlatformException catch (e) {
      throw LlmInitializationException(
        'Failed to initialize MLC engine: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on MissingPluginException catch (e) {
      throw LlmInitializationException(
        'MLC Android LLM handler not registered: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    }
  }

  /// Cancel the active native generation, if one is running.
  Future<void> cancelActiveGeneration() async {
    await _cancelNativeGeneration();
  }

  Future<void> _cancelNativeGeneration() async {
    try {
      await _methodChannel.invokeMethod<void>('cancel');
    } catch (_) {
      // Best effort. The caller will surface the original error.
    }
  }

  /// Return native model metadata exposed by MLCLLMHandler.
  Future<Map<String, Object?>> getModelInfo() async {
    final result = await _methodChannel
        .invokeMapMethod<String, Object?>('getModelInfo')
        .timeout(const Duration(seconds: 10));
    return result ?? const <String, Object?>{};
  }

  /// Warm-up inference to reduce first-request latency.
  Future<void> warmUp() async {
    try {
      await _methodChannel
          .invokeMethod<String>('warmUp')
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // Non-fatal, just log
      developer.log('MLC warm-up failed: $e', name: 'SmolLLMAdapter');
    }
  }

  StructuredSummary _parseStructuredSummary(String response) {
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
