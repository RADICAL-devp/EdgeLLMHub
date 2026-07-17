import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../features/note_assist/domain/models/doctor_note.dart';
import '../../features/note_assist/data/repositories/note_sync_repository.dart';

class SyncQueueService {
  final NoteSyncRepository _syncRepository;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Simple in-memory queue for failed syncs
  final List<DoctorNote> _pendingNotes = [];

  SyncQueueService(this._syncRepository);

  void startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.contains(ConnectivityResult.mobile) || 
                       results.contains(ConnectivityResult.wifi) ||
                       results.contains(ConnectivityResult.ethernet);
      
      if (isOnline && _pendingNotes.isNotEmpty) {
        _replayQueue();
      }
    });
  }

  void enqueueNote(DoctorNote note) {
    // Remove if already in queue to replace with latest version
    _pendingNotes.removeWhere((n) => n.noteId == note.noteId);
    _pendingNotes.add(note);
  }

  Future<void> _replayQueue() async {
    final notesToSync = List<DoctorNote>.from(_pendingNotes);
    _pendingNotes.clear();

    for (final note in notesToSync) {
      try {
        await _syncRepository.syncNoteToBackend(note.consultationId);
      } catch (e) {
        // If it fails again, re-queue it
        enqueueNote(note);
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
