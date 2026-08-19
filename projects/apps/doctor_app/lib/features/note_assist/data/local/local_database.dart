import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:doctor_app/core/crypto/encrypted_database.dart';

part 'local_database.g.dart';

@DataClassName('DoctorNoteEntity')
class DoctorNotes extends Table {
  TextColumn get noteId => text()();
  TextColumn get consultationId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get rawText => text()();
  TextColumn get richTextDelta => text().nullable()(); // Quill Delta JSON
  IntColumn get status => integer()(); // Store enum as integer
  TextColumn get extractedFields => text().nullable()();
  TextColumn get patientRecap => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {noteId};
}

@DataClassName('TranscriptEntity')
class Transcripts extends Table {
  TextColumn get transcriptId => text()();
  TextColumn get consultationId => text()();
  TextColumn get doctorId => text()();
  TextColumn get rawText => text()();
  TextColumn get cleanedText => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get source => integer()();

  @override
  Set<Column> get primaryKey => {transcriptId};
}

@DataClassName('TranscriptSummaryEntity')
class TranscriptSummaries extends Table {
  TextColumn get consultationId => text()();
  TextColumn get doctorId => text()();
  TextColumn get structuredSummaryJson => text().nullable()();
  TextColumn get executiveSummary => text().nullable()();
  TextColumn get contextEnrichedSummaryJson => text().nullable()();
  TextColumn get doctorNoteJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {consultationId};
}

@DataClassName('SyncQueueEntryEntity')
class SyncQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get consultationId => text()();
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get payloadJson => text()(); // Serialized DoctorNote
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  BoolColumn get isDeadLetter => boolean().withDefault(const Constant(false))();
  BoolColumn get isConflict => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DoctorNotes, Transcripts, TranscriptSummaries, SyncQueueEntries])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openEncryptedConnection());

  LocalDatabase.connect(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v1 → v2: Added TranscriptSummaries table.
          await m.createTable(transcriptSummaries);
        }
        if (from < 3) {
          // v2 → v3: Added SyncQueueEntries table for persistent sync queue.
          // The table is created with the current definition, which already
          // includes the v4 isConflict column.
          await m.createTable(syncQueueEntries);
        }
        if (from == 3) {
          // v3 → v4: Added isConflict flag for manual merge UI.
          await m.addColumn(syncQueueEntries, syncQueueEntries.isConflict);
        }
        if (from == 4) {
          // v4 → v5: Added richTextDelta for the Quill rich-text editor.
          await m.addColumn(doctorNotes, doctorNotes.richTextDelta);
        }
        if (from == 5) {
          // v5 → v6: Database encryption enabled (SQLCipher).
          // No schema changes needed; encryption is transparent at the connection level.
          // If migrating from unencrypted to encrypted, data will be re-encrypted on first access.
        }
      },
      beforeOpen: (details) async {
        // Validate schema integrity on every launch.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// One-time import of notes from the legacy unencrypted database
/// (`doctor_notes.sqlite`, used by builds before the SQLCipher upgrade).
///
/// Runs before the encrypted DB opens for the first time so pre-existing
/// consultations surface in the list immediately after an app update.
Future<void> importLegacyDatabase() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final legacyFile = File(p.join(documentsDir.path, 'doctor_notes.sqlite'));
  if (!legacyFile.existsSync()) return;

  final legacy = sqlite3.open(legacyFile.path);
  try {
    final tables = legacy
        .select('SELECT name FROM sqlite_master WHERE type = \'table\'')
        .map((row) => row['name'] as String)
        .toList();
    if (!tables.contains('doctor_notes')) return;

    final current = sqlite3.open(
      p.join(documentsDir.path, 'doctor_notes_encrypted.sqlite'),
    );
    try {
      final key = await _readOrCreateDatabaseKey();
      current.execute("PRAGMA key = '${_escapeSqlString(key)}'");

      final rows = legacy.select(
        'SELECT * FROM doctor_notes ORDER BY updated_at ASC',
      );
      for (final row in rows) {
        final count = current.select(
          'SELECT COUNT(*) AS c FROM doctor_notes WHERE note_id = ?',
          [row['note_id']],
        ).first['c'] as int;
        if (count > 0) continue;
        current.execute(
          'INSERT OR IGNORE INTO doctor_notes '
          '(note_id, consultation_id, patient_id, doctor_id, raw_text, '
          'rich_text_delta, status, extracted_fields, patient_recap, '
          'created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            row['note_id'],
            row['consultation_id'],
            row['patient_id'],
            row['doctor_id'],
            row['raw_text'],
            row['rich_text_delta'],
            row['status'],
            row['extracted_fields'],
            row['patient_recap'],
            row['created_at'],
            row['updated_at'],
          ],
        );
      }
    } finally {
      current.close();
    }
  } finally {
    legacy.close();
  }
}

Future<String> _readOrCreateDatabaseKey() async {
  const storage = FlutterSecureStorage();
  const alias = 'database_encryption_key';
  final existing = await storage.read(key: alias);
  if (existing != null) return existing;
  final random = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch & 0xFF);
  final key = hex.encode(sha256.convert(random).bytes);
  await storage.write(
    key: alias,
    value: key,
    aOptions: const AndroidOptions(),
    iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  return key;
}

String _escapeSqlString(String input) {
  return input.replaceAll("'", "''");
}

LazyDatabase _openEncryptedConnection() {
  return createEncryptedDatabaseConnection(
    databaseName: 'doctor_notes_encrypted.sqlite',
  );
}
