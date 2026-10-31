import 'dart:convert';

import 'package:shared_models/shared_models.dart';

import '../exceptions/app_exceptions.dart';

/// Parses model output into the six-section contract.
///
/// Small on-device models occasionally wrap JSON in prose or markdown fences,
/// or fall back to headings. The parser accepts all three without ever
/// inventing clinical content.
class ClinicalResponseParser {
  const ClinicalResponseParser();

  StructuredNoteSections parseStructuredSections(String raw) {
    final text = _stripFences(raw).trim();
    if (text.isEmpty) {
      throw const LlmParseException(
        'The on-device model returned an empty note. Try again.',
      );
    }

    final jsonText = _extractJsonObject(text);
    if (jsonText != null) {
      try {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map<String, dynamic>) {
          final map = _canonicalizeKeys(_unwrapSections(decoded));
          final parsed = StructuredNoteSections.fromJson(map);
          final cleaned = _clean(parsed);
          if (!cleaned.isEmpty) return cleaned;
        }
      } catch (_) {
        // Fall through to heading parsing.
      }
    }

    final fromHeadings = _parseHeadings(text);
    final cleaned = _clean(fromHeadings);
    if (!cleaned.isEmpty) return cleaned;

    throw const LlmParseException(
      'The model response could not be read as a structured note. Try again, '
      'or edit the sections manually.',
    );
  }

  String parseCleanedTranscript(String raw) {
    var text = _stripFences(raw).trim();
    text = text
        .replaceAll(RegExp(r'<\|(?:im_start|im_end|endoftext)\|>'), '')
        .replaceAll(
          RegExp(
            r'^\s*(?:here is|this is)\s+(?:the\s+)?cleaned\s+transcript\s*[:\-]\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*cleaned\s+transcript\s*[:\-]\s*', caseSensitive: false),
          '',
        )
        .trim();
    if (text.length >= 2 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith('“') && text.endsWith('”')))) {
      text = text.substring(1, text.length - 1).trim();
    }
    if (text.isEmpty) {
      throw const LlmParseException(
        'The model returned an empty transcript. The original text was kept.',
      );
    }
    return text;
  }

  static String _stripFences(String text) {
    return text
        .replaceAll(RegExp(r'^\s*```[a-zA-Z0-9_-]*\s*'), '')
        .replaceAll(RegExp(r'\s*```\s*$'), '')
        .replaceAll(RegExp(r'^\s*```[a-zA-Z0-9_-]*\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*```\s*$', multiLine: true), '')
        .trim();
  }

  static Map<String, dynamic> _unwrapSections(Map<String, dynamic> map) {
    final nested = map['sections'] ?? map['note'] ?? map['structuredNote'];
    if (nested is Map<String, dynamic>) return nested;
    return map;
  }

  /// Returns the first balanced JSON object, ignoring braces inside strings.
  static String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    final end = text.lastIndexOf('}');
    if (end > start) return text.substring(start, end + 1);
    return null;
  }

  static StructuredNoteSections _parseHeadings(String text) {
    final heading = RegExp(
      r'^\s*(?:#{1,6}\s*)?(?:\d+[.)]\s*)?\**\s*'
      r'(chief complaint|history of present illness|hpi|examination|'
      r'physical examination|assessment|treatment plan|plan|follow[- ]?up)'
      r'\s*\**\s*(?::|[-–—])?\s*\**\s*(.*)$',
      caseSensitive: false,
    );

    String? currentKey;
    final values = <String, StringBuffer>{};
    final lines = text.split('\n');
    var foundHeading = false;

    for (final line in lines) {
      final match = heading.firstMatch(line);
      if (match != null) {
        foundHeading = true;
        currentKey = _keyFor(match.group(1)!);
        values.putIfAbsent(currentKey, () => StringBuffer());
        final inline = match.group(2)?.trim() ?? '';
        if (inline.isNotEmpty) {
          values[currentKey]!.writeln(inline);
        }
        continue;
      }
      if (currentKey != null) {
        values[currentKey]!.writeln(line);
      }
    }

    if (!foundHeading) return StructuredNoteSections();

    String? read(String key) {
      final buffer = values[key];
      if (buffer == null) return null;
      final value = buffer.toString().trim();
      return value.isEmpty ? null : value;
    }

    return StructuredNoteSections(
      chiefComplaint: read('chief'),
      historyOfPresentIllness: read('hpi'),
      examination: read('exam'),
      assessment: read('assessment'),
      treatmentPlan: read('plan'),
      followUp: read('followUp'),
    );
  }

  /// Accepts camelCase, snake_case, Title Case, and common aliases.
  static Map<String, dynamic> _canonicalizeKeys(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final value = _coerceValue(entry.value);
      switch (key) {
        case 'chiefcomplaint':
        case 'cc':
          out['chiefComplaint'] = value;
          break;
        case 'historyofpresentillness':
        case 'hpi':
          out['historyOfPresentIllness'] = value;
          break;
        case 'examination':
        case 'physicalexamination':
        case 'exam':
          out['examination'] = value;
          break;
        case 'assessment':
        case 'diagnosis':
          out['assessment'] = value;
          break;
        case 'treatmentplan':
        case 'plan':
          out['treatmentPlan'] = value;
          break;
        case 'followup':
          out['followUp'] = value;
          break;
        default:
          out[entry.key] = value;
      }
    }
    return out;
  }

  static Object? _coerceValue(Object? value) {
    if (value is List) {
      final parts = value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty);
      return parts.isEmpty ? null : parts.join('; ');
    }
    return value;
  }

  static String _keyFor(String label) {
    final normalized = label
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.startsWith('chief')) return 'chief';
    if (normalized == 'hpi' || normalized.startsWith('history')) return 'hpi';
    if (normalized.startsWith('physical') || normalized.startsWith('exam')) {
      return 'exam';
    }
    if (normalized.startsWith('assessment')) return 'assessment';
    if (normalized.startsWith('follow')) return 'followUp';
    return 'plan';
  }

  static StructuredNoteSections _clean(StructuredNoteSections sections) {
    return StructuredNoteSections(
      chiefComplaint: _cleanValue(sections.chiefComplaint),
      historyOfPresentIllness: _cleanValue(sections.historyOfPresentIllness),
      examination: _cleanValue(sections.examination),
      assessment: _cleanValue(sections.assessment),
      treatmentPlan: _cleanValue(sections.treatmentPlan),
      followUp: _cleanValue(sections.followUp),
    );
  }

  static String? _cleanValue(String? raw) {
    if (raw == null) return null;
    var value = raw
        .replaceAll(RegExp(r'^\s*[-*•]\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '')
        .trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith('“') && value.endsWith('”')))) {
      value = value.substring(1, value.length - 1).trim();
    }
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_isNone(line))
        .toList();
    value = lines.join('\n').trim();
    if (value.isEmpty || _isNone(value)) return null;
    return value;
  }

  static bool _isNone(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[.!]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized == 'none' ||
        normalized == 'none stated' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == 'not documented' ||
        normalized == 'not mentioned' ||
        normalized == 'not stated' ||
        normalized == 'not discussed' ||
        normalized == 'no information' ||
        normalized == 'null';
  }
}
