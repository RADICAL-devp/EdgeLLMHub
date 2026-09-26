import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:doctor_app/core/observability.dart';
import '../../domain/services/note_assist_service.dart';
import 'ai_assist_state.dart';

class AiAssistCubit extends Cubit<AiAssistState> {
  final NoteAssistService _assistService;
  final JsonLogger _log;
  StreamSubscription<String>? _generationSubscription;

  AiAssistCubit({
    required NoteAssistService assistService,
    JsonLogger? logger,
  })  : _assistService = assistService,
        _log = logger ?? JsonLogger(name: 'cubit.ai_assist'),
        super(AiAssistInitial());

  void cleanUpText(String rawText) {
    _startGenerationStream(
      _assistService.cleanUpText(rawText),
      'cleaning',
      inputChars: rawText.length,
    );
  }

  void structureNote(String cleanedText) {
    _startGenerationStream(
      _assistService.structureNote(cleanedText),
      'structuring',
      inputChars: cleanedText.length,
    );
  }

  void _startGenerationStream(
    Stream<String> stream,
    String action, {
    int? inputChars,
  }) {
    _generationSubscription?.cancel();
    _generationSubscription = null;
    _log.info(
      'request_received',
      context: {
        'action': action,
        if (inputChars != null) 'inputChars': inputChars
      },
    );
    emit(AiAssistGenerating('', action));
    _log.info('generation_started', context: {'action': action});

    _generationSubscription = stream.listen(
      (text) {
        if (!isClosed) {
          emit(AiAssistGenerating(text, action));
        }
      },
      onDone: () {
        if (!isClosed && state is AiAssistGenerating) {
          final current = (state as AiAssistGenerating).currentSuggestion;
          _log.info(
            'generation_completed',
            context: {'action': action, 'resultChars': current.length},
          );
          emit(AiAssistSuggestionReady(current, action));
        }
        _generationSubscription = null;
      },
      onError: (e) {
        _log.warn('generation_error', context: {'action': action}, error: e);
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
      inputChars: structuredText.length,
    );
  }

  Future<void> generateRecap(String structuredText) async {
    _startGenerationFuture(
      _assistService.generateRecap(structuredText),
      'generating recap',
      inputChars: structuredText.length,
    );
  }

  void _startGenerationFuture(
    Future<String> future,
    String action, {
    int? inputChars,
  }) async {
    _generationSubscription?.cancel(); // Cancel any ongoing stream
    _log.info(
      'request_received',
      context: {
        'action': action,
        if (inputChars != null) 'inputChars': inputChars
      },
    );
    emit(AiAssistGenerating('', action));
    _log.info('generation_started', context: {'action': action});
    try {
      final result = await future;
      _log.info(
        'generation_completed',
        context: {'action': action, 'resultChars': result.length},
      );
      if (!isClosed) {
        emit(AiAssistSuggestionReady(result, action));
      }
    } catch (e) {
      _log.warn('generation_error', context: {'action': action}, error: e);
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
