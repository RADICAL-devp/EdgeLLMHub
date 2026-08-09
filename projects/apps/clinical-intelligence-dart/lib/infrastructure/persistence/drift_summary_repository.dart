import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:clinical_intelligence_dart/application/ports/transcript_summary_repository.dart';
import 'package:shared_models/shared_models.dart';
import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';
import 'clinical_database.dart';

class DriftSummaryRepository implements TranscriptSummaryRepository {
  final ClinicalDatabase _db;
  final AesGcmService _crypto;

  DriftSummaryRepository(this._db, this._crypto);

  @override
  Future<void> save(TranscriptSummaryBundle bundle) async {
    await _db.into(_db.summaryBundles).insertOnConflictUpdate(
      SummaryBundlesCompanion.insert(
        consultationId: bundle.consultationId,
        transcriptId: bundle.transcriptId,
        structuredMedicalSummary: _encryptJson('structuredMedicalSummary', bundle.structuredMedicalSummary?.toJson()),
        executiveSummary: Value(_encryptJson('executiveSummary', bundle.executiveSummary?.toJson())),
        doctorNote: Value(_encryptJson('doctorNote', bundle.doctorNote?.toJson())),
        generatedAt: DateTime.parse(bundle.generatedAt),
        consultationMode: bundle.consultationMode?.toJson() ?? ConsultationMode.inPerson.toJson(),
      ),
    );
  }

  @override
  Future<TranscriptSummaryBundle?> findByConsultationId(String consultationId) async {
    final row = await (_db.select(_db.summaryBundles)
          ..where((s) => s.consultationId.equals(consultationId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toBundle(row) : null;
  }

  @override
  Future<List<TranscriptSummaryBundle>> findByDoctorId(String doctorId) async {
    // Note: SummaryBundles doesn't have doctorId directly, would need to join with Transcripts
    return [];
  }

  @override
  Future<void> delete(String consultationId) async {
    await (_db.delete(_db.summaryBundles)
          ..where((s) => s.consultationId.equals(consultationId)))
        .go();
  }

  String _encryptJson(String fieldName, Map<String, dynamic>? json) {
    if (json == null) return '';
    final encoded = jsonEncode(json);
    return _crypto.encrypt(encoded, fieldName);
  }

  Map<String, dynamic>? _decryptJson(String fieldName, String? encrypted) {
    if (encrypted == null || encrypted.isEmpty) return null;
    try {
      final decrypted = _crypto.decrypt(encrypted, fieldName);
      return Map<String, dynamic>.from(jsonDecode(decrypted) as Map);
    } catch (_) {
      return null;
    }
  }

  TranscriptSummaryBundle _toBundle(SummaryBundle row) {
    final structured =
        _decryptJson('structuredMedicalSummary', row.structuredMedicalSummary);
    final executive =
        _decryptJson('executiveSummary', row.executiveSummary);
    final doctorNote = _decryptJson('doctorNote', row.doctorNote);
    return TranscriptSummaryBundle(
      consultationId: row.consultationId,
      transcriptId: row.transcriptId,
      structuredMedicalSummary:
          structured == null ? null : StructuredSummary.fromJson(structured),
      executiveSummary:
          executive == null ? null : ExecutiveSummary.fromJson(executive),
      doctorNote: doctorNote == null ? null : DoctorNote.fromJson(doctorNote),
      generatedAt: row.generatedAt.toIso8601String(),
      consultationMode: ConsultationMode.tryParse(row.consultationMode) ?? ConsultationMode.inPerson,
    );
  }
}
