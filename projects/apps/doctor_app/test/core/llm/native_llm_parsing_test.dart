import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/llm/native_llm_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

class _Parser with NativeLlmParsing {}

void main() {
  group('NativeLlmParsing.parseStructuredSummary', () {
    test('rejects malformed model output', () {
      final parser = _Parser();

      expect(
        () => parser.parseStructuredSummary('not a JSON response'),
        throwsA(isA<LlmParseException>()),
      );
    });
  });
}
