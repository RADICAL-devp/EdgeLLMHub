import '../../domain/models/doctor_note.dart';
import '../local/note_local_repository.dart';
import '../remote/note_remote_datasource.dart';

class NoteSyncRepository {
  final NoteLocalRepository _localRepository;
  final NoteRemoteDatasource _remoteDatasource;

  NoteSyncRepository(this._localRepository, this._remoteDatasource);

  Future<void> syncNoteToBackend(String consultationId) async {
    final note = await _localRepository.getNoteByConsultationId(consultationId);
    if (note != null) {
      await _remoteDatasource.syncNote(note);
    }
  }
}
