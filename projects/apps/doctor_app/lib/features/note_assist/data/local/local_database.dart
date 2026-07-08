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

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'doctor_notes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
