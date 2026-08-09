import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migration from v1 to v2 works without data loss', () async {
    // 1. Create a raw in-memory database
    final rawDb = sqlite3.openInMemory();
    
    // 2. Execute v1 schema manually to simulate an old database
    rawDb.execute('''
      CREATE TABLE doctor_notes (
        note_id TEXT NOT NULL PRIMARY KEY,
        consultation_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        doctor_id TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        status INTEGER NOT NULL,
        extracted_fields TEXT,
        patient_recap TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    
    // Insert some mock v1 data
    rawDb.execute('''
      INSERT INTO doctor_notes (note_id, consultation_id, patient_id, doctor_id, raw_text, status, created_at, updated_at) 
      VALUES ('note-1', 'cons-1', 'pat-1', 'doc-1', 'Test raw text', 0, 10000, 10000);
    ''');
    
    // Set user_version to 1 so drift knows it's upgrading from v1
    rawDb.execute('PRAGMA user_version = 1;');

    // 3. Open the Drift database using the same in-memory connection
    // This will trigger the MigrationStrategy.onUpgrade
    final db = LocalDatabase.connect(NativeDatabase.opened(rawDb));
    
    // 4. Verify data is intact
    final notes = await db.select(db.doctorNotes).get();
    expect(notes.length, 1);
    expect(notes.first.noteId, 'note-1');
    expect(notes.first.rawText, 'Test raw text');
    
    await db.close();
  });

  test('migration from v3 to v4 adds isConflict without data loss', () async {
    final rawDb = sqlite3.openInMemory();

    // Simulate the v3 schema (sync queue WITHOUT the is_conflict column).
    rawDb.execute('''
      CREATE TABLE sync_queue_entries (
        id TEXT NOT NULL PRIMARY KEY,
        note_id TEXT NOT NULL,
        consultation_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 5,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        next_retry_at INTEGER,
        last_error TEXT,
        is_dead_letter INTEGER NOT NULL DEFAULT 0
      );
    ''');
    rawDb.execute('''
      INSERT INTO sync_queue_entries
        (id, note_id, consultation_id, operation, payload_json,
         created_at, updated_at)
      VALUES
        ('q-1', 'n-1', 'c-1', 'update', '{}', 10000, 10000);
    ''');
    rawDb.execute('PRAGMA user_version = 3;');

    final db = LocalDatabase.connect(NativeDatabase.opened(rawDb));

    // Reading triggers the lazy open → v3→v4 migration.
    final rows = await db.select(db.syncQueueEntries).get();
    expect(rows.length, 1);
    expect(rows.first.id, 'q-1');
    expect(rows.first.isConflict, isFalse);

    // v4 adds the is_conflict column; existing rows keep default false.
    final columns = rawDb
        .select('PRAGMA table_info(sync_queue_entries)')
        .map((row) => row['name'] as String)
        .toList();
    expect(columns, contains('is_conflict'));

    await db.close();
  });
}
