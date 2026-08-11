import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProcessingMode', () {
    test('tryParse handles canonical snake-case names', () {
      expect(ProcessingMode.tryParse('VOCAB_ASSIST'),
          ProcessingMode.vocabAssist);
      expect(ProcessingMode.tryParse('CLEAN_TRANSCRIPT'),
          ProcessingMode.cleanTranscript);
      expect(ProcessingMode.tryParse('SUMMARIZE'), ProcessingMode.summarize);
      expect(ProcessingMode.tryParse('GENERATE_DOCTOR_NOTE'),
          ProcessingMode.generateDoctorNote);
      expect(ProcessingMode.tryParse('FULL_BUNDLE'), ProcessingMode.fullBundle);
    });

    test('tryParse is case-insensitive and ignores dashes', () {
      expect(ProcessingMode.tryParse('vocab-assist'),
          ProcessingMode.vocabAssist);
      expect(ProcessingMode.tryParse('generateDoctorNote'),
          ProcessingMode.generateDoctorNote);
    });

    test('tryParse returns null for unknown values', () {
      expect(ProcessingMode.tryParse('TRANSLATE'), isNull);
      expect(ProcessingMode.tryParse(null), isNull);
    });

    test('toJson produces the wire format', () {
      expect(ProcessingMode.vocabAssist.toJson(), 'VOCAB_ASSIST');
      expect(ProcessingMode.fullBundle.toJson(), 'FULL_BUNDLE');
    });

    test('round-trips through tryParse', () {
      for (final mode in ProcessingMode.values) {
        expect(ProcessingMode.tryParse(mode.toJson()), mode);
      }
    });
  });
}
