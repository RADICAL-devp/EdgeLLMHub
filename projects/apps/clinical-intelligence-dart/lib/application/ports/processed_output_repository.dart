import 'package:shared_models/shared_models.dart';

/// Record representing a processed output for querying.
class ProcessedOutputRecord {
  ProcessedOutputRecord({
    required this.id,
    required this.consultationId,
    required this.processingMode,
    required this.source,
    required this.inputText,
    required this.processedText,
    required this.warnings,
    required this.generatedAt,
    required this.metadata,
  });

  final String id;
  final String? consultationId;
  final String processingMode;
  final String? source;
  final String inputText;
  final String processedText;
  final List<String> warnings;
  final DateTime generatedAt;
  final Map<String, dynamic> metadata;
}

/// Port for persisting processed output from clinical text processing.
abstract class ProcessedOutputRepository {
  Future<void> save({
    required String id,
    required String? consultationId,
    required String processingMode,
    required String? source,
    required String inputText,
    required String processedText,
    required List<String> warnings,
    required DateTime generatedAt,
    required Map<String, dynamic> metadata,
  });
  Future<ProcessedOutputRecord?> findById(String id);
  Future<List<ProcessedOutputRecord>> findByConsultationId(
    String consultationId,
  );
}
