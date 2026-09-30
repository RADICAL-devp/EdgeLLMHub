import 'dart:async';
import 'dart:convert';

import 'package:doctor_app/core/llm/gemma_backend.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/patient_context.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/llm/native_llm_parsing.dart';
import 'package:doctor_app/core/observability.dart';
import '../utils/debounce.dart';
import 'prompts/clinical_prompts.dart';

/// On-device LLM adapter backed by flutter_gemma (LiteRT-LM, Qwen3 0.6B).
///
/// Replaces the MLC MethodChannel adapters (`ios_native_llm_adapter.dart`,
/// `smol_llm_adapter.dart`) with a single cross-platform implementation:
/// model delivery is a published `.litertlm` file, so changing models never
/// requires a native recompile. Engine registration happens once in `main()`
/// via `FlutterGemma.initialize`; model install state is owned by
/// flutter_gemma's store and surfaced through [ModelManagerCubit].
///
/// Thinking mode is exposed, never silent: thinking traces are logged (and
/// forwarded to [onThinkingSink] when set, e.g. a debug surface) while
/// parsers only ever see the final answer, keeping clinical output parseable.
class FlutterGemmaLlmAdapter with NativeLlmParsing implements LlmPort {
  static const _generationTimeout = Duration(seconds: 60);
  static const _maxOutputTokens = 512;

  final GemmaBackend _backend;
  final JsonLogger _log;

  /// Receives thinking traces (Qwen3 thinking mode). Null by default —
  /// traces are still recorded in logs.
  void Function(String thinking)? onThinkingSink;

  FlutterGemmaLlmAdapter({
    GemmaBackend? backend,
    JsonLogger? logger,
  })  : _backend = backend ?? FlutterGemmaBackend(),
        _log = logger ?? JsonLogger(name: 'llm.flutter_gemma');

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    final prompt = buildPrompt(input, mode);
    final rawResponse = await _generate(prompt);
    return validateAndCleanResponse(rawResponse, mode);
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
    final rawResponse = await _generate(prompt);
    return validateAndCleanResponse(
        rawResponse, ProcessingMode.cleanTranscript);
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = '${ClinicalPrompts.doctorNote}\n$cleanText';
    final rawResponse = await _generate(prompt);
    return validateAndCleanResponse(
        rawResponse, ProcessingMode.generateDoctorNote);
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
    return parseFieldValue(response, fieldName);
  }

  @override
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) async* {
    final cleanText = ClinicalPrompts.sanitize(transcriptText);
    final prompt = _buildFieldPrompt(fieldName, cleanText, patientContext);
    final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
    final controller = StreamController<String>();
    final buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    void emitThinking(String thinking) {
      _recordThinking(fieldName, thinking);
    }

    try {
      _log.info('generate_start',
          context: {'method': 'generateFieldStream', 'tier': 'gemma'});
      subscription = _backend
          .generateStream(
        prompt: prompt,
        maxOutputTokens: _maxOutputTokens,
        enableThinking: true,
        onThinking: emitThinking,
      )
          .timeout(_generationTimeout)
          .listen(
        (partial) {
          buffer
            ..clear()
            ..write(partial);
          debouncer.run(() {
            if (controller.isClosed) return;
            final current = parseFieldValue(buffer.toString(), fieldName);
            if (current.isNotEmpty) {
              controller.add(current);
            }
          });
        },
        onError: (Object error) {
          debouncer.dispose();
          controller.addError(_wrap(error, 'stream'));
          controller.close();
        },
        onDone: () {
          // Flush the final value synchronously: with fast token delivery
          // the pending debounce may never fire before the stream ends.
          debouncer.flush(() {
            if (controller.isClosed) return;
            final current = parseFieldValue(buffer.toString(), fieldName);
            if (current.isNotEmpty) {
              controller.add(current);
            }
          });
          controller.close();
        },
      );

      await for (final value in controller.stream) {
        yield value;
      }
    } catch (e) {
      throw _wrap(e, 'stream');
    } finally {
      debouncer.dispose();
      await subscription?.cancel();
      if (!controller.isClosed) await controller.close();
    }
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
  String parseFieldValue(String response, String fieldName) {
    var cleaned = response.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return (json[fieldName] as String? ?? '').trim();
    } catch (_) {
      // Fallback: return cleaned response
      return cleaned;
    }
  }

  /// Single generation through flutter_gemma with thinking enabled.
  ///
  /// Thinking traces go to logs/sink; only the final answer is returned.
  Future<String> _generate(String prompt) async {
    try {
      _log.info('generate_start',
          context: {'method': 'generate', 'tier': 'gemma'});
      final result = await _backend
          .generate(
            prompt: prompt,
            maxOutputTokens: _maxOutputTokens,
            enableThinking: true,
            onThinking: (thinking) =>
                _recordThinking('generate', thinking),
          )
          .timeout(_generationTimeout);
      if (result.text.isEmpty) {
        throw const LlmException(
          'flutter_gemma returned an empty response',
          provider: LlmProvider.gemma,
        );
      }
      return result.text;
    } on TimeoutException catch (e) {
      _log.error('inference_timeout',
          context: {
            'method': 'generate',
            'timeoutSeconds': _generationTimeout.inSeconds,
          },
          error: e);
      throw LlmException(
        'flutter_gemma inference timed out after '
        '${_generationTimeout.inSeconds}s.',
        cause: e,
        provider: LlmProvider.gemma,
      );
    } catch (e) {
      throw _wrap(e, 'generate');
    }
  }

  void _recordThinking(String scope, String thinking) {
    if (thinking.isEmpty) return;
    _log.info('thinking_trace',
        context: {'scope': scope, 'chars': thinking.length});
    onThinkingSink?.call(thinking);
  }

  LlmException _wrap(Object error, String method) {
    if (error is LlmException) return error;
    _log.error('inference_failed',
        context: {'method': method, 'tier': 'gemma'}, error: error);
    return LlmException(
      'flutter_gemma inference failed: $error',
      cause: error,
      provider: LlmProvider.gemma,
    );
  }
}
