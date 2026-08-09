import 'package:drift/drift.dart';
import 'local_database.dart';
import 'dart:convert';
import '../../domain/models/doctor_note.dart';

class NoteLocalRepository {
  final LocalDatabase db;

  NoteLocalRepository(this.db);

  Future<void> saveNote(DoctorNote note) async {
    await db.into(db.doctorNotes).insertOnConflictUpdate(
          DoctorNotesCompanion(
            noteId: Value(note.noteId),
            consultationId: Value(note.consultationId),
            patientId: Value(note.patientId),
            doctorId: Value(note.doctorId),
            rawText: Value(note.rawText),
            richTextDelta: Value(note.richTextDelta),
            status: Value(note.status.index),
            extractedFields: Value(note.extractedFields != null
                ? jsonEncode(note.extractedFields!.toJson())
                : null),
            patientRecap: Value(note.patientRecap),
            createdAt: Value(note.createdAt),
            updatedAt: Value(note.updatedAt),
          ),
        );
  }

  Future<DoctorNote?> getNoteById(String noteId) async {
    final record = await (db.select(db.doctorNotes)
          ..where((t) => t.noteId.equals(noteId)))
        .getSingleOrNull();

    if (record == null) return null;

    return DoctorNote(
      noteId: record.noteId,
      consultationId: record.consultationId,
      patientId: record.patientId,
      doctorId: record.doctorId,
      rawText: record.rawText,
      richTextDelta: record.richTextDelta,
      status: NoteStatus.values[record.status],
      extractedFields: record.extractedFields != null
          ? ExtractedFields.fromJson(jsonDecode(record.extractedFields!))
          : null,
      patientRecap: record.patientRecap,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  Future<List<DoctorNote>> getNotesForConsultation(
      String consultationId) async {
    final records = await (db.select(db.doctorNotes)
          ..where((t) => t.consultationId.equals(consultationId)))
        .get();

    return records
        .map((r) => DoctorNote(
              noteId: r.noteId,
              consultationId: r.consultationId,
              patientId: r.patientId,
              doctorId: r.doctorId,
              rawText: r.rawText,
              richTextDelta: r.richTextDelta,
              status: NoteStatus.values[r.status],
              extractedFields: r.extractedFields != null
                  ? ExtractedFields.fromJson(jsonDecode(r.extractedFields!))
                  : null,
              patientRecap: r.patientRecap,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  Future<DoctorNote?> getNoteByConsultationId(String consultationId) async {
    final notes = await getNotesForConsultation(consultationId);
    return notes.isEmpty ? null : notes.first;
  }

  /// All notes across all consultations, newest first.
  Future<List<DoctorNote>> getAllNotes() async {
    final records = await (db.select(db.doctorNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    return records
        .map((r) => DoctorNote(
              noteId: r.noteId,
              consultationId: r.consultationId,
              patientId: r.patientId,
              doctorId: r.doctorId,
              rawText: r.rawText,
              richTextDelta: r.richTextDelta,
              status: NoteStatus.values[r.status],
              extractedFields: r.extractedFields != null
                  ? ExtractedFields.fromJson(jsonDecode(r.extractedFields!))
                  : null,
              patientRecap: r.patientRecap,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  /// Distinct consultations ordered by most-recent note update.
  ///
  /// Each entry uses the note with the latest [DoctorNote.updatedAt] for a
  /// given consultation, so the list always reflects the freshest content.
  Future<List<DoctorNote>> getAllConsultations() async {
    final notes = await getAllNotes();
    final byConsultation = <String, DoctorNote>{};
    for (final note in notes) {
      final existing = byConsultation[note.consultationId];
      if (existing == null || note.updatedAt.isAfter(existing.updatedAt)) {
        byConsultation[note.consultationId] = note;
      }
    }
    final result = byConsultation.values.toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }
}
