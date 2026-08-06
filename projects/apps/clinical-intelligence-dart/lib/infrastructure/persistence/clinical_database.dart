import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

part 'clinical_database.g.dart';

/// Transcripts table
class Transcripts extends Table {
  TextColumn get transcriptId => text()();
  TextColumn get consultationId => text().withLength(min: 1, max: 64)();
  TextColumn get patientId => text().nullable()();
  TextColumn get doctorId => text().nullable()();
  TextColumn get sleepLabId => text().nullable()();
  TextColumn get transcriptText => text()();
  TextColumn get consultationMode => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {transcriptId};
}

/// Summary bundles table - store complex objects as JSON text
class SummaryBundles extends Table {
  TextColumn get consultationId => text().withLength(min: 1, max: 64)();
  TextColumn get transcriptId => text()();
  TextColumn get structuredMedicalSummary => text()(); // JSON string
  TextColumn get executiveSummary => text().nullable()(); // JSON string
  TextColumn get doctorNote => text().nullable()(); // JSON string
  DateTimeColumn get generatedAt => dateTime()();
  TextColumn get consultationMode => text()();

  @override
  Set<Column> get primaryKey => {consultationId};
}

/// Processed outputs table (API Family A)
class ProcessedOutputs extends Table {
  TextColumn get id => text()();
  TextColumn get consultationId => text().nullable()();
  TextColumn get processingMode => text()();
  TextColumn get source => text().nullable()();
  TextColumn get inputText => text()();
  TextColumn get processedText => text()();
  TextColumn get warnings => text().map(const StringListConverter())();
  DateTimeColumn get generatedAt => dateTime()();
  TextColumn get metadata => text().map(const JsonMapConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Audit logs table
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get correlationId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get clinicId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get resource => text()();
  TextColumn get resourceId => text().nullable()();
  TextColumn get outcome => text()();
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  // Don't override primaryKey when using autoIncrement()
}

/// Type converters
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) => List<String>.from(json.decode(fromDb) as List);
  @override
  String toSql(List<String> value) => json.encode(value);
}

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();
  @override
  Map<String, dynamic> fromSql(String fromDb) => Map<String, dynamic>.from(json.decode(fromDb) as Map);
  @override
  String toSql(Map<String, dynamic> value) => json.encode(value);
}

/// Database class
@DriftDatabase(tables: [Transcripts, SummaryBundles, ProcessedOutputs, AuditLogs])
class ClinicalDatabase extends _$ClinicalDatabase {
  ClinicalDatabase([String? dbPath]) : super(_openConnection(dbPath));

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection([String? dbPath]) {
    return LazyDatabase(() async {
      final file = File(dbPath ?? p.join(Directory.current.path, 'clinical_intelligence.sqlite'));
      return NativeDatabase(file);
    });
  }
}
