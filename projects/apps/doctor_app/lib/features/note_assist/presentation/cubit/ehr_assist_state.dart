import 'package:equatable/equatable.dart';

/// Represents a past consultation used for context enrichment.
class PastConsultationContext extends Equatable {
  final String consultationId;
  final String patientName;
  final String date;
  final String structuredSummary; // JSON string of structured summary
  final double similarityScore; // 0.0 to 1.0

  const PastConsultationContext({
    required this.consultationId,
    required this.patientName,
    required this.date,
    required this.structuredSummary,
    required this.similarityScore,
  });

  @override
  List<Object?> get props =>
      [consultationId, patientName, date, structuredSummary, similarityScore];
}

/// Represents an AI suggestion with confidence metadata.
class AiSuggestion extends Equatable {
  final String fieldName;
  final String suggestion;
  final double confidence; // 0.0 to 1.0
  final List<PastConsultationContext>? contextUsed; // Past consultations used for enrichment
  final String? reasoning; // Optional explanation from LLM

  const AiSuggestion({
    required this.fieldName,
    required this.suggestion,
    required this.confidence,
    this.contextUsed,
    this.reasoning,
  });

  /// Whether the suggestion is high confidence (> 0.8)
  bool get isHighConfidence => confidence >= 0.8;

  /// Whether the suggestion is low confidence (< 0.5)
  bool get isLowConfidence => confidence < 0.5;

  @override
  List<Object?> get props =>
      [fieldName, suggestion, confidence, contextUsed, reasoning];
}

abstract class EhrAssistState extends Equatable {
  const EhrAssistState();

  @override
  List<Object?> get props => [];
}

class EhrAssistInitial extends EhrAssistState {}

class EhrAssistGenerating extends EhrAssistState {
  final String fieldName;
  final String suggestion; // Partial or complete suggestion

  const EhrAssistGenerating({
    required this.fieldName,
    required this.suggestion,
  });

  @override
  List<Object?> get props => [fieldName, suggestion];
}

class EhrAssistSuggestionReady extends EhrAssistState {
  final AiSuggestion suggestion;

  const EhrAssistSuggestionReady({required this.suggestion});

  @override
  List<Object?> get props => [suggestion];
}

class EhrAssistGeneratingMultiple extends EhrAssistState {
  const EhrAssistGeneratingMultiple();

  @override
  List<Object?> get props => [];
}

class EhrAssistMultipleSuggestionsReady extends EhrAssistState {
  final Map<String, AiSuggestion> suggestions;

  const EhrAssistMultipleSuggestionsReady({required this.suggestions});

  @override
  List<Object?> get props => [suggestions];
}

class EhrAssistError extends EhrAssistState {
  final String fieldName;
  final String message;

  const EhrAssistError({required this.fieldName, required this.message});

  @override
  List<Object?> get props => [fieldName, message];
}