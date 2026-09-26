import 'dart:convert';

import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'prompts/clinical_prompts.dart';

/// Shared JSON-parsing logic for native LLM adapters.
///
/// Both Android (MLC) and iOS (MLC) adapters parse the same structured
/// JSON from their respective models, so this mixin avoids duplication.
mixin NativeLlmParsing {
  /// Build a prompt string for the given processing mode.
  String buildPrompt(String input, ProcessingMode mode) {
    final cleanInput = ClinicalPrompts.sanitize(input);
    return switch (mode) {
      ProcessingMode.vocabAssist =>
        '${ClinicalPrompts.vocabAssist}\n$cleanInput',
      ProcessingMode.cleanTranscript =>
        '${ClinicalPrompts.cleanTranscript}\n$cleanInput',
      ProcessingMode.summarize =>
        '${ClinicalPrompts.structuredSummary}\n$cleanInput',
      ProcessingMode.generateDoctorNote =>
        '${ClinicalPrompts.doctorNote}\n$cleanInput',
      _ => cleanInput,
    };
  }

  /// Parse LLM response as a [StructuredSummary] JSON.
  ///
  /// Tolerates markdown code fences and preamble text before the JSON.
  StructuredSummary parseStructuredSummary(String response) {
    var cleaned = response.trim();

    // Strip markdown code fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }

    // Find JSON block if the model produced preamble text
    final startIndex = cleaned.indexOf('{');
    final endIndex = cleaned.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      cleaned = cleaned.substring(startIndex, endIndex + 1);
    }

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return StructuredSummary.fromJson(json);
    } catch (error) {
      if (cleaned == '[DONE]' || cleaned.isEmpty) {
        throw LlmParseException(
          'The on-device model failed to generate a response (empty or [DONE] sentinel received).',
          cause: error,
          provider: LlmProvider.mlc,
        );
      }
      throw LlmParseException(
        'The on-device model returned an invalid structured summary.',
        cause: error,
        provider: LlmProvider.mlc,
      );
    }
  }

/// Cleans up raw LLM output by removing echoed prompts or ChatML tags.
  ///
  /// Some local model configurations (like Qwen/SmolLM without strict chat templates)
  /// will echo the user's prompt or leak ChatML tags into the output buffer.
  /// This robustly strips them before returning the result to the UI.
  String stripPromptEcho(String response, String prompt) {
    var cleaned = response;

    // 1. Strip common ChatML/assistant tag patterns that may leak from the engine
    const chatMLPatterns = [
      '<|assistant|>',
      '<|im_start|>assistant',
      'assistant\n',
      'assistant:',
      '### Assistant:',
      'Assistant:',
    ];
    for (final pattern in chatMLPatterns) {
      final tagIndex = cleaned.lastIndexOf(pattern);
      if (tagIndex != -1) {
        cleaned = cleaned.substring(tagIndex + pattern.length);
        break;
      }
    }

    // 2. Try exact prompt match (most reliable when it works)
    var promptIndex = cleaned.indexOf(prompt);
    if (promptIndex != -1) {
      cleaned = cleaned.substring(promptIndex + prompt.length);
    } else {
      // 3. Try with normalized whitespace (collapse multiple spaces/newlines)
      final normalizedPrompt = prompt.replaceAll(RegExp(r'\s+'), ' ');
      final normalizedResponse = cleaned.replaceAll(RegExp(r'\s+'), ' ');
      promptIndex = normalizedResponse.indexOf(normalizedPrompt);
      if (promptIndex != -1) {
        // Approximate: find the end of the matched region in original response
        // Use the suffix of the prompt for precise cutting
        final suffix = prompt.length > 60 ? prompt.substring(prompt.length - 60) : prompt;
        final suffixIndex = cleaned.indexOf(suffix);
        if (suffixIndex != -1) {
          cleaned = cleaned.substring(suffixIndex + suffix.length);
        }
      } else {
        // 4. Fallback: extract input portion from prompt (text after last newline)
        // and find its LAST occurrence in the response (end of echoed prompt)
        final lastNewlineIndex = prompt.lastIndexOf('\n');
        if (lastNewlineIndex != -1 && lastNewlineIndex < prompt.length - 1) {
          final inputPart = prompt.substring(lastNewlineIndex + 1);
          if (inputPart.length > 10) {
            // Only use substantial input parts to avoid false matches
            final lastInputIndex = cleaned.lastIndexOf(inputPart);
            if (lastInputIndex != -1) {
              cleaned = cleaned.substring(lastInputIndex + inputPart.length);
            }
          }
        }
      }
    }

    // 5. Remove instruction-like patterns that LLM may generate (paraphrased rules)
    final instructionPatterns = [
      // "The rule of thumb for..." patterns - match multi-word phrases
      RegExp(r'The rule of thumb for.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'Rules?[:\n]\s*.*?(?=\n\n|\n|$)', caseSensitive: false),
      // "The rule of thumb" without "for"
      RegExp(r'The rule of thumb.*?(?=\n\n|\n|$)', caseSensitive: false),
      // Common instruction starters
      RegExp(r'(?:Follow|Remember|Ensure|Always|Never|Do not|Must|Should)\s+.*?[.!]\s*', caseSensitive: false),
      RegExp(r'DO NOT OUTPUT.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'INSTRUCTIONS?\(.*?\)\s*.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'RETURN ONLY.*?(?=\n\n|\n|$)', caseSensitive: false),
      // Phrase-based patterns for generated instructions
      RegExp(r'rule of thumb.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'prioritize.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'ensure that.*?(?=\n\n|\n|$)', caseSensitive: false),
      // Regex to catch bullet points or numbered lists of rules
      RegExp(r'\d+\.\s+.*?(?=\n\n|\n|$)', caseSensitive: false),
      RegExp(r'[-*•]\s+.*?(?=\n\n|\n|$)', caseSensitive: false),
      // Catch any line starting with capital letter that looks like an instruction
      RegExp(r'^[A-Z][a-z]+ (is|are|should|must|for|to)\s+.*?(?=\n|$)', caseSensitive: false, multiLine: true),
    ];
    
    for (final pattern in instructionPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    
    // Remove multiple consecutive newlines created by pattern removal
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 6. Final cleanup: remove any residual ChatML tags and trim
    cleaned = cleaned
        .replaceAll('<|assistant|>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|im_start|>', '')
        .replaceAll(RegExp(r'assistant\s*[\n:]'), '')
        .trim();

    return cleaned;
  }

  /// Extracts only the content from LLM response, removing any instruction leakage.
  /// Used as a final safety net for text generation modes.
  String validateAndCleanResponse(String response, ProcessingMode mode) {
    // For text generation modes, be aggressive about removing non-content
    if (mode == ProcessingMode.cleanTranscript ||
        mode == ProcessingMode.vocabAssist ||
        mode == ProcessingMode.generateDoctorNote) {
      
      // If response looks like it has content followed by instructions,
      // extract only the content portion
      final contentOnly = _extractContentOnly(response);
      if (contentOnly.isNotEmpty && contentOnly != response) {
        return contentOnly;
      }
    }
    return response;
  }

  /// Extracts only the content-looking text from a response that may contain
  /// both content and instruction leakage.
  String _extractContentOnly(String text) {
    final lines = text.split('\n');
    
    // Find the first line that looks like actual content (not an instruction)
    int? contentStartIndex;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Skip lines that look like instructions
      if (_isInstructionLine(line)) {
        // If we've already found content and now see instructions, stop here
        if (contentStartIndex != null) {
          break;
        }
        continue;
      }
      
      // This looks like content
      contentStartIndex = i;
      break;
    }
    
    // If we found a content start, return everything from there
    if (contentStartIndex != null) {
      final result = lines.sublist(contentStartIndex).join('\n').trim();
      // Remove any trailing instruction-like lines
      return _removeTrailingInstructions(result);
    }
    
    return text;
  }

  /// Checks if a line looks like an instruction rather than content.
  bool _isInstructionLine(String line) {
    final lowerLine = line.toLowerCase();
    
    // Common instruction patterns
    final instructionPatterns = [
      RegExp(r'^the rule of thumb for'),
      RegExp(r'^rules?[:\n]'),
      RegExp(r'^follow'),
      RegExp(r'^remember'),
      RegExp(r'^ensure'),
      RegExp(r'^always'),
      RegExp(r'^never'),
      RegExp(r'^do not'),
      RegExp(r'^must'),
      RegExp(r'^instructions?'),
      RegExp(r'^return only'),
      RegExp(r'^(?:do not output|internal use only)'),
      RegExp(r'^\d+\.\s'),  // Numbered list items
      RegExp(r'^[-*•]\s'),  // Bullet points
    ];
    
    for (final pattern in instructionPatterns) {
      if (pattern.hasMatch(lowerLine)) {
        return true;
      }
    }
    
    // Lines that are too generic but in instruction style
    if (line.length > 50 && 
        (line.contains('should') || line.contains('must')) &&
        line.contains(':')) {
      return true;
    }
    
    return false;
  }

  /// Removes trailing instruction lines from content.
  String _removeTrailingInstructions(String text) {
    final lines = text.split('\n');
    int lastContentIndex = lines.length - 1;
    
    // Find the last line that is actual content
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        lastContentIndex = i - 1;
        continue;
      }
      
      if (!_isInstructionLine(line)) {
        lastContentIndex = i;
        break;
      }
      
      lastContentIndex = i - 1;
    }
    
    if (lastContentIndex >= 0) {
      return lines.sublist(0, lastContentIndex + 1).join('\n').trim();
    }
    
    return text;
  }
}
