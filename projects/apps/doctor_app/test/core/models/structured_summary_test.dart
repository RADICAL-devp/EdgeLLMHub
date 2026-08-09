import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredSummary', () {
    test('isComplete is true when all 7 fields are present', () {
      final summary = StructuredSummary(
        complaint: 'Cough',
        pastHistory: 'None',
        vitals: 'Normal',
        physicalExamination: 'Clear',
        investigationOrdered: 'Chest X-ray',
        diagnosis: 'Bronchitis',
        advice: 'Rest',
      );
      expect(summary.isComplete, isTrue);
    });

    test('isComplete is false when any field is missing', () {
      final summary = StructuredSummary(
        complaint: 'Cough',
        pastHistory: 'None',
        vitals: 'Normal',
        physicalExamination: 'Clear',
        investigationOrdered: 'Chest X-ray',
        diagnosis: 'Bronchitis',
      );
      expect(summary.isComplete, isFalse);
    });

    test('isComplete treats whitespace-only fields as missing', () {
      final summary = StructuredSummary(
        complaint: 'Cough',
        pastHistory: '  ',
        vitals: 'Normal',
        physicalExamination: 'Clear',
        investigationOrdered: 'Chest X-ray',
        diagnosis: 'Bronchitis',
        advice: 'Rest',
      );
      expect(summary.isComplete, isFalse);
    });

    test('round-trips through JSON', () {
      final original = StructuredSummary(
        complaint: 'Cough',
        pastHistory: 'None',
        vitals: 'Normal',
        physicalExamination: 'Clear',
        investigationOrdered: 'Chest X-ray',
        diagnosis: 'Bronchitis',
        advice: 'Rest',
      );

      final restored = StructuredSummary.fromJson(original.toJson());

      expect(restored.complaint, 'Cough');
      expect(restored.diagnosis, 'Bronchitis');
      expect(restored.advice, 'Rest');
      expect(restored.isComplete, isTrue);
    });

    test('fromJson tolerates missing fields', () {
      final summary =
          StructuredSummary.fromJson(const {'complaint': 'Cough'});
      expect(summary.complaint, 'Cough');
      expect(summary.pastHistory, isNull);
      expect(summary.isComplete, isFalse);
    });
  });
}
