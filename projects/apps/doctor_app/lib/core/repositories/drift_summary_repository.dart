import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:doctor_app/core/models/transcript_summary_bundle.dart';
import 'package:doctor_app/core/models/executive_summary.dart';
import 'package:doctor_app/core/models/structured_summary.dart';
import 'package:doctor_app/core/models/doctor_note.dart';
import 'package:doctor_app/core/ports/transcript_summary_repository.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';

class DriftSummaryRepository implements TranscriptSummaryRepository {
  final LocalDatabase _db;

  DriftSummaryRepository(this._db);

  @override
  Future<void> save(TranscriptSummaryBundle bundle) async {
    final companion = TranscriptSummariesCompanion(
      consultationId: Value(bundle.consultationId),
      doctorId: Value(bundle.doctorNote?.doctorId ?? ''),
      structuredSummaryJson: Value(
        bundle.structuredMedicalSummary != null
            ? jsonEncode(bundle.structuredMedicalSummary!.toJson())
            : null,
      ),
      executiveSummary: Value(
        bundle.executiveSummary != null
            ? jsonEncode(bundle.executiveSummary!.toJson())
            : null,
      ),
      contextEnrichedSummaryJson: const Value(null),
      doctorNoteJson: Value(
        bundle.doctorNote != null
            ? jsonEncode(bundle.doctorNote!.toJson())
            : null,
      ),
      createdAt: Value(DateTime.parse(bundle.generatedAt)),
    );

    await _db.into(_db.transcriptSummaries).insertOnConflictUpdate(companion);
  }

  @override
  Future<TranscriptSummaryBundle?> findByConsultationId(
      String consultationId) async {
    final query = _db.select(_db.transcriptSummaries)
      ..where((t) => t.consultationId.equals(consultationId));
    final entity = await query.getSingleOrNull();

    if (entity == null) return null;
    return _mapEntityToModel(entity);
  }

  @override
  Future<List<TranscriptSummaryBundle>> findByDoctorId(String doctorId) async {
    final query = _db.select(_db.transcriptSummaries)
      ..where((t) => t.doctorId.equals(doctorId));
    final entities = await query.get();

    return entities.map(_mapEntityToModel).toList();
  }

  TranscriptSummaryBundle _mapEntityToModel(TranscriptSummaryEntity entity) {
    return TranscriptSummaryBundle(
      consultationId: entity.consultationId,
      transcriptId: entity.consultationId,
      structuredMedicalSummary: entity.structuredSummaryJson != null
          ? StructuredSummary.fromJson(
              jsonDecode(entity.structuredSummaryJson!))
          : null,
      executiveSummary: entity.executiveSummary != null
          ? ExecutiveSummary.fromJson(jsonDecode(entity.executiveSummary!))
          : null,
      doctorNote: entity.doctorNoteJson != null
          ? DoctorNote.fromJson(jsonDecode(entity.doctorNoteJson!))
          : null,
      generatedAt: entity.createdAt.toUtc().toIso8601String(),
    );
  }
}
