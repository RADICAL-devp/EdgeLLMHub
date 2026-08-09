import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:clinical_intelligence_dart/application/ports/doctor_note_repository.dart';
import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';
import 'package:clinical_intelligence_dart/core/models/doctor_note.dart';
import 'clinical_database.dart';

class DriftDoctorNoteRepository implements DoctorNoteRepository {
  final ClinicalDatabase _db;
  final AesGcmService _crypto;

  DriftDoctorNoteRepository(this._db, this._crypto);

  static const _encryptedFields = {
    'patientId': 'patientId',
    'doctorId': 'doctorId',
    'rawText': 'rawText',
    'richTextDelta': 'richTextDelta',
    'extractedFields': 'extractedFields',
    'patientRecap': 'patientRecap',
  };

  @override
  Future<void> upsert(DoctorNote note) async {
    await _db.into(_db.syncedDoctorNotes).insertOnConflictUpdate(
      SyncedDoctorNotesCompanion.insert(
        noteId: note.noteId,
        consultationId: note.consultationId,
        patientId: Value(_encryptField('patientId', note.patientId)),
        doctorId: Value(_encryptField('doctorId', note.doctorId)),
        rawText: _encryptField('rawText', note.rawText) ?? '',
        richTextDelta: Value(_encryptField('richTextDelta', note.richTextDelta)),
        status: note.status,
        extractedFields: Value(
          _encryptField(
            'extractedFields',
            note.extractedFields != null
                ? jsonEncode(note.extractedFields!.toJson())
                : null,
          ),
        ),
        patientRecap: Value(_encryptField('patientRecap', note.patientRecap)),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      ),
    );
  }

  @override
  Future<DoctorNote?> findByConsultationId(String consultationId) async {
    final row = await (_db.select(_db.syncedDoctorNotes)
          ..where((t) => t.consultationId.equals(consultationId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toNote(row) : null;
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

  DoctorNote _toNote(SyncedDoctorNote row) {
    final extractedFieldsJson = _decryptField('extractedFields', row.extractedFields);
    return DoctorNote(
      noteId: row.noteId,
      consultationId: row.consultationId,
      patientId: _decryptField('patientId', row.patientId) ?? '',
      doctorId: _decryptField('doctorId', row.doctorId) ?? '',
      rawText: _decryptField('rawText', row.rawText) ?? '',
      richTextDelta: _decryptField('richTextDelta', row.richTextDelta),
      status: row.status,
      extractedFields: extractedFieldsJson != null
          ? ExtractedFields.fromJson(
              Map<String, dynamic>.from(
                // The extracted fields were encrypted as a JSON map string.
                (jsonDecode(extractedFieldsJson) as Map),
              ),
            )
          : null,
      patientRecap: _decryptField('patientRecap', row.patientRecap),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
