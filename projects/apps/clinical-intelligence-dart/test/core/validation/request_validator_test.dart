import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  group('RequestSchemas', () {
    bool validate(Map<String, dynamic> schema, Map<String, dynamic> json) =>
        JsonSchema.create(schema).validate(json).isValid;

    group('clinicalProcess', () {
      test('accepts a valid VOCAB_ASSIST request', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'inputText': 'Patient stable',
            'processingMode': 'VOCAB_ASSIST',
          }),
          isTrue,
        );
      });

      test('accepts optional metadata fields', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'inputText': 'Patient stable',
            'processingMode': 'SUMMARIZE',
            'consultationId': 'c-1',
            'patientId': 'p-1',
            'doctorId': 'd-1',
            'source': 'STT',
          }),
          isTrue,
        );
      });

      test('rejects unknown processing mode', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'inputText': 'Patient stable',
            'processingMode': 'DO_MAGIC',
          }),
          isFalse,
        );
      });

      test('rejects missing inputText', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'processingMode': 'VOCAB_ASSIST',
          }),
          isFalse,
        );
      });

      test('rejects unknown top-level fields', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'inputText': 'Patient stable',
            'processingMode': 'VOCAB_ASSIST',
            'hack': true,
          }),
          isFalse,
        );
      });

      test('rejects whitespace-only inputText', () {
        expect(
          validate(RequestSchemas.clinicalProcess, {
            'inputText': '   ',
            'processingMode': 'VOCAB_ASSIST',
          }),
          isFalse,
        );
      });
    });

    group('structuredSummary', () {
      test('accepts a valid request', () {
        expect(
          validate(RequestSchemas.structuredSummary, {
            'transcriptText': '56yo male with SOB.',
          }),
          isTrue,
        );
      });

      test('rejects a missing transcriptText', () {
        expect(validate(RequestSchemas.structuredSummary, {}), isFalse);
      });

      test('rejects a non-string transcriptText', () {
        expect(
          validate(RequestSchemas.structuredSummary, {
            'transcriptText': 42,
          }),
          isFalse,
        );
      });
    });

    group('contextEnriched', () {
      test('accepts transcriptText without pastContext (auto retrieval)', () {
        expect(
          validate(RequestSchemas.contextEnriched, {
            'transcriptText': 'Patient reports headaches.',
          }),
          isTrue,
        );
      });

      test('accepts transcriptText with pastContext', () {
        expect(
          validate(RequestSchemas.contextEnriched, {
            'transcriptText': 'Patient reports headaches.',
            'pastContext': 'Known migraine history.',
          }),
          isTrue,
        );
      });
    });

    group('notesSync', () {
      test('accepts a minimal valid note', () {
        expect(
          validate(RequestSchemas.notesSync, {
            'noteId': 'n-1',
            'consultationId': 'c-1',
            'createdAt': '2026-08-01T10:00:00.000Z',
            'updatedAt': '2026-08-01T10:00:00.000Z',
          }),
          isTrue,
        );
      });

      test('accepts a full note with extracted fields', () {
        expect(
          validate(RequestSchemas.notesSync, {
            'noteId': 'n-1',
            'consultationId': 'c-1',
            'patientId': 'p-1',
            'doctorId': 'd-1',
            'rawText': 'Patient stable.',
            'status': 'finalized',
            'extractedFields': {
              'symptoms': ['SOB'],
              'duration': '2 weeks',
              'medications': ['metformin'],
              'allergies': <String>[],
              'testsRecommended': ['HbA1c'],
              'followUpActions': ['review in 3 months'],
              'provisionalDiagnosis': 'DM2',
            },
            'createdAt': '2026-08-01T10:00:00.000Z',
            'updatedAt': '2026-08-01T10:00:00.000Z',
          }),
          isTrue,
        );
      });

      test('rejects a note without noteId', () {
        expect(
          validate(RequestSchemas.notesSync, {
            'consultationId': 'c-1',
            'createdAt': '2026-08-01T10:00:00.000Z',
            'updatedAt': '2026-08-01T10:00:00.000Z',
          }),
          isFalse,
        );
      });

      test('rejects non-date createdAt', () {
        expect(
          validate(RequestSchemas.notesSync, {
            'noteId': 'n-1',
            'consultationId': 'c-1',
            'createdAt': 'not-a-date',
            'updatedAt': '2026-08-01T10:00:00.000Z',
          }),
          isFalse,
        );
      });
    });

    group('summaryBundle', () {
      test('accepts a valid generate request', () {
        expect(
          validate(RequestSchemas.summaryBundle, {
            'consultationId': 'c-1',
            'patientId': 'p-1',
            'doctorId': 'd-1',
            'transcriptText': '56yo male with SOB.',
            'consultationMode': 'IN_PERSON',
          }),
          isTrue,
        );
      });

      test('rejects a request without doctorId', () {
        expect(
          validate(RequestSchemas.summaryBundle, {
            'consultationId': 'c-1',
            'patientId': 'p-1',
            'transcriptText': '56yo male with SOB.',
          }),
          isFalse,
        );
      });
    });
  });
}