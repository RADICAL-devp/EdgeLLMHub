import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local note storage.
///
/// Every patient-identifying or clinical text field is stored as an AES-GCM
/// ciphertext produced by `PhiEncryptionService`. Only non-sensitive routing
/// metadata (ids, status, timestamps, language) is stored in plain columns.
/// This means the database file itself is not useful without the key in the
/// platform secure store, and search is performed in memory after decryption.
@DataClassName('ClinicalNoteRow')
class ClinicalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get titleCipher => text()();
  TextColumn get patientNameCipher => text()();
  TextColumn get transcriptCipher => text()();
  TextColumn get cleanedTranscriptCipher => text().nullable()();
  TextColumn get sectionsCipher => text()();
  IntColumn get status => integer()();
  TextColumn get languageCode => text().withDefault(const Constant('en'))();
  BoolColumn get thinkingModeUsed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get modelName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ClinicalNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Injectable constructor used by tests with an in-memory database.
  AppDatabase.connect(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA foreign_keys = ON');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'clinical_notes.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
