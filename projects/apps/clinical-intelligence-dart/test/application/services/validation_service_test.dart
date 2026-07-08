import 'package:clinical_intelligence_dart/api/dto/clinical_processing_request.dart';
import 'package:clinical_intelligence_dart/api/dto/transcript_summary_request.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:clinical_intelligence_dart/core/models/processing_mode.dart';
import 'package:test/test.dart';

void main() {
  late ValidationService validationService;

  setUp(() {
    validationService = ValidationService();
  });

  group('ValidationService - Clinical Processing', () {
    test('rejects empty inputText', () {
      final request = ClinicalProcessingRequest(
        inputText: '',
        processingMode: ProcessingMode.vocabAssist,
      );

      expect(
        () => validationService.validateClinicalProcessingRequest(request),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects whitespace-only inputText', () {
      final request = ClinicalProcessingRequest(
        inputText: '   \n\t  ',
        processingMode: ProcessingMode.vocabAssist,
      );

      expect(
        () => validationService.validateClinicalProcessingRequest(request),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects unsupported processing mode SUMMARIZE', () {
      final request = ClinicalProcessingRequest(
        inputText: 'Patient presents with headache.',
        processingMode: ProcessingMode.summarize,
      );

      expect(
        () => validationService.validateClinicalProcessingRequest(request),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Unsupported processing mode'),
        )),
      );
    });

    test('rejects unsupported processing mode GENERATE_DOCTOR_NOTE', () {
      final request = ClinicalProcessingRequest(
        inputText: 'Patient presents with headache.',
        processingMode: ProcessingMode.generateDoctorNote,
      );

      expect(
        () => validationService.validateClinicalProcessingRequest(request),
        throwsA(isA<ValidationException>()),
      );
    });

    test('accepts valid VOCAB_ASSIST request', () {
      final request = ClinicalProcessingRequest(
        inputText: 'Patient presents with headache.',
        processingMode: ProcessingMode.vocabAssist,
      );

      // Should not throw
      validationService.validateClinicalProcessingRequest(request);
    });

    test('accepts valid CLEAN_TRANSCRIPT request', () {
      final request = ClinicalProcessingRequest(
        inputText: 'Doctor: How are you today?',
        processingMode: ProcessingMode.cleanTranscript,
      );

      // Should not throw
      validationService.validateClinicalProcessingRequest(request);
    });
  });

  group('ValidationService - Payload Size', () {
    test('rejects payload exceeding 10MB', () {
      final largePayload = 'x' * (10 * 1024 * 1024 + 1);

      expect(
        () => validationService.validatePayloadSize(largePayload),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('10MB'),
        )),
      );
    });

    test('accepts payload within size limit', () {
      final normalPayload = 'Patient presents with headache and nausea.';

      // Should not throw
      validationService.validatePayloadSize(normalPayload);
    });
  });

  group('ValidationService - Transcript Summary', () {
    test('rejects empty consultationId', () {
      expect(
        () => validationService.validateTranscriptSummaryRequest(
          consultationId: '',
          patientId: 'P1',
          doctorId: 'D1',
          transcriptText: 'Some text',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects empty transcriptText', () {
      expect(
        () => validationService.validateTranscriptSummaryRequest(
          consultationId: 'C1',
          patientId: 'P1',
          doctorId: 'D1',
          transcriptText: '',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('accepts valid transcript summary request', () {
      // Should not throw
      validationService.validateTranscriptSummaryRequest(
        consultationId: 'C1',
        patientId: 'P1',
        doctorId: 'D1',
        transcriptText: 'Patient presents with headache.',
      );
    });

    test('successfully parses Java ConsultationInput format', () {
      final json = {
        'patientId': 'PAT-2024-0042',
        'doctorId': 'DR-SINGH-001',
        'sleepLabId': 'SL-MUMBAI-003',
        'consultation': {
          'patientId': 'PAT-2024-0042',
          'doctorId': 'DR-SINGH-001',
          'chiefComplaint': 'Excessive daytime sleepiness',
          'vitals': {
            'bp': '142/88 mmHg',
            'hr': '78 bpm'
          }
        }
      };

      final request = TranscriptSummaryRequest.fromJson(json);

      expect(request.patientId, equals('PAT-2024-0042'));
      expect(request.doctorId, equals('DR-SINGH-001'));
      expect(request.sleepLabId, equals('SL-MUMBAI-003'));
      expect(request.transcriptText, contains('Chief Complaint: Excessive daytime sleepiness'));
      expect(request.transcriptText, contains('Vitals: BP: 142/88 mmHg, HR: 78 bpm'));
    });
  });
}
