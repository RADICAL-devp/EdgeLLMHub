import 'package:clinical_intelligence_dart/application/ports/processed_output_repository.dart';

/// In-memory implementation of [ProcessedOutputRepository].
class InMemoryProcessedOutputRepository implements ProcessedOutputRepository {
  final Map<String, ProcessedOutputRecord> _byId = {};
  final Map<String, List<ProcessedOutputRecord>> _byConsultationId = {};

  @override
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
  }) async {
    final record = ProcessedOutputRecord(
      id: id,
      consultationId: consultationId,
      processingMode: processingMode,
      source: source,
      inputText: inputText,
      processedText: processedText,
      warnings: warnings,
      generatedAt: generatedAt,
      metadata: metadata,
    );
    _byId[id] = record;
    if (consultationId != null) {
      _byConsultationId
          .putIfAbsent(consultationId, () => [])
          .add(record);
    }
  }

  @override
  Future<ProcessedOutputRecord?> findById(String id) async {
    return _byId[id];
  }

  @override
  Future<List<ProcessedOutputRecord>> findByConsultationId(
    String consultationId,
  ) async {
    return _byConsultationId[consultationId] ?? [];
  }
}
