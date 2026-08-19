import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/core/models/patient_context.dart';
import 'package:doctor_app/core/services/telemetry_service.dart';
import 'ehr_assist_state.dart';

/// Cubit for field-level EHR AI assistance.
///
/// Provides real-time AI suggestions for individual EHR form fields
/// (complaint, pastHistory, vitals, etc.) using the HybridLlmAdapter
/// with local-first inference and offline fallback.
///
/// Features:
/// - Context enrichment from vector store (similar past consultations)
/// - Confidence scoring for suggestions
/// - Telemetry for acceptance/rejection tracking
class EhrAssistCubit extends Cubit<EhrAssistState> {
  final LlmPort _llmPort;
  final TelemetryService? _telemetry;

  StreamSubscription<String>? _streamSubscription;
  String? _currentFieldName;
  String? _currentTranscriptText;
  PatientContext? _currentPatientContext;
  List<PastConsultationContext>? _currentContextUsed;

  EhrAssistCubit({
    required LlmPort llmPort,
    TelemetryService? telemetry,
  })  : _llmPort = llmPort,
        _telemetry = telemetry,
        super(EhrAssistInitial());

  /// Request an AI suggestion for a single EHR field with context enrichment.
  ///
  /// [fieldName] must be one of: complaint, pastHistory, vitals,
  /// physicalExamination, investigationOrdered, diagnosis, advice,
  /// manualPrescription
  ///
  /// [transcriptText] is the current consultation transcript (or partial notes).
  /// [patientContext] provides patient metadata (name, sleep lab, date) for better suggestions.
  /// [useContextEnrichment] whether to retrieve similar past consultations from vector store.
  ///
  /// Emits: EhrAssistGenerating → EhrAssistSuggestionReady (or EhrAssistError)
  Future<void> suggestField({
    required String fieldName,
    required String transcriptText,
    PatientContext? patientContext,
    bool useContextEnrichment = true,
  }) async {
    _streamSubscription?.cancel();
    _streamSubscription = null;

    _currentFieldName = fieldName;
    _currentTranscriptText = transcriptText;
    _currentPatientContext = patientContext;

    emit(EhrAssistGenerating(fieldName: fieldName, suggestion: ''));

    try {
      // Retrieve context from vector store if enabled
      List<PastConsultationContext> contextUsed = [];
      String enrichedTranscript = transcriptText;

      if (useContextEnrichment) {
        contextUsed = await _retrieveRelevantContext(transcriptText);
        if (contextUsed.isNotEmpty) {
          enrichedTranscript = _buildEnrichedPrompt(transcriptText, contextUsed);
        }
      }

      // Generate suggestion with context
      final suggestion = await _llmPort.generateField(
        fieldName,
        enrichedTranscript,
        patientContext: patientContext,
      );

      // Calculate confidence based on multiple factors
      final confidence = _calculateConfidence(
        suggestion,
        fieldName,
        transcriptText,
        contextUsed,
      );

      _currentContextUsed = contextUsed;

      if (!isClosed) {
        emit(EhrAssistSuggestionReady(
          suggestion: AiSuggestion(
            fieldName: fieldName,
            suggestion: suggestion,
            confidence: confidence,
            contextUsed: contextUsed.isNotEmpty ? contextUsed : null,
          ),
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(EhrAssistError(fieldName: fieldName, message: e.toString()));
      }
    }
  }

  /// Stream an AI suggestion for a single EHR field with context enrichment.
  ///
  /// Emits incremental tokens as they are generated.
  /// Emits: EhrAssistGenerating (multiple) → EhrAssistSuggestionReady (or EhrAssistError)
  Future<void> suggestFieldStream({
    required String fieldName,
    required String transcriptText,
    PatientContext? patientContext,
    bool useContextEnrichment = true,
  }) async {
    _streamSubscription?.cancel();
    _streamSubscription = null;

    _currentFieldName = fieldName;
    _currentTranscriptText = transcriptText;
    _currentPatientContext = patientContext;

    final buffer = StringBuffer();
    emit(EhrAssistGenerating(fieldName: fieldName, suggestion: ''));

    try {
      // Retrieve context from vector store if enabled
      List<PastConsultationContext> contextUsed = [];
      String enrichedTranscript = transcriptText;

      if (useContextEnrichment) {
        contextUsed = await _retrieveRelevantContext(transcriptText);
        if (contextUsed.isNotEmpty) {
          enrichedTranscript = _buildEnrichedPrompt(transcriptText, contextUsed);
        }
      }

      _currentContextUsed = contextUsed;

      _streamSubscription = _llmPort
          .generateFieldStream(
            fieldName,
            enrichedTranscript,
            patientContext: patientContext,
          )
          .listen(
            (token) {
              if (!isClosed) {
                buffer.write(token);
                emit(EhrAssistGenerating(
                  fieldName: fieldName,
                  suggestion: buffer.toString(),
                ));
              }
            },
            onDone: () async {
              if (!isClosed) {
                final finalSuggestion = buffer.toString();
                final confidence = _calculateConfidence(
                  finalSuggestion,
                  fieldName,
                  transcriptText,
                  contextUsed,
                );

                emit(EhrAssistSuggestionReady(
                  suggestion: AiSuggestion(
                    fieldName: fieldName,
                    suggestion: finalSuggestion,
                    confidence: confidence,
                    contextUsed: contextUsed.isNotEmpty ? contextUsed : null,
                  ),
                ));
              }
              _streamSubscription = null;
            },
            onError: (e) {
              if (!isClosed) {
                emit(EhrAssistError(
                  fieldName: fieldName,
                  message: e.toString(),
                ));
              }
              _streamSubscription = null;
            },
          );
    } catch (e) {
      if (!isClosed) {
        emit(EhrAssistError(fieldName: fieldName, message: e.toString()));
      }
    }
  }

  /// Request AI suggestions for multiple EHR fields at once with context enrichment.
  Future<void> suggestFields({
    required List<String> fieldNames,
    required String transcriptText,
    PatientContext? patientContext,
    bool useContextEnrichment = true,
  }) async {
    _streamSubscription?.cancel();
    _streamSubscription = null;

    emit(const EhrAssistGeneratingMultiple());

    try {
      List<PastConsultationContext> contextUsed = [];
      String enrichedTranscript = transcriptText;

      if (useContextEnrichment) {
        contextUsed = await _retrieveRelevantContext(transcriptText);
        if (contextUsed.isNotEmpty) {
          enrichedTranscript = _buildEnrichedPrompt(transcriptText, contextUsed);
        }
      }

      final results = await _llmPort.generateFields(
        fieldNames,
        enrichedTranscript,
        patientContext: patientContext,
      );

      if (!isClosed) {
        final suggestionsWithConfidence = <String, AiSuggestion>{};
        for (final entry in results.entries) {
          final confidence = _calculateConfidence(
            entry.value,
            entry.key,
            transcriptText,
            contextUsed,
          );
          suggestionsWithConfidence[entry.key] = AiSuggestion(
            fieldName: entry.key,
            suggestion: entry.value,
            confidence: confidence,
            contextUsed: contextUsed.isNotEmpty ? contextUsed : null,
          );
        }
        emit(EhrAssistMultipleSuggestionsReady(
          suggestions: suggestionsWithConfidence,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(EhrAssistError(
          fieldName: fieldNames.join(', '),
          message: e.toString(),
        ));
      }
    }
  }

  /// Accept the current suggestion and log telemetry.
  void acceptSuggestion() {
    if (state is EhrAssistSuggestionReady) {
      final suggestion = (state as EhrAssistSuggestionReady).suggestion;
      _logTelemetry(
        event: 'suggestion_accepted',
        fieldName: suggestion.fieldName,
        confidence: suggestion.confidence,
        contextUsedCount: suggestion.contextUsed?.length ?? 0,
      );
    }
    _streamSubscription?.cancel();
    _streamSubscription = null;
    emit(EhrAssistInitial());
  }

  /// Discard the current suggestion and log telemetry.
  void discardSuggestion() {
    if (state is EhrAssistSuggestionReady) {
      final suggestion = (state as EhrAssistSuggestionReady).suggestion;
      _logTelemetry(
        event: 'suggestion_discarded',
        fieldName: suggestion.fieldName,
        confidence: suggestion.confidence,
        contextUsedCount: suggestion.contextUsed?.length ?? 0,
      );
    }
    _streamSubscription?.cancel();
    _streamSubscription = null;
    emit(EhrAssistInitial());
  }

  /// Edit and accept a modified suggestion.
  void acceptEditedSuggestion(String editedSuggestion) {
    if (state is EhrAssistSuggestionReady) {
      final original = (state as EhrAssistSuggestionReady).suggestion;
      _logTelemetry(
        event: 'suggestion_edited_accepted',
        fieldName: original.fieldName,
        confidence: original.confidence,
        contextUsedCount: original.contextUsed?.length ?? 0,
      );
    }
    _streamSubscription?.cancel();
    _streamSubscription = null;
    emit(EhrAssistInitial());
  }

  /// Cancel any ongoing generation.
  void cancel() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    emit(EhrAssistInitial());
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    return super.close();
  }

  /// Retrieve relevant past consultations from vector store.
  ///
  /// In production, this calls the backend /api/v1/ehr/past-context endpoint.
  /// For now, returns empty list as placeholder.
  Future<List<PastConsultationContext>> _retrieveRelevantContext(
    String transcriptText,
  ) async {
    try {
      // TODO: Call backend API to retrieve similar consultations
      // Example endpoint: POST /api/v1/ehr/past-context
      // Body: { "transcriptText": transcriptText, "doctorId": "...", "topK": 3 }
      // Response: List of past consultations with similarity scores
      //
      // For now, return empty list. The backend vector store integration
      // is already implemented in clinical-intelligence-dart.
      return [];
    } catch (e) {
      // Silently fail - context enrichment is optional
      return [];
    }
  }

  /// Build enriched prompt with past consultation context.
  String _buildEnrichedPrompt(
    String transcriptText,
    List<PastConsultationContext> context,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('PAST CONSULTATION CONTEXT (for style consistency only):');
    buffer.writeln('---');
    for (final ctx in context) {
      buffer.writeln('Consultation ${ctx.consultationId} (${ctx.date}, ${ctx.patientName}):');
      buffer.writeln('Similarity: ${(ctx.similarityScore * 100).toStringAsFixed(0)}%');
      buffer.writeln(ctx.structuredSummary);
      buffer.writeln('---');
    }
    buffer.writeln('CURRENT CONSULTATION TO SUMMARIZE:');
    buffer.writeln(transcriptText);
    return buffer.toString();
  }

  /// Calculate confidence score for a suggestion.
  ///
  /// Factors:
  /// - Length and completeness of suggestion (0.0-0.3)
  /// - Whether context enrichment was used (0.0-0.2)
  /// - Whether suggestion contains "Not documented" (reduces confidence)
  /// - Field-specific heuristics
  double _calculateConfidence(
    String suggestion,
    String fieldName,
    String transcriptText,
    List<PastConsultationContext> contextUsed,
  ) {
    double confidence = 0.5; // Base confidence

    // Factor 1: Suggestion quality (length, not "Not documented")
    if (suggestion.isNotEmpty) {
      confidence += 0.1;
    }
    if (suggestion.length > 50) {
      confidence += 0.1;
    }
    if (!suggestion.toLowerCase().contains('not documented')) {
      confidence += 0.1;
    }

    // Factor 2: Context enrichment used
    if (contextUsed.isNotEmpty) {
      confidence += 0.1;
      // Higher similarity = more confidence
      final avgSimilarity = contextUsed
          .map((c) => c.similarityScore)
          .reduce((a, b) => a + b) /
          contextUsed.length;
      confidence += avgSimilarity * 0.1;
    }

    // Factor 3: Field-specific adjustments
    switch (fieldName) {
      case 'vitals':
      case 'investigationOrdered':
        // These fields have specific numeric values - higher confidence if numbers present
        if (RegExp(r'\d+').hasMatch(suggestion)) {
          confidence += 0.1;
        }
        break;
      case 'diagnosis':
        // Diagnosis should have ICD-10 codes
        if (RegExp(r'[A-Z]\d{2}').hasMatch(suggestion)) {
          confidence += 0.1;
        }
        break;
      case 'advice':
        // Advice should have numbered recommendations
        if (RegExp(r'\d+\.').hasMatch(suggestion)) {
          confidence += 0.1;
        }
        break;
    }

    // Clamp to [0.0, 1.0]
    return confidence.clamp(0.0, 1.0);
  }

  /// Log telemetry event for suggestion interactions.
  void _logTelemetry({
    required String event,
    required String fieldName,
    required double confidence,
    required int contextUsedCount,
    Map<String, dynamic>? extra,
  }) {
    if (_telemetry == null) return;

    final data = {
      'event': event,
      'fieldName': fieldName,
      'confidence': confidence,
      'contextUsedCount': contextUsedCount,
      'timestamp': DateTime.now().toIso8601String(),
      if (extra != null) ...extra,
    };

    _telemetry!.logEvent('ehr_assist', data);
  }
}