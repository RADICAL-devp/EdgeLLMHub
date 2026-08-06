# Phase 2.1 Execution Plan: Backend Persistence (Drift/SQLite)

**Objective:** Replace in-memory repositories with Drift/SQLite persistence in `clinical-intelligence-dart`.

**Dependencies:** None (can run parallel to Phase 1.1)

---

## Task 2.1.1: Update `pubspec.yaml`

**File:** `projects/apps/clinical-intelligence-dart/pubspec.yaml` (MODIFY)

```yaml
dependencies:
  dart_frog: ^1.2.6
  uuid: ^4.5.1
  http: ^1.2.2
  meta: ^1.15.0
  drift: ^2.18.0              # NEW
  sqlite3: ^2.4.0             # NEW
  path: ^1.9.0                # NEW

dev_dependencies:
  test: ^1.25.8
  mocktail: ^1.0.4
  very_good_analysis: ^6.0.0
  drift_dev: ^2.18.0          # NEW
  build_runner: ^2.4.0        # NEW
```

Run: `dart pub get` then `dart run build_runner build --delete-conflicting-outputs`

---

## Task 2.1.2: Create Drift Database Schema

**File:** `projects/apps/clinical-intelligence-dart/lib/infrastructure/persistence/clinical_database.dart` (NEW)

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// Summary bundles table
class SummaryBundles extends Table {
  TextColumn get consultationId => text().withLength(min: 1, max: 64)();
  TextColumn get transcriptId => text()();
  TextColumn get structuredMedicalSummary => text().map(const StructuredSummaryConverter())();
  TextColumn get executiveSummary => text().nullable()();
  TextColumn get doctorNote => text().nullable()();
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
  TextColumn get outcome => text()(); // success, failure, error
  TextColumn get metadataJson => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

/// Type converters
class StructuredSummaryConverter extends TypeConverter<StructuredSummary, String> {
  const StructuredSummaryConverter();
  @override
  StructuredSummary fromSql(String fromDb) => StructuredSummary.fromJson(jsonDecode(fromDb));
  @override
  String toSql(StructuredSummary value) => jsonEncode(value.toJson());
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) => jsonDecode(fromDb).cast<String>();
  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();
  @override
  Map<String, dynamic> fromSql(String fromDb) => jsonDecode(fromDb).cast<String, dynamic>();
  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

/// Database class
@DriftDatabase(tables: [Transcripts, SummaryBundles, ProcessedOutputs, AuditLogs])
class ClinicalDatabase extends _$ClinicalDatabase {
  ClinicalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'clinical_intelligence.sqlite'));
      return NativeDatabase(file);
    });
  }
}
```

---

## Task 2.1.3: Implement Drift Transcript Repository

**File:** `projects/apps/clinical-intelligence-dart/lib/infrastructure/persistence/drift_transcript_repository.dart` (NEW)

```dart
import 'package:clinical_intelligence_dart/application/ports/transcript_repository.dart';
import 'package:clinical_intelligence_dart/core/models/consultation_transcript.dart';
import 'clinical_database.dart';

class DriftTranscriptRepository implements TranscriptRepository {
  final ClinicalDatabase _db;

  DriftTranscriptRepository(this._db);

  @override
  Future<void> save(ConsultationTranscript transcript) async {
    await _db.into(_db.transcripts).insertOnConflictUpdate(
      TranscriptsCompanion.insert(
        transcriptId: transcript.transcriptId,
        consultationId: transcript.consultationId,
        patientId: Value(transcript.patientId),
        doctorId: Value(transcript.doctorId),
        sleepLabId: Value(transcript.sleepLabId),
        transcriptText: transcript.transcriptText,
        consultationMode: transcript.consultationMode.toJson(),
        createdAt: transcript.createdAt,
      ),
    );
  }

  @override
  Future<ConsultationTranscript?> findByConsultationId(String consultationId) async {
    final row = await (_db.select(_db.transcripts)
          ..where((t) => t.consultationId.equals(consultationId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toTranscript(row) : null;
  }

  @override
  Future<List<ConsultationTranscript>> findAll() async {
    final rows = await _db.select(_db.transcripts).get();
    return rows.map(_toTranscript).toList();
  }

  @override
  Future<void> delete(String transcriptId) async {
    await (_db.delete(_db.transcripts)
          ..where((t) => t.transcriptId.equals(transcriptId)))
        .go();
  }

  ConsultationTranscript _toTranscript(Transcript row) {
    return ConsultationTranscript(
      transcriptId: row.transcriptId,
      consultationId: row.consultationId,
      patientId: row.patientId,
      doctorId: row.doctorId,
      sleepLabId: row.sleepLabId,
      transcriptText: row.transcriptText,
      consultationMode: ConsultationMode.tryParse(row.consultationMode) ?? ConsultationMode.inPerson,
      createdAt: row.createdAt,
    );
  }
}
```

---

## Task 2.1.4: Implement Drift Summary Repository

**File:** `projects/apps/clinical-intelligence-dart/lib/infrastructure/persistence/drift_summary_repository.dart` (NEW)

```dart
import 'package:clinical_intelligence_dart/application/ports/transcript_summary_repository.dart';
import 'package:clinical_intelligence_dart/core/models/transcript_summary_bundle.dart';
import 'clinical_database.dart';

class DriftSummaryRepository implements TranscriptSummaryRepository {
  final ClinicalDatabase _db;

  DriftSummaryRepository(this._db);

  @override
  Future<void> save(TranscriptSummaryBundle bundle) async {
    await _db.into(_db.summaryBundles).insertOnConflictUpdate(
      SummaryBundlesCompanion.insert(
        consultationId: bundle.consultationId,
        transcriptId: bundle.transcriptId,
        structuredMedicalSummary: bundle.structuredMedicalSummary,
        executiveSummary: Value(bundle.executiveSummary),
        doctorNote: Value(bundle.doctorNote),
        generatedAt: DateTime.parse(bundle.generatedAt),
        consultationMode: bundle.consultationMode.toJson(),
      ),
    );
  }

  @override
  Future<TranscriptSummaryBundle?> findByConsultationId(String consultationId) async {
    final row = await (_db.select(_db.summaryBundles)
          ..where((s) => s.consultationId.equals(consultationId))
          ..limit(1))
        .getSingleOrNull();
    return row != null ? _toBundle(row) : null;
  }

  @override
  Future<void> delete(String consultationId) async {
    await (_db.delete(_db.summaryBundles)
          ..where((s) => s.consultationId.equals(consultationId)))
        .go();
  }

  TranscriptSummaryBundle _toBundle(SummaryBundle row) {
    return TranscriptSummaryBundle(
      consultationId: row.consultationId,
      transcriptId: row.transcriptId,
      structuredMedicalSummary: row.structuredMedicalSummary,
      executiveSummary: row.executiveSummary,
      doctorNote: row.doctorNote,
      generatedAt: row.generatedAt.toIso8601String(),
      consultationMode: ConsultationMode.tryParse(row.consultationMode) ?? ConsultationMode.inPerson,
    );
  }
}
```

---

## Task 2.1.5: Implement Drift Processed Output Repository

**File:** `projects/apps/clinical-intelligence-dart/lib/infrastructure/persistence/drift_processed_output_repository.dart` (NEW)

```dart
import 'package:clinical_intelligence_dart/application/ports/processed_output_repository.dart';
import 'clinical_database.dart';

class DriftProcessedOutputRepository implements ProcessedOutputRepository {
  final ClinicalDatabase _db;

  DriftProcessedOutputRepository(this._db);

  @override
  Future<void> save({
    required String id,
    required String? consultationId,
    required String processingMode,
    required String? source,
    required String inputText,
    required String processedText,
    required List<String> warnings,
    required DateTime generatedAt,
    required Map<String, dynamic> metadata,
  }) async {
    await _db.into(_db.processedOutputs).insertOnConflictUpdate(
      ProcessedOutputsCompanion.insert(
        id: id,
        consultationId: Value(consultationId),
        processingMode: processingMode,
        source: Value(source),
        inputText: inputText,
        processedText: processedText,
        warnings: warnings,
        generatedAt: generatedAt,
        metadata: metadata,
      ),
    );
  }

  @override
  Future<List<ProcessedOutputRecord>> findByConsultationId(String consultationId) async {
    final rows = await (_db.select(_db.processedOutputs)
          ..where((p) => p.consultationId.equals(consultationId))
          ..orderBy([(p) => OrderingTerm.desc(p.generatedAt)]))
        .get();
    return rows.map(_toRecord).toList();
  }

  ProcessedOutputRecord _toRecord(ProcessedOutput row) {
    return ProcessedOutputRecord(
      id: row.id,
      consultationId: row.consultationId,
      processingMode: row.processingMode,
      source: row.source,
      inputText: row.inputText,
      processedText: row.processedText,
      warnings: row.warnings,
      generatedAt: row.generatedAt,
      metadata: row.metadata,
    );
  }
}
```

---

## Task 2.1.6: Update `_middleware.dart`

**File:** `projects/apps/clinical-intelligence-dart/routes/_middleware.dart` (MODIFY)

```dart
// ... imports
import 'package:clinical_intelligence_dart/infrastructure/persistence/clinical_database.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_transcript_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_summary_repository.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/drift_processed_output_repository.dart';

// In middleware():
final database = ClinicalDatabase();
final transcriptRepository = DriftTranscriptRepository(database);
final summaryRepository = DriftSummaryRepository(database);
final processedOutputRepository = DriftProcessedOutputRepository(database);

// Replace InMemory*Repository with Drift implementations
// Add database.close() in a shutdown handler
```

---

## Task 2.1.7: Run Build Runner & Verify

```bash
cd projects/apps/clinical-intelligence-dart
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
dart test
```

---

## Success Criteria

| Check | Pass Condition |
|-------|----------------|
| `dart pub get` | No dependency conflicts |
| `build_runner` | Generates `.g.dart` files without errors |
| `dart analyze` | Zero errors, zero warnings |
| `dart test` | All existing tests pass |
| Persistence | Data survives server restart |
| Schema | Tables created with correct indices |

---

## Estimated Time

| Step | Duration |
|------|----------|
| pubspec update + deps | 5 min |
| Database schema | 20 min |
| 3 Repositories | 30 min |
| Middleware update | 10 min |
| Build runner + verify | 10 min |
| **Total** | **~1.5 hours** |

---

## Next Steps (Phase 2.2+)

After Phase 2.1 complete:
- 2.2: Authentication (JWT RS256)
- 2.3: Audit logging + PHI redaction
- 2.4: AES-GCM encryption at rest
- 2.5: SQLite-vec vector store (embedding dim = 960)
- 2.6: API completion (FULL_BUNDLE, regenerate route, OpenAPI, load test)