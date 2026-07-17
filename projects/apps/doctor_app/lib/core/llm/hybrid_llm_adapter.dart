import 'dart:developer' as developer;

import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Three-tier hybrid LLM adapter: native → cloud → stub.
///
/// Fallback chain:
///   1. **Native** (on-device MLC on iOS, Gemma on Android)
///   2. **Cloud** (only if compliance-approved — PHI gate)
///   3. **Stub** (offline placeholder responses)
///
/// The adapter tracks per-tier availability and avoids repeated failures
/// against a known-broken tier until it is explicitly reset.
class HybridLlmAdapter implements LlmPort {
  final LlmPort _nativeAdapter;
  final LlmPort _cloudAdapter;
  final LlmPort _stubAdapter;

  /// Whether cloud processing is allowed by compliance policy.
  /// When false, PHI never leaves the device — cloud tier is skipped entirely.
  final bool cloudEnabled;

  bool _nativeAvailable = true;
  bool _cloudAvailable = true;

  HybridLlmAdapter({
    required LlmPort nativeAdapter,
    required LlmPort cloudAdapter,
    required LlmPort stubAdapter,
    this.cloudEnabled = false,
  })  : _nativeAdapter = nativeAdapter,
        _cloudAdapter = cloudAdapter,
        _stubAdapter = stubAdapter;

  /// Reset availability flags (e.g., after network reconnection).
  void resetAvailability() {
    _nativeAvailable = true;
    _cloudAvailable = true;
  }

  @override
  Future<String> processText(String input, ProcessingMode mode) {
    return _withFallback(
      'processText',
      native: () => _nativeAdapter.processText(input, mode),
      cloud: () => _cloudAdapter.processText(input, mode),
      stub: () => _stubAdapter.processText(input, mode),
    );
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) {
    return _withFallback(
      'generateStructuredSummary',
      native: () => _nativeAdapter.generateStructuredSummary(transcriptText),
      cloud: () => _cloudAdapter.generateStructuredSummary(transcriptText),
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
      cloud: () => _cloudAdapter.generateContextEnrichedSummary(
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
      cloud: () => _cloudAdapter.generateExecutiveSummary(transcriptText),
      stub: () => _stubAdapter.generateExecutiveSummary(transcriptText),
    );
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) {
    return _withFallback(
      'generateDoctorNote',
      native: () => _nativeAdapter.generateDoctorNote(transcriptText),
      cloud: () => _cloudAdapter.generateDoctorNote(transcriptText),
      stub: () => _stubAdapter.generateDoctorNote(transcriptText),
    );
  }

  /// Execute with three-tier fallback: native → cloud → stub.
  ///
  /// - Skips native if previously failed (until [resetAvailability]).
  /// - Skips cloud if compliance is not approved or previously failed.
  /// - Stub always succeeds (hardcoded responses).
  Future<T> _withFallback<T>(
    String methodName, {
    required Future<T> Function() native,
    required Future<T> Function() cloud,
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

    // --- Tier 2: Cloud (compliance-gated) ---
    if (cloudEnabled && _cloudAvailable) {
      try {
        final result = await cloud();
        // Cloud succeeded — mark native as potentially recoverable
        return result;
      } on ComplianceException catch (e) {
        _log(methodName, 'Cloud blocked by compliance: $e');
        _cloudAvailable = false;
      } on NetworkException catch (e) {
        _log(methodName, 'Cloud network error: $e');
        if (!e.isTransient) {
          _cloudAvailable = false;
        }
      } catch (e) {
        _log(methodName, 'Cloud unexpected error: $e');
        _cloudAvailable = false;
      }
    } else if (!cloudEnabled) {
      _log(methodName, 'Cloud fallback disabled (compliance not approved)');
    }

    // --- Tier 3: Stub (always available) ---
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
