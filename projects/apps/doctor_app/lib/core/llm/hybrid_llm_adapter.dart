import 'dart:developer' as developer;

import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/patient_context.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Two-tier hybrid LLM adapter: native → stub.
///
/// Fallback chain:
///   1. **Native** (on-device MLC on iOS/Android)
///   2. **Stub** (offline placeholder responses)
///
/// Cloud tier removed — PHI never leaves the device.
/// The adapter tracks native availability and avoids repeated failures
/// against a known-broken tier until it is explicitly reset.
class HybridLlmAdapter implements LlmPort {
  final LlmPort _nativeAdapter;
  final LlmPort _stubAdapter;

  bool _nativeAvailable = true;

  HybridLlmAdapter({
    required LlmPort nativeAdapter,
    required LlmPort stubAdapter,
  })  : _nativeAdapter = nativeAdapter,
        _stubAdapter = stubAdapter;

  /// Reset availability flags (e.g., after engine restart).
  void resetAvailability() {
    _nativeAvailable = true;
  }

  @override
  Future<String> processText(String input, ProcessingMode mode) {
    return _withFallback(
      'processText',
      native: () => _nativeAdapter.processText(input, mode),
      stub: () => _stubAdapter.processText(input, mode),
    );
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) {
    return _withFallback(
      'generateStructuredSummary',
      native: () => _nativeAdapter.generateStructuredSummary(transcriptText),
      stub: () => _stubAdapter.generateStructuredSummary(transcriptText),
    );
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) {
    return _withFallback(
      'generateContextEnrichedSummary',
      native: () => _nativeAdapter.generateContextEnrichedSummary(
          transcriptText, pastContext),
      stub: () => _stubAdapter.generateContextEnrichedSummary(
          transcriptText, pastContext),
    );
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) {
    return _withFallback(
      'generateExecutiveSummary',
      native: () => _nativeAdapter.generateExecutiveSummary(transcriptText),
      stub: () => _stubAdapter.generateExecutiveSummary(transcriptText),
    );
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) {
    return _withFallback(
      'generateDoctorNote',
      native: () => _nativeAdapter.generateDoctorNote(transcriptText),
      stub: () => _stubAdapter.generateDoctorNote(transcriptText),
    );
  }

  // ============ FIELD-LEVEL GENERATION ============

  @override
  Future<String> generateField(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    return _withFallback(
      'generateField',
      native: () => _nativeAdapter.generateField(
        fieldName,
        transcriptText,
        patientContext: patientContext,
      ),
      stub: () => _stubAdapter.generateField(
        fieldName,
        transcriptText,
        patientContext: patientContext,
      ),
    );
  }

  @override
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    // For streaming, we try native first, then fall back to stub
    // Note: This is a simplified fallback - in production you might want
    // more sophisticated stream fallback handling
    if (_nativeAvailable) {
      try {
        return _nativeAdapter.generateFieldStream(
          fieldName,
          transcriptText,
          patientContext: patientContext,
        ).handleError((error) {
          _log('generateFieldStream', 'Native stream failed: $error');
          _nativeAvailable = false;
          return _stubAdapter.generateFieldStream(
            fieldName,
            transcriptText,
            patientContext: patientContext,
          );
        });
      } on UnsupportedPlatformException {
        _log('generateFieldStream', 'Native not supported on this platform');
        _nativeAvailable = false;
      } on LlmInitializationException catch (e) {
        _log('generateFieldStream', 'Native LLM not initialized: $e');
        _nativeAvailable = false;
      } catch (e) {
        _log('generateFieldStream', 'Native LLM unexpected error: $e');
        _nativeAvailable = false;
      }
    }

    // --- Tier 2: Stub ---
    _log('generateFieldStream', 'Falling back to offline stub');
    return _stubAdapter.generateFieldStream(
      fieldName,
      transcriptText,
      patientContext: patientContext,
    );
  }

  @override
  Future<Map<String, String>> generateFields(
    List<String> fieldNames,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    return _withFallback(
      'generateFields',
      native: () => _nativeAdapter.generateFields(
        fieldNames,
        transcriptText,
        patientContext: patientContext,
      ),
      stub: () => _stubAdapter.generateFields(
        fieldNames,
        transcriptText,
        patientContext: patientContext,
      ),
    );
  }

  /// Execute with two-tier fallback: native → stub.
  ///
  /// - Skips native if previously failed (until [resetAvailability]).
  /// - Stub always succeeds (hardcoded responses).
  Future<T> _withFallback<T>(
    String methodName, {
    required Future<T> Function() native,
    required Future<T> Function() stub,
  }) async {
    // --- Tier 1: Native (on-device) ---
    if (_nativeAvailable) {
      try {
        final result = await native();
        // Native succeeded — ensure it stays available
        return result;
      } on UnsupportedPlatformException {
        _log(methodName, 'Native not supported on this platform');
        _nativeAvailable = false;
      } on LlmInitializationException catch (e) {
        _log(methodName, 'Native LLM not initialized: $e');
        _nativeAvailable = false;
      } on LlmException catch (e) {
        _log(methodName, 'Native LLM failed: $e');
        // Don't permanently disable for transient inference errors
      } catch (e) {
        _log(methodName, 'Native LLM unexpected error: $e');
        _nativeAvailable = false;
      }
    }

    // --- Tier 2: Stub (always available) ---
    _log(methodName, 'Falling back to offline stub');
    return stub();
  }

  void _log(String method, String message) {
    developer.log(
      '[$method] $message',
      name: 'HybridLlmAdapter',
    );
  }
}
