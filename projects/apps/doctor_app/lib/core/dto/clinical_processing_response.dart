import 'package:doctor_app/core/models/processing_mode.dart';

/// Response DTO for the generic clinical text processing endpoint.
class ClinicalProcessingResponse {
  ClinicalProcessingResponse({
    required this.processedText,
    required this.processingMode,
    this.warnings = const [],
    required this.generatedAt,
    this.metadata = const {},
  });

  final String processedText;
  final ProcessingMode processingMode;
  final List<String> warnings;
  final String generatedAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'processedText': processedText,
        'processingMode': processingMode.toJson(),
        'warnings': warnings,
        'generatedAt': generatedAt,
        'metadata': metadata,
      };
}
