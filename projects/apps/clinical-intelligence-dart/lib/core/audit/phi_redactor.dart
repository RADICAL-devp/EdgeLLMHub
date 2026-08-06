/// PHI detection and redaction for audit logging.
///
/// Detects and redacts Protected Health Information (PHI) from strings
/// before they are logged, following HIPAA Safe Harbor guidelines.
class PhiRedactor {
  PhiRedactor({this.customPatterns = const []});

  /// Additional custom regex patterns for PHI detection.
  final List<RegExp> customPatterns;

  /// Redact PHI from the input string.
  String redact(String input) {
    if (input.isEmpty) return input;

    var result = input;

    // Apply built-in patterns
    for (final pattern in _builtInPatterns) {
      result = result.replaceAllMapped(pattern, _redactMatch);
    }

    // Apply custom patterns
    for (final pattern in customPatterns) {
      result = result.replaceAllMapped(pattern, _redactMatch);
    }

    return result;
  }

  /// Redact PHI from a JSON-serializable object.
  dynamic redactJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return redact(value);
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, redactJson(v)));
    }
    if (value is List) {
      return value.map(redactJson).toList();
    }
    return value;
  }

  static String _redactMatch(RegExpMatch match) {
    final matched = match.group(0)!;
    // Preserve first and last char for context, redact middle
    if (matched.length <= 4) return '[REDACTED]';
    return '${matched[0]}${'*' * (matched.length - 2)}${matched[matched.length - 1]}';
  }

  /// Built-in PHI detection patterns (HIPAA Safe Harbor identifiers).
  static final List<RegExp> _builtInPatterns = [
    // SSN: XXX-XX-XXXX or XXXXXXXXX
    RegExp(r'\b\d{3}-?\d{2}-?\d{4}\b'),

    // Phone numbers: (XXX) XXX-XXXX, XXX-XXX-XXXX, XXX.XXX.XXXX, etc.
    RegExp(r'\b\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),

    // Email addresses
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),

    // Dates (MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD) - but be careful not to redact timestamps
    // RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{4}\b'),

    // Medical Record Numbers (alphanumeric, 6-12 chars)
    RegExp(r'\b(?:MRN|mrn|Medical Record)[:\s#]*([A-Za-z0-9]{6,12})\b', caseSensitive: false),

    // Patient names with titles (Dr., Mr., Mrs., Ms., etc.)
    RegExp(r'\b(?:Dr|Mr|Mrs|Ms|Prof)\.\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b'),

    // Addresses (basic street address pattern)
    RegExp(r'\b\d+\s+[A-Za-z0-9\s,]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl)\b', caseSensitive: false),

    // Zip codes (5 or 9 digits)
    RegExp(r'\b\d{5}(?:-\d{4})?\b'),

    // IP addresses
    RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),

    // URLs with potential PHI in path
    RegExp(r'https?://[^\s]+'),

    // Credit card numbers (basic Luhn-validatable pattern)
    RegExp(r'\b(?:\d{4}[-\s]?){3}\d{4}\b'),

    // Date of Birth patterns (DOB: MM/DD/YYYY)
    RegExp(r'\b(?:DOB|dob|Date of Birth)[:\s]*\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b', caseSensitive: false),
  ];
}
