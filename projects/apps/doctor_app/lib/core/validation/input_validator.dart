import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Input validator for text sent to LLM prompts.
///
/// Provides three layers of defense:
///   1. **Length limits** — reject excessively long inputs
///   2. **Charset sanitization** — strip control characters
///   3. **Prompt-injection heuristics** — detect known attack patterns
///
/// Tuned for clinical text to minimize false positives on medical
/// terminology and abbreviations.
class InputValidator {
  /// Maximum allowed input length in characters.
  final int maxLength;

  const InputValidator({
    this.maxLength = 50000,
  });

  /// Validate and sanitize input before sending to an LLM.
  ///
  /// Returns the sanitized input if valid.
  /// Throws [ValidationException] if validation fails.
  String validate(String input) {
    if (input.trim().isEmpty) {
      throw const ValidationException(
        'Input cannot be empty',
        reason: ValidationFailureReason.emptyInput,
      );
    }

    if (input.length > maxLength) {
      throw ValidationException(
        'Input exceeds maximum length of $maxLength characters '
        '(received ${input.length})',
        reason: ValidationFailureReason.tooLong,
      );
    }

    // Sanitize control characters (keep \n, \t, \r)
    final sanitized = _sanitizeCharset(input);

    // Check for prompt injection patterns
    _checkPromptInjection(sanitized);

    return sanitized;
  }

  /// Strip control characters except whitespace (\n, \t, \r).
  String _sanitizeCharset(String input) {
    final buffer = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      if (codeUnit == 0x0A || // \n
          codeUnit == 0x0D || // \r
          codeUnit == 0x09 || // \t
          codeUnit >= 0x20) {
        // Printable or allowed whitespace
        buffer.writeCharCode(codeUnit);
      }
      // Silently drop other control characters (0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F)
    }
    return buffer.toString();
  }

  /// Detect known prompt-injection patterns.
  ///
  /// Uses case-insensitive matching. Designed to have low false-positive
  /// rates on clinical text — medical abbreviations like "PRN", "BP",
  /// "system review" are explicitly excluded.
  void _checkPromptInjection(String input) {
    final lower = input.toLowerCase();

    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(lower)) {
        throw ValidationException(
          'Input contains a potentially unsafe pattern that may '
          'interfere with AI processing. Please review and resubmit.',
          reason: ValidationFailureReason.promptInjection,
        );
      }
    }
  }

  /// Known prompt-injection patterns.
  ///
  /// Each regex is designed to avoid false positives on clinical text:
  ///   - "system review" is common in medicine → "system:" requires a colon
  ///   - "ignore" is common → "ignore previous/above/all instructions" is specific
  static final _injectionPatterns = [
    // Role-switching attempts
    RegExp(r'(?:^|\n)\s*system\s*:', multiLine: true),
    RegExp(r'(?:^|\n)\s*assistant\s*:', multiLine: true),
    RegExp(r'(?:^|\n)\s*user\s*:', multiLine: true),

    // Instruction override attempts
    RegExp(r'ignore\s+(?:all\s+)?(?:previous|above|prior)\s+instructions'),
    RegExp(r'disregard\s+(?:all\s+)?(?:previous|above|prior)\s+instructions'),
    RegExp(r'forget\s+(?:all\s+)?(?:previous|above|prior)\s+instructions'),
    RegExp(r'override\s+(?:all\s+)?(?:previous|above|prior)\s+instructions'),

    // Chat ML / special token injection
    RegExp(r'<\|(?:im_start|im_end|system|user|assistant|endoftext)\|>'),
    RegExp(r'\[inst\]|\[/inst\]'),
    RegExp(r'<<sys>>|<</sys>>'),

    // Jailbreak patterns
    RegExp(r'(?:do\s+)?anything\s+now\s+(?:mode|dan)'),
    RegExp(r'pretend\s+(?:you\s+are|to\s+be)\s+(?:a|an)\s+(?:un|evil|malicious)'),
    RegExp(r'act\s+as\s+(?:if|though)\s+(?:you\s+have\s+)?no\s+(?:rules|limits|restrictions)'),
  ];
}
