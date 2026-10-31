import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

import '../crypto/phi_encryption_service.dart';
import '../exceptions/app_exceptions.dart';
import '../models/clinical_note.dart';
import 'app_database.dart';

/// Encrypted, local-only note persistence.
///
/// Text fields are encrypted individually with [PhiEncryptionService] before
/// they are written. Search therefore decrypts notes into memory first; this
/// is acceptable for a clinician's local note set and keeps the database
/// unreadable at rest.
class NoteRepository {
  NoteRepository(this._db, this._encryption);

  final AppDatabase _db;
  final PhiEncryptionService _encryption;

  Future<List<ClinicalNote>> getAll() async {
    final rows = await (_db.select(
      _db.clinicalNotes,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    final notes = <ClinicalNote>[];
    for (final row in rows) {
      notes.add(await _fromRow(row));
    }
    return notes;
  }

  Future<ClinicalNote?> getById(String id) async {
    final row = await (_db.select(
      _db.clinicalNotes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _fromRow(row);
  }

  Future<void> save(ClinicalNote note) async {
    try {
      final sectionsJson = jsonEncode(note.sections.toJson());
      await _db
          .into(_db.clinicalNotes)
          .insertOnConflictUpdate(
            ClinicalNotesCompanion(
              id: Value(note.id),
              titleCipher: Value(await _encryption.encryptString(note.title)),
              patientNameCipher: Value(
                await _encryption.encryptString(note.patientName),
              ),
              transcriptCipher: Value(
                await _encryption.encryptString(note.transcript),
              ),
              cleanedTranscriptCipher: Value(
                note.cleanedTranscript == null
                    ? null
                    : await _encryption.encryptString(note.cleanedTranscript!),
              ),
              sectionsCipher: Value(
                await _encryption.encryptString(sectionsJson),
              ),
              status: Value(note.status.index),
              languageCode: Value(note.languageCode),
              thinkingModeUsed: Value(note.thinkingModeUsed),
              modelName: Value(note.modelName),
              createdAt: Value(note.createdAt),
              updatedAt: Value(note.updatedAt),
            ),
          );
    } on EncryptionException {
      rethrow;
    } catch (error) {
      throw DatabaseException(
        'Could not save this note locally.',
        cause: error,
      );
    }
  }

  Future<void> deleteById(String id) async {
    try {
      await (_db.delete(_db.clinicalNotes)..where((t) => t.id.equals(id))).go();
    } catch (error) {
      throw DatabaseException('Could not delete this note.', cause: error);
    }
  }

  Future<void> deleteAll() async {
    try {
      await _db.delete(_db.clinicalNotes).go();
    } catch (error) {
      throw DatabaseException(
        'Could not delete the local notes.',
        cause: error,
      );
    }
  }

  /// Case-insensitive search over decrypted note content plus an optional
  /// date range. `from`/`to` are inclusive calendar days.
  Future<List<ClinicalNote>> search(
    String query, {
    DateTime? from,
    DateTime? to,
  }) async {
    final notes = await getAll();
    final normalized = query.trim().toLowerCase();
    final start = from == null ? null : _startOfDay(from);
    final endExclusive = to == null
        ? null
        : _startOfDay(to).add(const Duration(days: 1));

    return notes
        .where((note) {
          if (start != null && note.updatedAt.isBefore(start)) return false;
          if (endExclusive != null && !note.updatedAt.isBefore(endExclusive)) {
            return false;
          }
          if (normalized.isEmpty) return true;

          if (note.searchableText.contains(normalized)) return true;

          final dateText = [
            DateFormat('yyyy-MM-dd').format(note.updatedAt),
            DateFormat('yyyy-MM-dd').format(note.createdAt),
            DateFormat.yMMMd().format(note.updatedAt),
          ];
          return dateText.any(
            (value) => value.toLowerCase().contains(normalized),
          );
        })
        .toList(growable: false);
  }

  Future<int> countAll() async {
    final count = _db.clinicalNotes.id.count();
    final query = _db.selectOnly(_db.clinicalNotes)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countByStatus(NoteStatus status) async {
    final count = _db.clinicalNotes.id.count();
    final query = _db.selectOnly(_db.clinicalNotes)
      ..addColumns([count])
      ..where(_db.clinicalNotes.status.equals(status.index));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countUpdatedToday() async {
    final now = DateTime.now();
    final start = _startOfDay(now);
    final end = start.add(const Duration(days: 1));
    final count = _db.clinicalNotes.id.count();
    final query = _db.selectOnly(_db.clinicalNotes)
      ..addColumns([count])
      ..where(
        _db.clinicalNotes.updatedAt.isBiggerOrEqualValue(start) &
            _db.clinicalNotes.updatedAt.isSmallerThanValue(end),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<ClinicalNote> _fromRow(ClinicalNoteRow row) async {
    try {
      final title = await _encryption.decryptString(row.titleCipher);
      final patientName = await _encryption.decryptString(
        row.patientNameCipher,
      );
      final transcript = await _encryption.decryptString(row.transcriptCipher);
      final cleaned = row.cleanedTranscriptCipher == null
          ? null
          : await _encryption.decryptString(row.cleanedTranscriptCipher!);
      final sectionsJson = await _encryption.decryptString(row.sectionsCipher);

      StructuredNoteSections sections;
      try {
        final decoded = jsonDecode(sectionsJson);
        sections = decoded is Map<String, dynamic>
            ? StructuredNoteSections.fromJson(decoded)
            : StructuredNoteSections();
      } catch (_) {
        sections = StructuredNoteSections();
      }

      return ClinicalNote(
        id: row.id,
        title: title,
        patientName: patientName,
        transcript: transcript,
        cleanedTranscript: cleaned,
        sections: sections,
        status: NoteStatus
            .values[row.status.clamp(0, NoteStatus.values.length - 1)],
        languageCode: row.languageCode,
        thinkingModeUsed: row.thinkingModeUsed,
        modelName: row.modelName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    } catch (_) {
      // A key change or corruption should not hide every other note. Keep a
      // visible placeholder so the clinician can delete the unreadable record.
      return ClinicalNote(
        id: row.id,
        title: 'Unreadable note',
        patientName: '',
        transcript: '',
        sections: StructuredNoteSections(
          assessment:
              'This note could not be decrypted on this device. It may have '
              'been created with a different secure-storage key.',
        ),
        status: NoteStatus
            .values[row.status.clamp(0, NoteStatus.values.length - 1)],
        languageCode: row.languageCode,
        thinkingModeUsed: row.thinkingModeUsed,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
