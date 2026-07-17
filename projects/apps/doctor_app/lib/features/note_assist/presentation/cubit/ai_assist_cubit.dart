import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../domain/services/note_assist_service.dart';
import 'ai_assist_state.dart';

class AiAssistCubit extends Cubit<AiAssistState> {
  final NoteAssistService _assistService;
  StreamSubscription<String>? _generationSubscription;

  AiAssistCubit({required NoteAssistService assistService})
      : _assistService = assistService,
        super(AiAssistInitial());

  void cleanUpText(String rawText) {
    _startGenerationStream(
      _assistService.cleanUpText(rawText),
      'cleaning',
    );
  }

  void structureNote(String cleanedText) {
    _startGenerationStream(
      _assistService.structureNote(cleanedText),
      'structuring',
    );
  }

  void _startGenerationStream(Stream<String> stream, String action) {
    _generationSubscription?.cancel();
    _generationSubscription = null;
    emit(AiAssistGenerating('', action));

    _generationSubscription = stream.listen(
      (text) {
        if (!isClosed) {
          emit(AiAssistGenerating(text, action));
        }
      },
      onDone: () {
        if (!isClosed && state is AiAssistGenerating) {
          final current = (state as AiAssistGenerating).currentSuggestion;
          emit(AiAssistSuggestionReady(current, action));
        }
        _generationSubscription = null;
      },
      onError: (e) {
        if (!isClosed) {
          emit(AiAssistError(e.toString()));
        }
        _generationSubscription = null;
      },
    );
  }

  Future<void> extractFields(String structuredText) async {
    _startGenerationFuture(
      _assistService.extractFields(structuredText),
      'extracting fields',
    );
  }

  Future<void> generateRecap(String structuredText) async {
    _startGenerationFuture(
      _assistService.generateRecap(structuredText),
      'generating recap',
    );
  }

  void _startGenerationFuture(Future<String> future, String action) async {
    _generationSubscription?.cancel(); // Cancel any ongoing stream
    emit(AiAssistGenerating('', action));
    try {
      final result = await future;
      if (!isClosed) {
        emit(AiAssistSuggestionReady(result, action));
      }
    } catch (e) {
      if (!isClosed) {
        emit(AiAssistError(e.toString()));
      }
    }
  }

  void discardSuggestion() {
    _generationSubscription?.cancel();
    emit(AiAssistInitial());
  }

  @override
  Future<void> close() {
    _generationSubscription?.cancel();
    return super.close();
  }
}
