import 'package:drift/drift.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'local_database.dart';

class SyncQueueRepository {
  final LocalDatabase _db;

  SyncQueueRepository(this._db);

  Future<void> enqueue(SyncQueueEntry entry) async {
    await _db.into(_db.syncQueueEntries).insertOnConflictUpdate(
      SyncQueueEntriesCompanion.insert(
        id: entry.id,
        noteId: entry.noteId,
        consultationId: entry.consultationId,
        operation: entry.operation,
        payloadJson: entry.note.toJson(),
        retryCount: Value(entry.retryCount),
        maxRetries: Value(entry.maxRetries),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        nextRetryAt: Value(entry.nextRetryAt),
        lastError: Value(entry.lastError),
        isDeadLetter: Value(entry.isDeadLetter),
      ),
    );
  }

  Future<SyncQueueEntry?> getById(String id) async {
    final row = await (_db.select(_db.syncQueueEntries)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toEntry(row) : null;
  }

  Future<List<SyncQueueEntry>> getPendingEntries() async {
    final now = DateTime.now().toUtc();
    final rows = await (_db.select(_db.syncQueueEntries)
          ..where((t) => t.isDeadLetter.equals(false) &
              (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerThanValue(DateTime.now().toUtc())))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_toEntry).toList();
  }

  Future<List<SyncQueueEntry>> getDeadLetterEntries() async {
    final rows = await (_db.select(_db.syncQueueEntries)
          ..where((t) => t.isDeadLetter.equals(true)))
        .get();
    return rows.map(_toEntry).toList();
  }

  Future<void> updateEntry(SyncQueueEntry entry) async {
    await _db.update(_db.syncQueueEntries).replace(
      SyncQueueEntriesCompanion(
        id: Value(entry.id),
        noteId: Value(entry.noteId),
        consultationId: Value(entry.consultationId),
        operation: Value(entry.operation),
        payloadJson: Value(entry.note.toJson()),
        retryCount: Value(entry.retryCount),
        maxRetries: Value(entry.maxRetries),
        createdAt: Value(entry.createdAt),
        updatedAt: Value(entry.updatedAt),
        nextRetryAt: Value(entry.nextRetryAt),
        lastError: Value(entry.lastError),
        isDeadLetter: Value(entry.isDeadLetter),
      ),
    );
  }

  Future<void> markDeadLetter(String id, String error) async {
    await (_db.update(_db.syncQueueEntries)
          ..where((t) => t.id.equals(id)))
        .write(SyncQueueEntriesCompanion(
      isDeadLetter: const Value(true),
      lastError: Value(error),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.syncQueueEntries)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<int> getPendingCount() async {
    final now = DateTime.now().toUtc();
    final count = await (_db.selectOnly(_db.syncQueueEntries)
          ..where((t) => t.isDeadLetter.equals(false) &
              (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerThanValue(DateTime.now().toUtc())))
          ..addColumns([db.syncQueueEntries.id.count()]))
        .getSingle();
    return count.read(db.syncQueueEntries.id.count()) ?? 0;
  }

  SyncQueueEntry _toEntry(SyncQueueEntryEntity row) {
    return SyncQueueEntry.fromJson({
      'id': row.id,
      'noteId': row.noteId,
      'consultationId': row.consultationId,
      'operation': row.operation,
      'note': row.payloadJson,
      'retryCount': row.retryCount,
      'maxRetries': row.maxRetries,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'nextRetryAt': row.nextRetryAt?.toIso8601String(),
      'lastError': row.lastError,
      'isDeadLetter': row.isDeadLetter,
    });
  }
}
