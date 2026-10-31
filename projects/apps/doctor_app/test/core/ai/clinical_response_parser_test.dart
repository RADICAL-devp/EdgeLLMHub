import 'package:doctor_app/core/ai/clinical_response_parser.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ClinicalResponseParser();

  group('ClinicalResponseParser.parseStructuredSections', () {
    test('parses a fenced JSON object with all six sections', () {
      final sections = parser.parseStructuredSections('''
```json
{
  "chiefComplaint": "Chest pain",
  "historyOfPresentIllness": "Started yesterday",
  "examination": "BP 120/80",
  "assessment": "Possible angina",
  "treatmentPlan": "ECG and aspirin",
  "followUp": "Review in two days"
}
```
''');

      expect(sections.chiefComplaint, 'Chest pain');
      expect(sections.historyOfPresentIllness, 'Started yesterday');
      expect(sections.examination, 'BP 120/80');
      expect(sections.assessment, 'Possible angina');
      expect(sections.treatmentPlan, 'ECG and aspirin');
      expect(sections.followUp, 'Review in two days');
      expect(sections.isEmpty, isFalse);
    });

    test('accepts snake_case keys and arrays for list-like values', () {
      final sections = parser.parseStructuredSections('''
Sure, here is the note:
{
  "chief_complaint": "Headache",
  "history_of_present_illness": ["Two days", "Worse at night"],
  "physicalExamination": "No focal deficit",
  "diagnosis": "Migraine",
  "plan": "Hydration",
  "follow_up": null
}
''');

      expect(sections.chiefComplaint, 'Headache');
      expect(sections.historyOfPresentIllness, 'Two days; Worse at night');
      expect(sections.examination, 'No focal deficit');
      expect(sections.assessment, 'Migraine');
      expect(sections.treatmentPlan, 'Hydration');
      expect(sections.followUp, isNull);
    });

    test(
      'converts "None stated" values to null instead of inventing content',
      () {
        final sections = parser.parseStructuredSections('''
{
  "chiefComplaint": "Cough",
  "historyOfPresentIllness": "None stated",
  "examination": "N/A",
  "assessment": "Viral illness",
  "treatmentPlan": "Rest",
  "followUp": "Not documented"
}
''');

        expect(sections.chiefComplaint, 'Cough');
        expect(sections.historyOfPresentIllness, isNull);
        expect(sections.examination, isNull);
        expect(sections.assessment, 'Viral illness');
        expect(sections.treatmentPlan, 'Rest');
        expect(sections.followUp, isNull);
      },
    );

    test('falls back to headings when JSON is unavailable', () {
      final sections = parser.parseStructuredSections('''
Chief complaint: Sore throat
HPI: Three days of pain
Examination: Mild erythema
Assessment: Pharyngitis
Treatment plan: Analgesia
Follow-up: If worse
''');

      expect(sections.chiefComplaint, 'Sore throat');
      expect(sections.historyOfPresentIllness, 'Three days of pain');
      expect(sections.examination, 'Mild erythema');
      expect(sections.assessment, 'Pharyngitis');
      expect(sections.treatmentPlan, 'Analgesia');
      expect(sections.followUp, 'If worse');
    });

    test('uses the balanced object even when prose follows it', () {
      final sections = parser.parseStructuredSections('''
The draft is:
{"chiefComplaint":"Pain","assessment":"Unknown"}
Please review.
''');
      expect(sections.chiefComplaint, 'Pain');
      expect(sections.assessment, 'Unknown');
    });

    test('rejects an empty or unreadable response', () {
      expect(
        () => parser.parseStructuredSections('   '),
        throwsA(isA<LlmParseException>()),
      );
      expect(
        () => parser.parseStructuredSections('I cannot help with that.'),
        throwsA(isA<LlmParseException>()),
      );
    });
  });

  group('ClinicalResponseParser.parseCleanedTranscript', () {
    test('removes fences, labels, and wrapping quotes', () {
      expect(
        parser.parseCleanedTranscript(
          '```text\nCleaned transcript: "The patient has chest pain."\n```',
        ),
        'The patient has chest pain.',
      );
    });

    test('rejects an empty cleanup', () {
      expect(
        () => parser.parseCleanedTranscript('Cleaned transcript:'),
        throwsA(isA<LlmParseException>()),
      );
    });

    test('rejects null-like cleanup placeholders', () {
      for (final response in ['null', 'None of the above', 'N/A']) {
        expect(
          () => parser.parseCleanedTranscript(response),
          throwsA(isA<LlmParseException>()),
        );
      }
    });
  });
}
