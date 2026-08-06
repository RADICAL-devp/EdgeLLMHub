import 'package:drift/drift.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_repository.dart';
import 'package:shared_models/shared_models.dart';
import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';
import 'clinical_database.dart';

class DriftTranscriptRepository implements TranscriptRepository {
  final ClinicalDatabase _db;
  final AesGcmService _crypto;

  DriftTranscriptRepository(this._db, this._crypto);

  static const _encryptedFields = {
    'transcriptText': 'transcriptText',
    'patientId': 'patientId',
    'doctorId': 'doctorId',
    'sleepLabId': 'sleepLabId',
  };

  @override
  Future<void> save(ConsultationTranscript transcript) async {
    await _db.into(_db.transcripts).insertOnConflictUpdate(
      TranscriptsCompanion.insert(
        transcriptId: transcript.transcriptId,
        consultationId: transcript.consultationId,
        patientId: Value(_encryptField('patientId', transcript.patientId)),
        doctorId: Value(_encryptField('doctorId', transcript.doctorId)),
        sleepLabId: Value(_encryptField('sleepLabId', transcript.sleepLabId)),
        transcriptText: _encryptField('transcriptText', transcript.transcriptText),
        consultationMode: transcript.consultationMode?.toJson() ?? ConsultationMode.inPerson.toJson(),
        createdAt: transcript.createdAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<ConsultationTranscript?> findByConsultationId(String consultationId) async {
    final row = await (_db.select(_db.transcripts)
          ..where((t) => t.consultationId.equals(consultationId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toTranscript(row) : null;
  }

  @override
  Future<ConsultationTranscript?> findByTranscriptId(String transcriptId) async {
    final row = await (_db.select(_db.transcripts)
          ..where((t) => t.transcriptId.equals(transcriptId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toTranscript(row) : null;
  }

  @override
  Future<List<ConsultationTranscript>> findByDoctorId(String doctorId) async {
    final rows = await (_db.select(_db.transcripts)
          ..where((t) => t.doctorId.equals(doctorId)))
        .get();
    return rows.map(_toTranscript).toList();
  }

  @override
  Future<void> delete(String transcriptId) async {
    await (_db.delete(_db.transcripts)
          ..where((t) => t.transcriptId.equals(transcriptId)))
        .go();
  }

  String? _encryptField(String fieldName, String? value) {
    if (value == null) return null;
    return _crypto.encrypt(value, fieldName);
  }

  String? _decryptField(String fieldName, String? value) {
    if (value == null) return null;
    try {
      return _crypto.decrypt(value, fieldName);
    } catch (_) {
      return value; // Return as-is if decryption fails (legacy data)
    }
  }

  ConsultationTranscript _toTranscript(Transcript row) {
    return ConsultationTranscript(
      transcriptId: row.transcriptId,
      consultationId: row.consultationId,
      patientId: _decryptField('patientId', row.patientId),
      doctorId: _decryptField('doctorId', row.doctorId),
      sleepLabId: _decryptField('sleepLabId', row.sleepLabId),
      transcriptText: _decryptField('transcriptText', row.transcriptText),
      consultationMode: ConsultationMode.tryParse(row.consultationMode) ?? ConsultationMode.inPerson,
      createdAt: row.createdAt,
    );
  }
}
