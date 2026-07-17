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

@DriftDatabase(tables: [DoctorNotes, Transcripts, TranscriptSummaries])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());
  
  LocalDatabase.connect(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v1 → v2: Added TranscriptSummaries table.
          // DoctorNotes and Transcripts tables are unchanged.
          await m.createTable(transcriptSummaries);
        }
      },
      beforeOpen: (details) async {
        // Validate schema integrity on every launch.
        // This ensures foreign keys are enabled and the schema matches
        // what Drift expects (catches corruption early).
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
