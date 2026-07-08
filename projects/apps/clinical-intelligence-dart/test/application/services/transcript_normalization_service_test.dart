import 'package:clinical_intelligence_dart/application/services/transcript_normalization_service.dart';
import 'package:test/test.dart';

void main() {
  late TranscriptNormalizationService service;

  setUp(() {
    service = TranscriptNormalizationService();
  });

  group('TranscriptNormalizationService', () {
    test('normalizes multiple spaces to single space', () {
      final result = service.normalize('Patient   has    headache');
      expect(result, equals('Patient has headache'));
    });

    test('normalizes mixed line endings', () {
      final result = service.normalize('Line 1\r\nLine 2\rLine 3\nLine 4');
      expect(result, contains('Line 1'));
      expect(result, contains('Line 2'));
      expect(result, contains('Line 3'));
      expect(result, contains('Line 4'));
    });

    test('preserves order of content', () {
      const input = 'First point.\nSecond point.\nThird point.';
      final result = service.normalize(input);
      final firstIdx = result.indexOf('First');
      final secondIdx = result.indexOf('Second');
      final thirdIdx = result.indexOf('Third');
      expect(firstIdx, lessThan(secondIdx));
      expect(secondIdx, lessThan(thirdIdx));
    });

    test('preserves speaker labels', () {
      const input = 'Doctor: How are you?\nPatient: I have a headache.';
      final result = service.normalize(input);
      expect(result, contains('Doctor:'));
      expect(result, contains('Patient:'));
    });

    test('preserves Doctor label with name', () {
      const input = 'Dr. Smith: Please describe your symptoms.';
      final result = service.normalize(input);
      expect(result, contains('Dr. Smith:'));
    });

    test('collapses excessive blank lines to single blank line', () {
      const input = 'Line 1\n\n\n\n\nLine 2';
      final result = service.normalize(input);
      // Should have at most one blank line between content
      expect(result, equals('Line 1\n\nLine 2'));
    });

    test('trims leading and trailing whitespace', () {
      const input = '  \n  Hello world  \n  ';
      final result = service.normalize(input);
      expect(result, equals('Hello world'));
    });

    test('returns empty string for blank input', () {
      expect(service.normalize(''), equals(''));
      expect(service.normalize('   \n\t  '), equals(''));
    });

    test('detects speaker labels correctly', () {
      expect(
        service.containsSpeakerLabels('Doctor: Hello'),
        isTrue,
      );
      expect(
        service.containsSpeakerLabels('Patient: Hi'),
        isTrue,
      );
      expect(
        service.containsSpeakerLabels('No speaker here'),
        isFalse,
      );
    });

    test('extracts speaker labels', () {
      const input = 'Doctor: Hello\nPatient: Hi\nDoctor: How are you?';
      final labels = service.extractSpeakerLabels(input);
      expect(labels, containsAll(['Doctor', 'Patient']));
    });
  });
}
