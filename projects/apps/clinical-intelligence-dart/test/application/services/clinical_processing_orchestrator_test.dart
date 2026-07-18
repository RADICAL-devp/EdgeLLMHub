import 'package:clinical_intelligence_dart/api/dto/clinical_processing_request.dart';
import 'package:clinical_intelligence_dart/application/services/clinical_processing_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/terminology_assistance_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_cleanup_service.dart';
import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:clinical_intelligence_dart/core/models/processing_mode.dart';
import 'package:clinical_intelligence_dart/infrastructure/llm/stub_llm_adapter.dart';
import 'package:test/test.dart';

void main() {
  late ClinicalProcessingOrchestrator orchestrator;

  setUp(() {
    final llmPort = StubLlmAdapter();
    final normalizationService = TranscriptNormalizationService();

    orchestrator = ClinicalProcessingOrchestrator(
      validationService: ValidationService(),
      terminologyAssistanceService: TerminologyAssistanceService(
        llmPort: llmPort,
        normalizationService: normalizationService,
      ),
      transcriptCleanupService: TranscriptCleanupService(
        llmPort: llmPort,
        normalizationService: normalizationService,
      ),
      llmPort: llmPort,
    );
  });

  group('ClinicalProcessingOrchestrator', () {
    test('processes VOCAB_ASSIST mode successfully', () async {
      final request = ClinicalProcessingRequest(
        inputText:
            'patient has blood pressure of 140 / 90 and heart rate 88 beats per minute',
        processingMode: ProcessingMode.vocabAssist,
      );

      final response = await orchestrator.process(request);

      expect(response.processedText, isNotEmpty);
      expect(response.processingMode, equals(ProcessingMode.vocabAssist));
      expect(response.generatedAt, isNotEmpty);
    });

    test('processes CLEAN_TRANSCRIPT mode successfully', () async {
      final request = ClinicalProcessingRequest(
        inputText: 'Doctor:  Hello   patient.\n\nPatient:   I have pain.',
        processingMode: ProcessingMode.cleanTranscript,
      );

      final response = await orchestrator.process(request);

      expect(response.processedText, isNotEmpty);
      expect(
        response.processingMode,
        equals(ProcessingMode.cleanTranscript),
      );
      expect(response.generatedAt, isNotEmpty);
    });

    test('rejects empty input', () async {
      final request = ClinicalProcessingRequest(
        inputText: '',
        processingMode: ProcessingMode.vocabAssist,
      );

      expect(
        () => orchestrator.process(request),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects unsupported mode', () async {
      final request = ClinicalProcessingRequest(
        inputText: 'Some clinical text.',
        processingMode: ProcessingMode.summarize,
      );

      expect(
        () => orchestrator.process(request),
        throwsA(isA<ValidationException>()),
      );
    });

    test('includes metadata in response', () async {
      final request = ClinicalProcessingRequest(
        inputText: 'Patient has headache.',
        processingMode: ProcessingMode.vocabAssist,
        consultationId: 'C-123',
      );

      final response = await orchestrator.process(request);

      expect(response.metadata['consultationId'], equals('C-123'));
    });

    test('CLEAN_TRANSCRIPT response includes speaker label metadata',
        () async {
      final request = ClinicalProcessingRequest(
        inputText: 'Doctor: Hello\nPatient: Hi',
        processingMode: ProcessingMode.cleanTranscript,
      );

      final response = await orchestrator.process(request);

      expect(response.metadata['hasSpeakerLabels'], isTrue);
    });

    test('response generatedAt is valid ISO-8601', () async {
      final request = ClinicalProcessingRequest(
        inputText: 'Patient has headache.',
        processingMode: ProcessingMode.vocabAssist,
      );

      final response = await orchestrator.process(request);

      // Should parse without error
      final parsed = DateTime.parse(response.generatedAt);
      expect(parsed.isUtc, isTrue);
    });
  });
}
