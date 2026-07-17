import 'package:drift/drift.dart';
import 'package:doctor_app/core/models/consultation_transcript.dart';
import 'package:doctor_app/core/ports/transcript_repository.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';

class DriftTranscriptRepository implements TranscriptRepository {
  final LocalDatabase _db;

  DriftTranscriptRepository(this._db);

  @override
  Future<void> save(ConsultationTranscript transcript) async {
    final companion = TranscriptsCompanion(
      transcriptId: Value(transcript.transcriptId),
      consultationId: Value(transcript.consultationId),
      doctorId: Value(transcript.doctorId ?? ''),
      rawText: Value(transcript.transcriptText),
      cleanedText: const Value(null),
      source: const Value(1),
      createdAt: Value(transcript.createdAt ?? DateTime.now().toUtc()),
    );

    await _db.into(_db.transcripts).insertOnConflictUpdate(companion);
  }

  @override
  Future<ConsultationTranscript?> findByTranscriptId(
      String transcriptId) async {
    final query = _db.select(_db.transcripts)
      ..where((t) => t.transcriptId.equals(transcriptId));
    final entity = await query.getSingleOrNull();

    if (entity == null) return null;
    return _mapEntityToModel(entity);
  }

  @override
  Future<ConsultationTranscript?> findByConsultationId(
      String consultationId) async {
    final query = _db.select(_db.transcripts)
      ..where((t) => t.consultationId.equals(consultationId));
    final entity = await query.getSingleOrNull();

    if (entity == null) return null;
    return _mapEntityToModel(entity);
  }

  @override
  Future<List<ConsultationTranscript>> findByDoctorId(String doctorId) async {
    final query = _db.select(_db.transcripts)
      ..where((t) => t.doctorId.equals(doctorId));
    final entities = await query.get();

    return entities.map(_mapEntityToModel).toList();
  }

  ConsultationTranscript _mapEntityToModel(TranscriptEntity entity) {
    return ConsultationTranscript(
      transcriptId: entity.transcriptId,
      consultationId: entity.consultationId,
      doctorId: entity.doctorId,
      transcriptText: entity.rawText,
      createdAt: entity.createdAt,
    );
  }
}
