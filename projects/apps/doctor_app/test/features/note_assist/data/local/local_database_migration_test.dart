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
}
