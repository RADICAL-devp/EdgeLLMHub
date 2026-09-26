import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/patient_context.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/observability.dart';

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
  final JsonLogger _log;

  bool _nativeAvailable = true;

  HybridLlmAdapter({
    required LlmPort nativeAdapter,
    required LlmPort stubAdapter,
    JsonLogger? logger,
  })  : _nativeAdapter = nativeAdapter,
        _stubAdapter = stubAdapter,
        _log = logger ?? JsonLogger(name: 'llm.hybrid');

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
  }) async* {
    if (_nativeAvailable) {
      _log.info('tier_selected', context: {
        'method': 'generateFieldStream',
        'tier': 'native',
      });
      var emittedOutput = false;
      try {
        await for (final chunk in _nativeAdapter.generateFieldStream(
          fieldName,
          transcriptText,
          patientContext: patientContext,
        )) {
          emittedOutput = true;
          yield chunk;
        }
        return;
      } catch (error, stackTrace) {
        if (emittedOutput) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (error is UnsupportedPlatformException) {
          _log.warn('fallback_triggered', context: {
            'method': 'generateFieldStream',
            'from': 'native',
            'to': 'stub',
            'reason': 'UnsupportedPlatformException',
          });
          _nativeAvailable = false;
        } else if (error is LlmInitializationException) {
          _log.warn('fallback_triggered',
              context: {
                'method': 'generateFieldStream',
                'from': 'native',
                'to': 'stub',
                'reason': 'LlmInitializationException',
              },
              error: error);
          _nativeAvailable = false;
        } else if (error is LlmException) {
          _log.warn('fallback_triggered',
              context: {
                'method': 'generateFieldStream',
                'from': 'native',
                'to': 'stub',
                'reason': 'LlmException',
              },
              error: error);
        } else {
          _log.warn('fallback_triggered',
              context: {
                'method': 'generateFieldStream',
                'from': 'native',
                'to': 'stub',
                'reason': 'UnexpectedError',
              },
              error: error);
          _nativeAvailable = false;
        }
      }
    } else {
      _log.warn('tier_skipped', context: {
        'method': 'generateFieldStream',
        'tier': 'native',
        'reason': 'Unavailable',
      });
    }

    _log.info('tier_selected', context: {
      'method': 'generateFieldStream',
      'tier': 'stub',
    });
    yield* _stubAdapter.generateFieldStream(
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
      _log.info('tier_selected', context: {
        'method': methodName,
        'tier': 'native',
      });
      try {
        final result = await native();
        // Native succeeded — ensure it stays available
        _log.info('tier_succeeded', context: {
          'method': methodName,
          'tier': 'native',
        });
        return result;
      } on UnsupportedPlatformException {
        _log.warn('fallback_triggered', context: {
          'method': methodName,
          'from': 'native',
          'to': 'stub',
          'reason': 'UnsupportedPlatformException',
        });
        _nativeAvailable = false;
      } on LlmInitializationException catch (e) {
        _log.warn('fallback_triggered',
            context: {
              'method': methodName,
              'from': 'native',
              'to': 'stub',
              'reason': 'LlmInitializationException',
            },
            error: e);
        _nativeAvailable = false;
      } on LlmException catch (e) {
        _log.warn('fallback_triggered',
            context: {
              'method': methodName,
              'from': 'native',
              'to': 'stub',
              'reason': 'LlmException',
            },
            error: e);
        // Don't permanently disable for transient inference errors
      } catch (e) {
        _log.warn('fallback_triggered',
            context: {
              'method': methodName,
              'from': 'native',
              'to': 'stub',
              'reason': 'UnexpectedError',
            },
            error: e);
        _nativeAvailable = false;
      }
    } else {
      _log.warn('tier_skipped', context: {
        'method': methodName,
        'tier': 'native',
        'reason': 'Unavailable',
      });
    }

    // --- Tier 2: Stub (always available) ---
    _log.info('tier_selected', context: {
      'method': methodName,
      'tier': 'stub',
    });
    final result = await stub();
    _log.info('tier_succeeded', context: {
      'method': methodName,
      'tier': 'stub',
    });
    return result;
  }
}
