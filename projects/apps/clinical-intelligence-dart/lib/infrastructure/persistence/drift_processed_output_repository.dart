import 'package:drift/drift.dart';
import 'package:clinical_intelligence_dart/application/ports/processed_output_repository.dart';
import 'clinical_database.dart';

class DriftProcessedOutputRepository implements ProcessedOutputRepository {
  final ClinicalDatabase _db;

  DriftProcessedOutputRepository(this._db);

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
    await _db.into(_db.processedOutputs).insertOnConflictUpdate(
      ProcessedOutputsCompanion.insert(
        id: id,
        consultationId: Value(consultationId),
        processingMode: processingMode,
        source: Value(source),
        inputText: inputText,
        processedText: processedText,
        warnings: warnings,
        generatedAt: generatedAt,
        metadata: metadata,
      ),
    );
  }

  @override
  Future<ProcessedOutputRecord?> findById(String id) async {
    final row = await (_db.select(_db.processedOutputs)
          ..where((p) => p.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toRecord(row) : null;
  }

  @override
  Future<List<ProcessedOutputRecord>> findByConsultationId(String consultationId) async {
    final rows = await (_db.select(_db.processedOutputs)
          ..where((p) => p.consultationId.equals(consultationId))
          ..orderBy([(p) => OrderingTerm.desc(p.generatedAt)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  ProcessedOutputRecord _toRecord(ProcessedOutput row) {
    return ProcessedOutputRecord(
      id: row.id,
      consultationId: row.consultationId,
      processingMode: row.processingMode,
      source: row.source,
      inputText: row.inputText,
      processedText: row.processedText,
      warnings: row.warnings,
      generatedAt: row.generatedAt,
      metadata: row.metadata,
    );
  }
}
