import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/ports/llm_port.dart';
import 'package:doctor_app/features/note_assist/data/services/on_device_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLlmPort extends Mock implements LlmPort {}

void main() {
  late _MockLlmPort llmPort;
  late OnDeviceLlmService service;

  setUpAll(() {
    registerFallbackValue(ProcessingMode.cleanTranscript);
  });

  setUp(() {
    llmPort = _MockLlmPort();
    service = OnDeviceLlmService(llmPort);
    when(() => llmPort.processText(any(), any()))
        .thenAnswer((_) async => 'local result');
  });

  test('cleanup sends plain transcript for one native prompt wrapper',
      () async {
    await service.cleanUpText('Patient: cough').drain<void>();

    verify(() => llmPort.processText(
          'Patient: cough',
          ProcessingMode.cleanTranscript,
        )).called(1);
  });

  test('structure sends plain transcript for one native prompt wrapper',
      () async {
    await service.structureNote('Patient: cough').drain<void>();

    verify(() => llmPort.processText(
          'Patient: cough',
          ProcessingMode.summarize,
        )).called(1);
  });
}
