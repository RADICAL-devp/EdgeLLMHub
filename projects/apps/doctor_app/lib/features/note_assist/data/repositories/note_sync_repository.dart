import 'dart:developer' as developer;

import '../../domain/models/doctor_note.dart';
import '../local/note_local_repository.dart';
import '../remote/note_remote_datasource.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Repository that coordinates local persistence and remote sync.
///
/// Wraps sync operations with error handling and provides bulk
/// sync for replaying pending operations on reconnection.
class NoteSyncRepository {
  final NoteLocalRepository _localRepository;
  final NoteRemoteDatasource _remoteDatasource;

  NoteSyncRepository(this._localRepository, this._remoteDatasource);

  /// Sync a single note to the backend.
  ///
  /// Fetches the latest local version and pushes it to the remote.
  /// Throws [DatabaseException] on local read failure.
  /// Throws [NetworkException] on remote sync failure.
  Future<void> syncNoteToBackend(String consultationId) async {
    final DoctorNote? note;
    try {
      note = await _localRepository.getNoteByConsultationId(consultationId);
    } catch (e) {
      throw DatabaseException(
        'Failed to read note for sync (consultation=$consultationId): $e',
        cause: e,
      );
    }

    if (note == null) {
      developer.log(
        'No local note found for consultation=$consultationId, skipping sync',
        name: 'NoteSyncRepository',
      );
      return;
    }

    try {
      await _remoteDatasource.syncNote(note);
      developer.log(
        'Successfully synced note for consultation=$consultationId',
        name: 'NoteSyncRepository',
      );
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException(
        'Failed to sync note to backend: $e',
        cause: e,
        isTransient: true,
      );
    }
  }

  /// Sync a batch of notes by consultation IDs.
  ///
  /// Iterates through the provided consultation IDs and syncs each one.
  /// Collects errors without stopping — returns the count of
  /// successfully synced notes.
  Future<SyncResult> syncAllPending(List<String> consultationIds) async {
    int succeeded = 0;
    int failed = 0;
    final errors = <String>[];

    for (final consultationId in consultationIds) {
      try {
        await syncNoteToBackend(consultationId);
        succeeded++;
      } catch (e) {
        failed++;
        errors.add('$consultationId: $e');
        developer.log(
          'Failed to sync note $consultationId: $e',
          name: 'NoteSyncRepository',
        );
      }
    }

    developer.log(
      'Bulk sync complete: $succeeded succeeded, $failed failed',
      name: 'NoteSyncRepository',
    );

    return SyncResult(
      succeeded: succeeded,
      failed: failed,
      errors: errors,
    );
  }
}

/// Result of a bulk sync operation.
class SyncResult {
  final int succeeded;
  final int failed;
  final List<String> errors;

  const SyncResult({
    required this.succeeded,
    required this.failed,
    this.errors = const [],
  });

  bool get hasErrors => failed > 0;
}
