import 'dart:async';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_repository.dart';

/// Result of a conflict resolution attempt.
class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.resolvedNote,
    required this.strategy,
    required this.wasConflict,
  });

  final DoctorNote resolvedNote;
  final ConflictResolutionStrategy strategy;
  final bool wasConflict;
}

/// Strategy used to resolve a sync conflict.
enum ConflictResolutionStrategy {
  /// Local changes win (last write wins based on local timestamp)
  localWins,
  /// Remote changes win
  remoteWins,
  /// Manual merge by user
  manualMerge,
  /// Automatic merge (combine non-conflicting fields)
  autoMerge,
}

/// Service for resolving sync conflicts between local and remote notes.
class ConflictResolutionService {
  ConflictResolutionService();

  /// Detect if there's a conflict between local and remote notes.
  ///
  /// A conflict exists when both local and remote have been modified
  /// since the last successful sync (i.e., their updatedAt timestamps
  /// are both newer than the last sync time).
  bool hasConflict({
    required DoctorNote localNote,
    required DoctorNote remoteNote,
    DateTime? lastSyncTime,
  }) {
    if (lastSyncTime == null) {
      // First sync - no conflict possible
      return false;
    }

    final localModified = localNote.updatedAt.isAfter(lastSyncTime);
    final remoteModified = remoteNote.updatedAt.isAfter(lastSyncTime);

    return localModified && remoteModified;
  }

  /// Resolve a conflict using the specified strategy.
  ConflictResolutionResult resolve({
    required DoctorNote localNote,
    required DoctorNote remoteNote,
    required ConflictResolutionStrategy strategy,
    DateTime? lastSyncTime,
  }) {
    if (!hasConflict(localNote: localNote, remoteNote: remoteNote, lastSyncTime: lastSyncTime)) {
      // No conflict - use the most recently updated
      final winner = localNote.updatedAt.isAfter(remoteNote.updatedAt)
          ? localNote
          : remoteNote;
      return ConflictResolutionResult(
        resolvedNote: winner,
        strategy: ConflictResolutionStrategy.autoMerge,
        wasConflict: false,
      );
    }

    switch (strategy) {
      case ConflictResolutionStrategy.localWins:
        return ConflictResolutionResult(
          resolvedNote: localNote,
          strategy: strategy,
          wasConflict: true,
        );
      case ConflictResolutionStrategy.remoteWins:
        return ConflictResolutionResult(
          resolvedNote: remoteNote,
          strategy: strategy,
          wasConflict: true,
        );
      case ConflictResolutionStrategy.autoMerge:
        return ConflictResolutionResult(
          resolvedNote: _autoMerge(localNote, remoteNote),
          strategy: strategy,
          wasConflict: true,
        );
      case ConflictResolutionStrategy.manualMerge:
        // For manual merge, return local with conflict flag
        // The UI should present both versions to the user
        return ConflictResolutionResult(
          resolvedNote: localNote.copyWith(
            status: NoteStatus.conflict,
            // Store remote version for manual resolution UI
            // This could be stored in a separate field or metadata
          ),
          strategy: strategy,
          wasConflict: true,
        );
    }
  }

  /// Automatically merge non-conflicting fields.
  ///
  /// Strategy: Use the most recent value for each field based on
  /// the note's updatedAt timestamp. For text fields that have
  /// diverged, prefer the local version (user's current work).
  DoctorNote _autoMerge(DoctorNote local, DoctorNote remote) {
    // If content is identical, no merge needed
    if (local.rawText == remote.rawText &&
        local.richTextDelta == remote.richTextDelta) {
      return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
    }

    // Prefer local text (user's current draft) but merge metadata from remote
    return local.copyWith(
      // Keep local text - user may be actively editing
      // rawText: local.rawText,
      // richTextDelta: local.richTextDelta,
      // Merge extracted fields if they differ
      extractedFields: _mergeFields(local.extractedFields, remote.extractedFields),
      // Keep local recap but merge if remote is newer
      patientRecap: local.updatedAt.isAfter(remote.updatedAt)
          ? local.patientRecap
          : remote.patientRecap,
      // Use the latest status
      status: _mergeStatus(local.status, remote.status),
      // Update timestamp to now
      updatedAt: DateTime.now().toUtc(),
    );
  }

  ExtractedFields? _mergeFields(ExtractedFields? local, ExtractedFields? remote) {
    if (local == null) return remote;
    if (remote == null) return local;

    // If identical, return either
    if (local.toJson().toString() == remote.toJson().toString()) {
      return local;
    }

    // Merge non-null fields from both, preferring local
    return ExtractedFields(
      patientName: local.patientName ?? remote.patientName,
      patientAge: local.patientAge ?? remote.patientAge,
      patientGender: local.patientGender ?? remote.patientGender,
      chiefComplaint: local.chiefComplaint ?? remote.chiefComplaint,
      historyOfPresentIllness: local.historyOfPresentIllness ?? remote.historyOfPresentIllness,
      pastMedicalHistory: local.pastMedicalHistory ?? remote.pastMedicalHistory,
      medications: local.medications ?? remote.medications,
      allergies: local.allergies ?? remote.allergies,
      vitalSigns: local.vitalSigns ?? remote.vitalSigns,
      physicalExam: local.physicalExam ?? remote.physicalExam,
      assessment: local.assessment ?? remote.assessment,
      plan: local.plan ?? remote.plan,
    );
  }

  NoteStatus _mergeStatus(NoteStatus local, NoteStatus remote) {
    // Prefer the more "advanced" status
    const order = [
      NoteStatus.draft,
      NoteStatus.pendingReview,
      NoteStatus.finalized,
      NoteStatus.conflict,
    ];

    final localIndex = order.indexOf(local);
    final remoteIndex = order.indexOf(remote);

    if (localIndex >= remoteIndex) return local;
    return remote;
  }

  /// Create a conflict entry for manual resolution.
  ///
  /// Returns a new note with conflict status and both versions preserved.
  DoctorNote createConflictEntry({
    required DoctorNote localNote,
    required DoctorNote remoteNote,
  }) {
    return localNote.copyWith(
      status: NoteStatus.conflict,
      updatedAt: DateTime.now().toUtc(),
      // Store remote version in extractedFields metadata or a separate field
      // For now, we'll encode it in a way that the UI can retrieve
      extractedFields: localNote.extractedFields?.copyWith(
        // Add remote version info
      ),
    );
  }
}

/// Extended SyncQueueRepository with conflict resolution support.
class ConflictAwareSyncQueueRepository {
  ConflictAwareSyncQueueRepository({
    required this.syncQueueRepository,
    required this.conflictResolutionService,
    this.defaultStrategy = ConflictResolutionStrategy.autoMerge,
  });

  final SyncQueueRepository syncQueueRepository;
  final ConflictResolutionService conflictResolutionService;
  final ConflictResolutionStrategy defaultStrategy;

  /// Process a sync queue entry with conflict resolution.
  ///
  /// If the entry is marked as conflict, attempt resolution with the
  /// given strategy (or user-selected strategy).
  Future<ConflictResolutionResult> processWithConflictResolution({
    required SyncQueueEntry entry,
    required DoctorNote remoteNote,
    ConflictResolutionStrategy? strategy,
    DateTime? lastSyncTime,
  }) async {
    // Get the current local note
    final localNote = entry.note;

    // If entry is already marked as conflict, it needs manual resolution
    if (entry.isConflict) {
      final result = conflictResolutionService.resolve(
        localNote: localNote,
        remoteNote: remoteNote,
        strategy: strategy ?? ConflictResolutionStrategy.manualMerge,
        lastSyncTime: lastSyncTime,
      );
      return result;
    }

    // Check for new conflicts
    if (conflictResolutionService.hasConflict(
      localNote: localNote,
      remoteNote: remoteNote,
      lastSyncTime: lastSyncTime,
    )) {
      final result = conflictResolutionService.resolve(
        localNote: localNote,
        remoteNote: remoteNote,
        strategy: strategy ?? defaultStrategy,
        lastSyncTime: lastSyncTime,
      );

      // If auto-merge was used, update the entry
      if (result.strategy == ConflictResolutionStrategy.autoMerge) {
        entry = entry.copyWith(
          note: result.resolvedNote,
          isConflict: false,
          updatedAt: DateTime.now().toUtc(),
        );
        await syncQueueRepository.updateEntry(entry);
      } else if (result.strategy == ConflictResolutionStrategy.manualMerge) {
        // Mark as conflict for manual resolution
        entry = entry.copyWith(
          isConflict: true,
          updatedAt: DateTime.now().toUtc(),
        );
        await syncQueueRepository.updateEntry(entry);
      }

      return result;
    }

    // No conflict - use the most recent
    final winner = localNote.updatedAt.isAfter(remoteNote.updatedAt)
        ? localNote
        : remoteNote;

    return ConflictResolutionResult(
      resolvedNote: winner,
      strategy: ConflictResolutionStrategy.autoMerge,
      wasConflict: false,
    );
  }

  /// Get all entries that need manual conflict resolution.
  Future<List<SyncQueueEntry>> getConflicts() async {
    // This would need a query for isConflict = true
    // For now, return empty - implement based on actual query needs
    return [];
  }

  /// Resolve a conflict manually (user chose local or remote).
  Future<void> resolveConflictManually({
    required String entryId,
    required bool useLocal,
    DoctorNote? mergedNote,
  }) async {
    final entry = await syncQueueRepository.getById(entryId);
    if (entry == null) {
      throw DatabaseException('Sync queue entry not found: $entryId');
    }

    DoctorNote resolvedNote;
    if (useLocal) {
      resolvedNote = entry.note;
    } else if (mergedNote != null) {
      resolvedNote = mergedNote;
    } else {
      // Fetch remote and use it
      throw UnimplementedError('Remote note fetch not implemented');
    }

    final updatedEntry = entry.copyWith(
      note: resolvedNote,
      isConflict: false,
      updatedAt: DateTime.now().toUtc(),
    );

    await syncQueueRepository.updateEntry(updatedEntry);
  }
}

/// Extension to add copyWith for SyncQueueEntry
extension SyncQueueEntryExtension on SyncQueueEntry {
  SyncQueueEntry copyWith({
    DoctorNote? note,
    bool? isConflict,
    DateTime? updatedAt,
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastError,
    bool? isDeadLetter,
  }) {
    return SyncQueueEntry(
      id: id,
      noteId: noteId,
      consultationId: consultationId,
      operation: operation,
      note: note ?? this.note,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      isDeadLetter: isDeadLetter ?? this.isDeadLetter,
      isConflict: isConflict ?? this.isConflict,
    );
  }
}