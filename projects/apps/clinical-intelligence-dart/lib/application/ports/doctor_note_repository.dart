import 'package:clinical_intelligence_dart/core/models/doctor_note.dart';

/// Port for persisting doctor notes synced from the mobile app.
abstract class DoctorNoteRepository {
  /// Upsert a note by [DoctorNote.noteId] (last-write-wins on updatedAt).
  Future<void> upsert(DoctorNote note);

  /// Fetch the most recent note for a consultation, or null.
  Future<DoctorNote?> findByConsultationId(String consultationId);
}
