import '../ports/llm_port.dart';
import '../../core/models/processing_mode.dart';
import 'transcript_normalization_service.dart';

/// CLEAN_TRANSCRIPT processing service.
///
/// Transcript cleanup:
///   - Normalize whitespace
///   - Improve readability
///   - Preserve original meaning and ordering
///   - Preserve speaker labels (Doctor:, Patient:) when present
///   - Do NOT summarize
///   - Do NOT add new medical facts
class TranscriptCleanupService {
  TranscriptCleanupService({
    required this.llmPort,
    required this.normalizationService,
  });

  final LlmPort llmPort;
  final TranscriptNormalizationService normalizationService;

  /// Process text with CLEAN_TRANSCRIPT mode.
  ///
  /// Steps:
  ///   1. Normalize whitespace and line endings
  ///   2. Detect and preserve speaker labels
  ///   3. Send to LLM with clean-transcript prompt
  ///   4. Verify speaker labels are preserved in output
  Future<TranscriptCleanupResult> process(String inputText) async {
    // 1. Normalize
    final normalized = normalizationService.normalize(inputText);

    if (normalized.isEmpty) {
      return TranscriptCleanupResult(
        processedText: '',
        warnings: ['Input text was empty after normalization.'],
      );
    }

    // 2. Detect speaker labels before processing
    final hasSpeakerLabels =
        normalizationService.containsSpeakerLabels(normalized);
    final originalLabels = hasSpeakerLabels
        ? normalizationService.extractSpeakerLabels(normalized)
        : <String>[];

    // 3. Process via LLM
    final processed = await llmPort.processText(
      normalized,
      ProcessingMode.cleanTranscript,
    );

    // 4. Verify speaker labels are preserved
    final warnings = <String>[];
    if (hasSpeakerLabels) {
      for (final label in originalLabels) {
        if (!processed.contains(label)) {
          warnings.add(
            'Speaker label "$label" may have been altered during cleanup.',
          );
        }
      }
    }

    return TranscriptCleanupResult(
      processedText: processed,
      hasSpeakerLabels: hasSpeakerLabels,
      detectedSpeakers: originalLabels,
      warnings: warnings,
    );
  }
}

class TranscriptCleanupResult {
  TranscriptCleanupResult({
    required this.processedText,
    this.hasSpeakerLabels = false,
    this.detectedSpeakers = const [],
    this.warnings = const [],
  });

  final String processedText;
  final bool hasSpeakerLabels;
  final List<String> detectedSpeakers;
  final List<String> warnings;
}
