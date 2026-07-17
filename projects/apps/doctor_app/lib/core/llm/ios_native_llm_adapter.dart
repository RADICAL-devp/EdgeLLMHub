import 'dart:async';

import 'package:flutter/services.dart';

import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/llm/android_native_llm_adapter.dart'
    show NativeLlmParsing;
import 'prompts/clinical_prompts.dart';

/// iOS native LLM adapter using MLC LLM via MethodChannel.
///
/// Communicates with [MLCLLMHandler.swift] which wraps the real MLCEngine
/// API (from the MLCSwift package). No platform branching — this class is
/// only instantiated on physical iOS devices by [LlmPortFactory].
///
/// Channel contract:
///   MethodChannel('com.example.clinical/llm'):
///     - 'isAvailable' → bool
///     - 'initialize' → void
///     - 'generate' → String (non-streaming)
///     - 'generateStream' → triggers EventChannel stream
///
///   EventChannel('com.example.clinical/llm_stream'):
///     - Emits String tokens, ends with '[DONE]' sentinel
class IosNativeLlmAdapter with NativeLlmParsing implements LlmPort {
  static const _methodChannel =
      MethodChannel('com.example.clinical/llm');
  static const _streamChannel =
      EventChannel('com.example.clinical/llm_stream');

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

  /// Generate text using the iOS MLC LLM via streaming EventChannel.
  ///
  /// 1. Sends 'generateStream' to the MethodChannel to start native generation.
  /// 2. Listens to the EventChannel for token-by-token output.
  /// 3. Completes when '[DONE]' sentinel is received.
  Future<String> _generate(String prompt) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      // Start generation on the native side
      await _methodChannel.invokeMethod('generateStream', {
        'prompt': prompt,
      });

      StreamSubscription? subscription;
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
              'MLC LLM stream error: $error',
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

      return completer.future;
    } on PlatformException catch (e) {
      throw LlmException(
        'MLC LLM platform error: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on MissingPluginException catch (e) {
      throw LlmInitializationException(
        'MLC LLM handler not registered. Ensure MLCLLMHandler is '
        'configured in AppDelegate.swift. Error: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } catch (e) {
      if (e is LlmException) rethrow;
      throw LlmException(
        'iOS native LLM inference failed: $e',
        cause: e,
        provider: LlmProvider.mlc,
      );
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
      await _methodChannel.invokeMethod<void>('initialize');
    } on PlatformException catch (e) {
      throw LlmInitializationException(
        'Failed to initialize MLC engine: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    } on MissingPluginException catch (e) {
      throw LlmInitializationException(
        'MLC LLM handler not registered: ${e.message}',
        cause: e,
        provider: LlmProvider.mlc,
      );
    }
  }
}
