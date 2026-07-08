import 'package:equatable/equatable.dart';

abstract class AiAssistState extends Equatable {
  const AiAssistState();

  @override
  List<Object?> get props => [];
}

class AiAssistInitial extends AiAssistState {}

class AiAssistGenerating extends AiAssistState {
  final String currentSuggestion;
  final String activeAction; // e.g., 'cleaning', 'structuring'

  const AiAssistGenerating(this.currentSuggestion, this.activeAction);

  @override
  List<Object?> get props => [currentSuggestion, activeAction];
}

class AiAssistSuggestionReady extends AiAssistState {
  final String suggestion;
  final String action;

  const AiAssistSuggestionReady(this.suggestion, this.action);

  @override
  List<Object?> get props => [suggestion, action];
}

class AiAssistError extends AiAssistState {
  final String message;

  const AiAssistError(this.message);

  @override
  List<Object?> get props => [message];
}
