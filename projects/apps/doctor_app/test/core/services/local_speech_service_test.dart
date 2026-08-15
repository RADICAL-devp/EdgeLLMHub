import 'dart:convert';

import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/local_speech_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Verifies VAD wiring: the configurable silence timeout feeds the
/// `speech_to_text` plugin's `pauseFor` (auto-stop on silence).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  Map<dynamic, dynamic>? lastListenArgs;

  setUp(() {
    lastListenArgs = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
          return true;
        case 'locales':
          return ['en_US:English (United States)'];
        case 'listen':
          lastListenArgs = call.arguments as Map<dynamic, dynamic>;
          return true;
        case 'stop':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const codec = StandardMethodCodec();

  Future<void> emit(String method, Object? args) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  String recognitionJson(String words, int resultType) =>
      jsonEncode(SpeechRecognitionResult(
        [
          SpeechRecognitionWords(
            words,
            null,
            1.0,
          ),
        ],
        resultType,
      ).toJson());

  // NOTE: must run first — the SpeechToText singleton binds the error
  // listener on its first successful initialize only.
  test('platform error is surfaced through lastError', () async {
    final service = LocalSpeechService();
    await service.initialize();
    await service.startListening((_) {});

    await emit('notifyError',
        jsonEncode({'errorMsg': 'no speech detected', 'permanent': false}));

    expect(service.lastError, isNotNull);
    expect(service.lastError!.errorMsg, 'no speech detected');
    expect(service.lastError!.permanent, isFalse);
  });

  test('default VAD silence timeout is 2s and feeds the plugin pauseFor',
      () async {
    final service = LocalSpeechService();
    await service.initialize();

    await service.startListening((_) {});

    expect(lastListenArgs, isNotNull);
    expect(lastListenArgs!['pauseFor'], 2000);
    expect(lastListenArgs!['listenFor'], 30000);

    await service.stopListening();
  });

  test('setSilenceTimeout(5s) is forwarded to the plugin pauseFor', () async {
    final service = LocalSpeechService();
    await service.initialize();
    service.setSilenceTimeout(const Duration(seconds: 5));

    await service.startListening((_) {});

    expect(lastListenArgs, isNotNull);
    expect(lastListenArgs!['pauseFor'], 5000);

    await service.stopListening();
  });

  test('setListenTimeout is forwarded to the plugin listenFor', () async {
    final service = LocalSpeechService();
    await service.initialize();
    service.setListenTimeout(45);

    await service.startListening((_) {});

    expect(lastListenArgs!['listenFor'], 45000);

    await service.stopListening();
  });

  test('initialize options override VAD and listen timeouts', () async {
    final service = LocalSpeechService();
    await service.initialize(
      silenceTimeout: const Duration(seconds: 4),
      listenTimeout: 20,
    );

    await service.startListening((_) {});

    expect(lastListenArgs!['pauseFor'], 4000);
    expect(lastListenArgs!['listenFor'], 20000);

    await service.stopListening();
  });

  test('startListening auto-initializes when not yet initialized', () async {
    final service = LocalSpeechService();

    await service.startListening((_) {});

    expect(lastListenArgs, isNotNull);
    expect(lastListenArgs!['pauseFor'], 2000);

    await service.stopListening();
  });

  test('isAvailable reports platform capability', () async {
    expect(await LocalSpeechService.isAvailable(), isTrue);
  });

  test('platform listen failure surfaces as SpeechException', () async {
    final service = LocalSpeechService();
    await service.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
          return true;
        case 'locales':
          return ['en_US:English (United States)'];
        case 'listen':
          throw PlatformException(code: 'stt_error', message: 'busy');
      }
      return null;
    });

    await expectLater(
      service.startListening((_) {}),
      throwsA(
        isA<SpeechException>().having(
          (e) => e.message,
          'message',
          contains('Failed to start speech recognition'),
        ),
      ),
    );
  });

  test('second startListening while already listening is guarded', () async {
    final service = LocalSpeechService();
    await service.initialize();
    var listenCalls = 0;
    const codec = StandardMethodCodec();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'listen') return null;
      listenCalls++;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(
          const MethodCall('notifyStatus', 'listening'),
        ),
        (_) {},
      );
      return true;
    });

    await service.startListening((_) {});
    expect(listenCalls, 1);

    await service.startListening((_) {});
    expect(listenCalls, 1, reason: 'guard should prevent a second listen');

    await service.stopListening();
    await service.startListening((_) {});
    expect(listenCalls, 2);

    await service.stopListening();
  });

  test('setSilenceTimeout resets the VAD dead band between sessions', () async {
    final service = LocalSpeechService();
    await service.initialize();
    service.setSilenceTimeout(const Duration(seconds: 5));
    service.setSilenceTimeout(const Duration(seconds: 2));

    await service.startListening((_) {});

    expect(lastListenArgs!['pauseFor'], 2000);
  });

  group('medical post-processing', () {
    test('final results get medical post-processing', () async {
      final service = LocalSpeechService();
      await service.initialize();
      final results = <String>[];
      await service.startListening(results.add);

      await emit('textRecognition', recognitionJson(
        'he has fever. the patient has bp 120 / 80 and temp 98.6 f '
        'with hr 72 bpm and 120 mm hg and 37 c',
        2,
      ));

      expect(results.single,
          'He has fever. The patient has BP 120/80 and Temp 98.6°F '
          'with HR 72 bpm and 120 mmHg and 37°C.');
    });

    test('partial results get light capitalization only', () async {
      final service = LocalSpeechService();
      await service.initialize();
      final results = <String>[];
      await service.startListening(results.add);

      await emit('textRecognition', recognitionJson('pt has fever', 0));

      expect(results.single, 'Pt has fever');
    });

    test('empty results are passed through unchanged', () async {
      final service = LocalSpeechService();
      await service.initialize();
      final results = <String>[];
      await service.startListening(results.add);

      await emit('textRecognition', recognitionJson('', 2));

      expect(results.single, isEmpty);
    });
  });
}