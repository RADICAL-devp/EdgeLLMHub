import 'package:doctor_app/core/ai/clinical_prompt_builder.dart';
import 'package:doctor_app/core/ai/edge_ai_service.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

const _json = '''
{
  "chiefComplaint": "Chest pain",
  "historyOfPresentIllness": "Started yesterday",
  "examination": null,
  "assessment": "Possible angina",
  "treatmentPlan": "ECG",
  "followUp": null
}
''';

void main() {
  group('EdgeAiService', () {
    test('reports readiness from the edge gateway', () {
      final gateway = FakeEdgeAiGateway(hasModel: false);
      final service = EdgeAiService(gateway: gateway);
      expect(service.isReady, isFalse);

      gateway.hasModel = true;
      expect(service.isReady, isTrue);
    });

    test(
      'structures a short transcript in one pass and streams final tokens',
      () async {
        final gateway = FakeEdgeAiGateway(responses: [_json]);
        final service = EdgeAiService(gateway: gateway);
        final tokens = <String>[];

        final sections = await service.structureNote(
          transcript: 'Patient has chest pain since yesterday.',
          languageCode: 'en',
          enableThinking: true,
          patientName: 'Asha',
          onToken: tokens.add,
        );

        expect(sections.chiefComplaint, 'Chest pain');
        expect(sections.historyOfPresentIllness, 'Started yesterday');
        expect(sections.examination, isNull);
        expect(gateway.requests, hasLength(1));
        expect(gateway.requests.single.enableThinking, isTrue);
        expect(gateway.requests.single.maxOutputTokens, 1400);
        expect(
          gateway.requests.single.systemInstruction,
          ClinicalPromptBuilder.systemInstruction,
        );
        expect(gateway.requests.single.prompt, contains('Asha'));
        expect(tokens, isNotEmpty);
      },
    );

    test(
      'chunks long transcripts, extracts, and synthesizes the result',
      () async {
        final longTranscript = List.filled(
          900,
          'Patient reports intermittent chest pain and no fever.',
        ).join(' ');
        final gateway = FakeEdgeAiGateway(
          responses: [
            'Chief complaint: Chest pain. Assessment: Possible angina.',
            'Follow-up: Review in two days.',
            _json,
          ],
        );
        final service = EdgeAiService(gateway: gateway);

        final sections = await service.structureNote(
          transcript: longTranscript,
          languageCode: 'en',
        );

        expect(sections.chiefComplaint, 'Chest pain');
        expect(gateway.requests.length, greaterThan(2));
        expect(gateway.requests.first.prompt, contains('ONE portion'));
        expect(gateway.requests.last.prompt, contains('consecutive portions'));
        expect(
          gateway.requests.where((request) => request.enableThinking),
          isEmpty,
          reason: 'Extraction passes should not waste time on thinking mode',
        );
      },
    );

    test(
      'rejects missing models, empty transcripts, and blank cleanup',
      () async {
        final notReady = EdgeAiService(
          gateway: FakeEdgeAiGateway(hasModel: false),
        );
        expect(
          () => notReady.structureNote(
            transcript: 'Some text',
            languageCode: 'en',
          ),
          throwsA(isA<ModelNotReadyException>()),
        );

        final ready = EdgeAiService(gateway: FakeEdgeAiGateway());
        expect(
          () => ready.structureNote(transcript: '   ', languageCode: 'en'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => ready.cleanTranscript(transcript: '  ', languageCode: 'en'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('cleans a transcript without invoking structuring', () async {
      final gateway = FakeEdgeAiGateway(
        responses: ['The patient has chest pain.'],
      );
      final service = EdgeAiService(gateway: gateway);

      final cleaned = await service.cleanTranscript(
        transcript: 'um the patient has chest pain',
        languageCode: 'en',
      );

      expect(cleaned, 'The patient has chest pain.');
      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single.prompt, contains('Clean this'));
      expect(gateway.requests.single.maxOutputTokens, 2000);
    });

    test('wraps unexpected gateway failures as an LLM exception', () async {
      final gateway = _ThrowingGateway();
      final service = EdgeAiService(gateway: gateway);

      expect(
        () => service.structureNote(
          transcript: 'Patient has pain.',
          languageCode: 'en',
        ),
        throwsA(isA<LlmException>()),
      );
    });
  });
}

class _ThrowingGateway extends FakeEdgeAiGateway {
  @override
  Future<String> generate({
    required String systemInstruction,
    required String prompt,
    required bool enableThinking,
    int? maxOutputTokens,
    void Function(String token)? onToken,
  }) async {
    throw StateError('native crash');
  }
}
