// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $DoctorNotesTable extends DoctorNotes
    with TableInfo<$DoctorNotesTable, DoctorNoteEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DoctorNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
      'note_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _doctorIdMeta =
      const VerificationMeta('doctorId');
  @override
  late final GeneratedColumn<String> doctorId = GeneratedColumn<String>(
      'doctor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _extractedFieldsMeta =
      const VerificationMeta('extractedFields');
  @override
  late final GeneratedColumn<String> extractedFields = GeneratedColumn<String>(
      'extracted_fields', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _patientRecapMeta =
      const VerificationMeta('patientRecap');
  @override
  late final GeneratedColumn<String> patientRecap = GeneratedColumn<String>(
      'patient_recap', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        noteId,
        consultationId,
        patientId,
        doctorId,
        rawText,
        status,
        extractedFields,
        patientRecap,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'doctor_notes';
  @override
  VerificationContext validateIntegrity(Insertable<DoctorNoteEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta,
          noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('consultation_id')) {
      context.handle(
          _consultationIdMeta,
          consultationId.isAcceptableOrUnknown(
              data['consultation_id']!, _consultationIdMeta));
    } else if (isInserting) {
      context.missing(_consultationIdMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(_patientIdMeta,
          patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta));
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('doctor_id')) {
      context.handle(_doctorIdMeta,
          doctorId.isAcceptableOrUnknown(data['doctor_id']!, _doctorIdMeta));
    } else if (isInserting) {
      context.missing(_doctorIdMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('extracted_fields')) {
      context.handle(
          _extractedFieldsMeta,
          extractedFields.isAcceptableOrUnknown(
              data['extracted_fields']!, _extractedFieldsMeta));
    }
    if (data.containsKey('patient_recap')) {
      context.handle(
          _patientRecapMeta,
          patientRecap.isAcceptableOrUnknown(
              data['patient_recap']!, _patientRecapMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId};
  @override
  DoctorNoteEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DoctorNoteEntity(
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id'])!,
      doctorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_id'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      extractedFields: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}extracted_fields']),
      patientRecap: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_recap']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DoctorNotesTable createAlias(String alias) {
    return $DoctorNotesTable(attachedDatabase, alias);
  }
}

class DoctorNoteEntity extends DataClass
    implements Insertable<DoctorNoteEntity> {
  final String noteId;
  final String consultationId;
  final String patientId;
  final String doctorId;
  final String rawText;
  final int status;
  final String? extractedFields;
  final String? patientRecap;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DoctorNoteEntity(
      {required this.noteId,
      required this.consultationId,
      required this.patientId,
      required this.doctorId,
      required this.rawText,
      required this.status,
      this.extractedFields,
      this.patientRecap,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<String>(noteId);
    map['consultation_id'] = Variable<String>(consultationId);
    map['patient_id'] = Variable<String>(patientId);
    map['doctor_id'] = Variable<String>(doctorId);
    map['raw_text'] = Variable<String>(rawText);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || extractedFields != null) {
      map['extracted_fields'] = Variable<String>(extractedFields);
    }
    if (!nullToAbsent || patientRecap != null) {
      map['patient_recap'] = Variable<String>(patientRecap);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DoctorNotesCompanion toCompanion(bool nullToAbsent) {
    return DoctorNotesCompanion(
      noteId: Value(noteId),
      consultationId: Value(consultationId),
      patientId: Value(patientId),
      doctorId: Value(doctorId),
      rawText: Value(rawText),
      status: Value(status),
      extractedFields: extractedFields == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedFields),
      patientRecap: patientRecap == null && nullToAbsent
          ? const Value.absent()
          : Value(patientRecap),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DoctorNoteEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DoctorNoteEntity(
      noteId: serializer.fromJson<String>(json['noteId']),
      consultationId: serializer.fromJson<String>(json['consultationId']),
      patientId: serializer.fromJson<String>(json['patientId']),
      doctorId: serializer.fromJson<String>(json['doctorId']),
      rawText: serializer.fromJson<String>(json['rawText']),
      status: serializer.fromJson<int>(json['status']),
      extractedFields: serializer.fromJson<String?>(json['extractedFields']),
      patientRecap: serializer.fromJson<String?>(json['patientRecap']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<String>(noteId),
      'consultationId': serializer.toJson<String>(consultationId),
      'patientId': serializer.toJson<String>(patientId),
      'doctorId': serializer.toJson<String>(doctorId),
      'rawText': serializer.toJson<String>(rawText),
      'status': serializer.toJson<int>(status),
      'extractedFields': serializer.toJson<String?>(extractedFields),
      'patientRecap': serializer.toJson<String?>(patientRecap),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DoctorNoteEntity copyWith(
          {String? noteId,
          String? consultationId,
          String? patientId,
          String? doctorId,
          String? rawText,
          int? status,
          Value<String?> extractedFields = const Value.absent(),
          Value<String?> patientRecap = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      DoctorNoteEntity(
        noteId: noteId ?? this.noteId,
        consultationId: consultationId ?? this.consultationId,
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        rawText: rawText ?? this.rawText,
        status: status ?? this.status,
        extractedFields: extractedFields.present
            ? extractedFields.value
            : this.extractedFields,
        patientRecap:
            patientRecap.present ? patientRecap.value : this.patientRecap,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DoctorNoteEntity copyWithCompanion(DoctorNotesCompanion data) {
    return DoctorNoteEntity(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      doctorId: data.doctorId.present ? data.doctorId.value : this.doctorId,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      status: data.status.present ? data.status.value : this.status,
      extractedFields: data.extractedFields.present
          ? data.extractedFields.value
          : this.extractedFields,
      patientRecap: data.patientRecap.present
          ? data.patientRecap.value
          : this.patientRecap,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DoctorNoteEntity(')
          ..write('noteId: $noteId, ')
          ..write('consultationId: $consultationId, ')
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('status: $status, ')
          ..write('extractedFields: $extractedFields, ')
          ..write('patientRecap: $patientRecap, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, consultationId, patientId, doctorId,
      rawText, status, extractedFields, patientRecap, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DoctorNoteEntity &&
          other.noteId == this.noteId &&
          other.consultationId == this.consultationId &&
          other.patientId == this.patientId &&
          other.doctorId == this.doctorId &&
          other.rawText == this.rawText &&
          other.status == this.status &&
          other.extractedFields == this.extractedFields &&
          other.patientRecap == this.patientRecap &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DoctorNotesCompanion extends UpdateCompanion<DoctorNoteEntity> {
  final Value<String> noteId;
  final Value<String> consultationId;
  final Value<String> patientId;
  final Value<String> doctorId;
  final Value<String> rawText;
  final Value<int> status;
  final Value<String?> extractedFields;
  final Value<String?> patientRecap;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DoctorNotesCompanion({
    this.noteId = const Value.absent(),
    this.consultationId = const Value.absent(),
    this.patientId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.status = const Value.absent(),
    this.extractedFields = const Value.absent(),
    this.patientRecap = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DoctorNotesCompanion.insert({
    required String noteId,
    required String consultationId,
    required String patientId,
    required String doctorId,
    required String rawText,
    required int status,
    this.extractedFields = const Value.absent(),
    this.patientRecap = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : noteId = Value(noteId),
        consultationId = Value(consultationId),
        patientId = Value(patientId),
        doctorId = Value(doctorId),
        rawText = Value(rawText),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<DoctorNoteEntity> custom({
    Expression<String>? noteId,
    Expression<String>? consultationId,
    Expression<String>? patientId,
    Expression<String>? doctorId,
    Expression<String>? rawText,
    Expression<int>? status,
    Expression<String>? extractedFields,
    Expression<String>? patientRecap,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (consultationId != null) 'consultation_id': consultationId,
      if (patientId != null) 'patient_id': patientId,
      if (doctorId != null) 'doctor_id': doctorId,
      if (rawText != null) 'raw_text': rawText,
      if (status != null) 'status': status,
      if (extractedFields != null) 'extracted_fields': extractedFields,
      if (patientRecap != null) 'patient_recap': patientRecap,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DoctorNotesCompanion copyWith(
      {Value<String>? noteId,
      Value<String>? consultationId,
      Value<String>? patientId,
      Value<String>? doctorId,
      Value<String>? rawText,
      Value<int>? status,
      Value<String?>? extractedFields,
      Value<String?>? patientRecap,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return DoctorNotesCompanion(
      noteId: noteId ?? this.noteId,
      consultationId: consultationId ?? this.consultationId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
      extractedFields: extractedFields ?? this.extractedFields,
      patientRecap: patientRecap ?? this.patientRecap,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (consultationId.present) {
      map['consultation_id'] = Variable<String>(consultationId.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (doctorId.present) {
      map['doctor_id'] = Variable<String>(doctorId.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (extractedFields.present) {
      map['extracted_fields'] = Variable<String>(extractedFields.value);
    }
    if (patientRecap.present) {
      map['patient_recap'] = Variable<String>(patientRecap.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DoctorNotesCompanion(')
          ..write('noteId: $noteId, ')
          ..write('consultationId: $consultationId, ')
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('status: $status, ')
          ..write('extractedFields: $extractedFields, ')
          ..write('patientRecap: $patientRecap, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $DoctorNotesTable doctorNotes = $DoctorNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [doctorNotes];
}

typedef $$DoctorNotesTableCreateCompanionBuilder = DoctorNotesCompanion
    Function({
  required String noteId,
  required String consultationId,
  required String patientId,
  required String doctorId,
  required String rawText,
  required int status,
  Value<String?> extractedFields,
  Value<String?> patientRecap,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DoctorNotesTableUpdateCompanionBuilder = DoctorNotesCompanion
    Function({
  Value<String> noteId,
  Value<String> consultationId,
  Value<String> patientId,
  Value<String> doctorId,
  Value<String> rawText,
  Value<int> status,
  Value<String?> extractedFields,
  Value<String?> patientRecap,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DoctorNotesTableFilterComposer
    extends Composer<_$LocalDatabase, $DoctorNotesTable> {
  $$DoctorNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get patientId => $composableBuilder(
      column: $table.patientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extractedFields => $composableBuilder(
      column: $table.extractedFields,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get patientRecap => $composableBuilder(
      column: $table.patientRecap, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DoctorNotesTableOrderingComposer
    extends Composer<_$LocalDatabase, $DoctorNotesTable> {
  $$DoctorNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get patientId => $composableBuilder(
      column: $table.patientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extractedFields => $composableBuilder(
      column: $table.extractedFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get patientRecap => $composableBuilder(
      column: $table.patientRecap,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DoctorNotesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $DoctorNotesTable> {
  $$DoctorNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get consultationId => $composableBuilder(
      column: $table.consultationId, builder: (column) => column);

  GeneratedColumn<String> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get doctorId =>
      $composableBuilder(column: $table.doctorId, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get extractedFields => $composableBuilder(
      column: $table.extractedFields, builder: (column) => column);

  GeneratedColumn<String> get patientRecap => $composableBuilder(
      column: $table.patientRecap, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DoctorNotesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $DoctorNotesTable,
    DoctorNoteEntity,
    $$DoctorNotesTableFilterComposer,
    $$DoctorNotesTableOrderingComposer,
    $$DoctorNotesTableAnnotationComposer,
    $$DoctorNotesTableCreateCompanionBuilder,
    $$DoctorNotesTableUpdateCompanionBuilder,
    (
      DoctorNoteEntity,
      BaseReferences<_$LocalDatabase, $DoctorNotesTable, DoctorNoteEntity>
    ),
    DoctorNoteEntity,
    PrefetchHooks Function()> {
  $$DoctorNotesTableTableManager(_$LocalDatabase db, $DoctorNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DoctorNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DoctorNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DoctorNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> noteId = const Value.absent(),
            Value<String> consultationId = const Value.absent(),
            Value<String> patientId = const Value.absent(),
            Value<String> doctorId = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<String?> extractedFields = const Value.absent(),
            Value<String?> patientRecap = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DoctorNotesCompanion(
            noteId: noteId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            rawText: rawText,
            status: status,
            extractedFields: extractedFields,
            patientRecap: patientRecap,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String noteId,
            required String consultationId,
            required String patientId,
            required String doctorId,
            required String rawText,
            required int status,
            Value<String?> extractedFields = const Value.absent(),
            Value<String?> patientRecap = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DoctorNotesCompanion.insert(
            noteId: noteId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            rawText: rawText,
            status: status,
            extractedFields: extractedFields,
            patientRecap: patientRecap,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DoctorNotesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $DoctorNotesTable,
    DoctorNoteEntity,
    $$DoctorNotesTableFilterComposer,
    $$DoctorNotesTableOrderingComposer,
    $$DoctorNotesTableAnnotationComposer,
    $$DoctorNotesTableCreateCompanionBuilder,
    $$DoctorNotesTableUpdateCompanionBuilder,
    (
      DoctorNoteEntity,
      BaseReferences<_$LocalDatabase, $DoctorNotesTable, DoctorNoteEntity>
    ),
    DoctorNoteEntity,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$DoctorNotesTableTableManager get doctorNotes =>
      $$DoctorNotesTableTableManager(_db, _db.doctorNotes);
}
