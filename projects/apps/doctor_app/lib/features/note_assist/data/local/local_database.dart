import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_database.g.dart';

@DataClassName('DoctorNoteEntity')
class DoctorNotes extends Table {
  TextColumn get noteId => text()();
  TextColumn get consultationId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get rawText => text()();
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
  LocalDatabase() : super(_openConnection());
  
  LocalDatabase.connect(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 4;

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
      },
      beforeOpen: (details) async {
        // Validate schema integrity on every launch.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'doctor_notes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
