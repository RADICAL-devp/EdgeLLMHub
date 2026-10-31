import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/exceptions/app_exceptions.dart';

class StructureNoteState extends Equatable {
  const StructureNoteState({
    this.isGenerating = false,
    this.generatedTokenCount = 0,
    this.sections,
    this.error,
  });

  final bool isGenerating;
  final int generatedTokenCount;
  final StructuredNoteSections? sections;
  final String? error;

  StructureNoteState copyWith({
    bool? isGenerating,
    int? generatedTokenCount,
    StructuredNoteSections? sections,
    String? error,
    bool clearError = false,
    bool clearSections = false,
  }) {
    return StructureNoteState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatedTokenCount: generatedTokenCount ?? this.generatedTokenCount,
      sections: clearSections ? null : (sections ?? this.sections),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    isGenerating,
    generatedTokenCount,
    sections?.toJson().toString(),
    error,
  ];
}

class StructureNoteCubit extends Cubit<StructureNoteState> {
  StructureNoteCubit({required AIService ai})
    : _ai = ai,
      super(const StructureNoteState());

  final AIService _ai;

  bool get isReady => _ai.isReady;

  Future<StructuredNoteSections?> generate({
    required String transcript,
    required String languageCode,
    required bool enableThinking,
    String patientName = '',
  }) async {
    if (state.isGenerating) return null;
    emit(const StructureNoteState(isGenerating: true));
    try {
      final sections = await _ai.structureNote(
        transcript: transcript,
        languageCode: languageCode,
        enableThinking: enableThinking,
        patientName: patientName,
        onToken: (_) {
          if (isClosed) return;
          // Never render or persist raw model tokens; only show activity.
          final next = state.generatedTokenCount + 1;
          if (next % 8 == 0) {
            emit(state.copyWith(generatedTokenCount: next));
          }
        },
      );
      if (isClosed) return null;
      emit(StructureNoteState(sections: sections, generatedTokenCount: 0));
      return sections;
    } on AppException catch (error) {
      if (!isClosed) {
        emit(StructureNoteState(error: error.message));
      }
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          const StructureNoteState(
            error:
                'The on-device model could not structure this note. Try again '
                'or edit the sections manually.',
          ),
        );
      }
      return null;
    }
  }

  Future<String?> cleanTranscript({
    required String transcript,
    required String languageCode,
    required bool enableThinking,
  }) async {
    if (state.isGenerating) return null;
    emit(const StructureNoteState(isGenerating: true));
    try {
      final cleaned = await _ai.cleanTranscript(
        transcript: transcript,
        languageCode: languageCode,
        enableThinking: enableThinking,
        onToken: (_) {
          if (isClosed) return;
          final next = state.generatedTokenCount + 1;
          if (next % 8 == 0) {
            emit(state.copyWith(generatedTokenCount: next));
          }
        },
      );
      if (!isClosed) emit(const StructureNoteState());
      return cleaned;
    } on AppException catch (error) {
      if (!isClosed) emit(StructureNoteState(error: error.message));
      return null;
    } catch (_) {
      if (!isClosed) {
        emit(
          const StructureNoteState(
            error:
                'The transcript could not be cleaned up. The original text '
                'was kept.',
          ),
        );
      }
      return null;
    }
  }

  void reset() {
    if (state.isGenerating) return;
    emit(const StructureNoteState());
  }
}
