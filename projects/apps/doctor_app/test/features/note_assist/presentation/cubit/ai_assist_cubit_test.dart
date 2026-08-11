import 'package:doctor_app/features/note_assist/domain/services/note_assist_service.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/ai_assist_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/ai_assist_state.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAssistService extends Mock implements NoteAssistService {}

void main() {
  late _MockAssistService service;
  late AiAssistCubit cubit;

  setUp(() {
    service = _MockAssistService();
    cubit = AiAssistCubit(assistService: service);
  });

  tearDown(() => cubit.close());

  group('cleanUpText', () {
    test('emits the final token as SuggestionReady', () async {
      when(() => service.cleanUpText('raw')).thenAnswer(
        (_) => Stream.fromIterable(['Patient ', 'reports ', 'cough.']),
      );

      cubit.cleanUpText('raw');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AiAssistSuggestionReady>());
      final state = cubit.state as AiAssistSuggestionReady;
      expect(state.suggestion, 'cough.');
      expect(state.action, 'cleaning');
    });

    test('emits Error when the stream fails', () async {
      when(() => service.cleanUpText('raw')).thenAnswer(
        (_) => Stream.error(Exception('model crashed')),
      );

      cubit.cleanUpText('raw');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AiAssistError>());
      expect((cubit.state as AiAssistError).message, contains('model crashed'));
    });

    test('interleaves token states during generation', () async {
      final controller = StreamController<String>();
      when(() => service.cleanUpText('raw')).thenAnswer((_) => controller.stream);

      cubit.cleanUpText('raw');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<AiAssistGenerating>());

      controller.add('partial');
      await Future<void>.delayed(Duration.zero);
      expect(
        (cubit.state as AiAssistGenerating).currentSuggestion,
        'partial',
      );

      await controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<AiAssistSuggestionReady>());
    });
  });

  group('extractFields / generateRecap', () {
    test('extractFields emits SuggestionReady with parsed JSON', () async {
      when(() => service.extractFields('structured')).thenAnswer(
        (_) async => '{"symptoms":["cough"]}',
      );

      await cubit.extractFields('structured');

      expect(cubit.state, isA<AiAssistSuggestionReady>());
      final state = cubit.state as AiAssistSuggestionReady;
      expect(state.suggestion, '{"symptoms":["cough"]}');
      expect(state.action, 'extracting fields');
    });

    test('generateRecap emits SuggestionReady with recap', () async {
      when(() => service.generateRecap('structured')).thenAnswer(
        (_) async => 'Patient presented with a persistent cough.',
      );

      await cubit.generateRecap('structured');

      expect(cubit.state, isA<AiAssistSuggestionReady>());
      expect(
        (cubit.state as AiAssistSuggestionReady).suggestion,
        'Patient presented with a persistent cough.',
      );
    });

    test('emits Error when generation fails', () async {
      when(() => service.generateRecap('structured'))
          .thenAnswer((_) => Future.error(Exception('timeout')));

      await cubit.generateRecap('structured');

      expect(cubit.state, isA<AiAssistError>());
      expect((cubit.state as AiAssistError).message, contains('timeout'));
    });
  });

  group('discardSuggestion', () {
    test('returns to initial state', () {
      cubit.discardSuggestion();
      expect(cubit.state, isA<AiAssistInitial>());
    });

    test('cancels an in-flight stream generation', () async {
      final controller = StreamController<String>();
      when(() => service.cleanUpText('raw')).thenAnswer((_) => controller.stream);

      cubit.cleanUpText('raw');
      await Future<void>.delayed(Duration.zero);
      cubit.discardSuggestion();

      // The stream is cancelled — the controller's done listener fires
      // without emitting SuggestionReady.
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<AiAssistInitial>());
    });
  });
}
