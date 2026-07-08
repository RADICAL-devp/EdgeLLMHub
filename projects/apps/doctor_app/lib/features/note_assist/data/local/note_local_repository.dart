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
            status: Value(note.status.index),
            extractedFields: Value(note.extractedFields != null ? jsonEncode(note.extractedFields!.toJson()) : null),
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
      status: NoteStatus.values[record.status],
      extractedFields: record.extractedFields != null ? ExtractedFields.fromJson(jsonDecode(record.extractedFields!)) : null,
      patientRecap: record.patientRecap,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  Future<List<DoctorNote>> getNotesForConsultation(String consultationId) async {
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
              status: NoteStatus.values[r.status],
              extractedFields: r.extractedFields != null ? ExtractedFields.fromJson(jsonDecode(r.extractedFields!)) : null,
              patientRecap: r.patientRecap,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }
}
