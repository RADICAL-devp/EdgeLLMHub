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

class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, TranscriptEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transcriptIdMeta =
      const VerificationMeta('transcriptId');
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
      'transcript_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, false,
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
  static const VerificationMeta _cleanedTextMeta =
      const VerificationMeta('cleanedText');
  @override
  late final GeneratedColumn<String> cleanedText = GeneratedColumn<String>(
      'cleaned_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastModifiedAtMeta =
      const VerificationMeta('lastModifiedAt');
  @override
  late final GeneratedColumn<DateTime> lastModifiedAt =
      GeneratedColumn<DateTime>('last_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<int> source = GeneratedColumn<int>(
      'source', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        transcriptId,
        consultationId,
        doctorId,
        rawText,
        cleanedText,
        createdAt,
        lastModifiedAt,
        source,
        isSynced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(Insertable<TranscriptEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transcript_id')) {
      context.handle(
          _transcriptIdMeta,
          transcriptId.isAcceptableOrUnknown(
              data['transcript_id']!, _transcriptIdMeta));
    } else if (isInserting) {
      context.missing(_transcriptIdMeta);
    }
    if (data.containsKey('consultation_id')) {
      context.handle(
          _consultationIdMeta,
          consultationId.isAcceptableOrUnknown(
              data['consultation_id']!, _consultationIdMeta));
    } else if (isInserting) {
      context.missing(_consultationIdMeta);
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
    if (data.containsKey('cleaned_text')) {
      context.handle(
          _cleanedTextMeta,
          cleanedText.isAcceptableOrUnknown(
              data['cleaned_text']!, _cleanedTextMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_modified_at')) {
      context.handle(
          _lastModifiedAtMeta,
          lastModifiedAt.isAcceptableOrUnknown(
              data['last_modified_at']!, _lastModifiedAtMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transcriptId};
  @override
  TranscriptEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptEntity(
      transcriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transcript_id'])!,
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      doctorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_id'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      cleanedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cleaned_text']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified_at']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source'])!,
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class TranscriptEntity extends DataClass
    implements Insertable<TranscriptEntity> {
  final String transcriptId;
  final String consultationId;
  final String doctorId;
  final String rawText;
  final String? cleanedText;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final int source;
  final bool isSynced;
  const TranscriptEntity(
      {required this.transcriptId,
      required this.consultationId,
      required this.doctorId,
      required this.rawText,
      this.cleanedText,
      required this.createdAt,
      this.lastModifiedAt,
      required this.source,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transcript_id'] = Variable<String>(transcriptId);
    map['consultation_id'] = Variable<String>(consultationId);
    map['doctor_id'] = Variable<String>(doctorId);
    map['raw_text'] = Variable<String>(rawText);
    if (!nullToAbsent || cleanedText != null) {
      map['cleaned_text'] = Variable<String>(cleanedText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastModifiedAt != null) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt);
    }
    map['source'] = Variable<int>(source);
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      transcriptId: Value(transcriptId),
      consultationId: Value(consultationId),
      doctorId: Value(doctorId),
      rawText: Value(rawText),
      cleanedText: cleanedText == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanedText),
      createdAt: Value(createdAt),
      lastModifiedAt: lastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedAt),
      source: Value(source),
      isSynced: Value(isSynced),
    );
  }

  factory TranscriptEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptEntity(
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      consultationId: serializer.fromJson<String>(json['consultationId']),
      doctorId: serializer.fromJson<String>(json['doctorId']),
      rawText: serializer.fromJson<String>(json['rawText']),
      cleanedText: serializer.fromJson<String?>(json['cleanedText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastModifiedAt: serializer.fromJson<DateTime?>(json['lastModifiedAt']),
      source: serializer.fromJson<int>(json['source']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transcriptId': serializer.toJson<String>(transcriptId),
      'consultationId': serializer.toJson<String>(consultationId),
      'doctorId': serializer.toJson<String>(doctorId),
      'rawText': serializer.toJson<String>(rawText),
      'cleanedText': serializer.toJson<String?>(cleanedText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastModifiedAt': serializer.toJson<DateTime?>(lastModifiedAt),
      'source': serializer.toJson<int>(source),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  TranscriptEntity copyWith(
          {String? transcriptId,
          String? consultationId,
          String? doctorId,
          String? rawText,
          Value<String?> cleanedText = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> lastModifiedAt = const Value.absent(),
          int? source,
          bool? isSynced}) =>
      TranscriptEntity(
        transcriptId: transcriptId ?? this.transcriptId,
        consultationId: consultationId ?? this.consultationId,
        doctorId: doctorId ?? this.doctorId,
        rawText: rawText ?? this.rawText,
        cleanedText: cleanedText.present ? cleanedText.value : this.cleanedText,
        createdAt: createdAt ?? this.createdAt,
        lastModifiedAt:
            lastModifiedAt.present ? lastModifiedAt.value : this.lastModifiedAt,
        source: source ?? this.source,
        isSynced: isSynced ?? this.isSynced,
      );
  TranscriptEntity copyWithCompanion(TranscriptsCompanion data) {
    return TranscriptEntity(
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      doctorId: data.doctorId.present ? data.doctorId.value : this.doctorId,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      cleanedText:
          data.cleanedText.present ? data.cleanedText.value : this.cleanedText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
      source: data.source.present ? data.source.value : this.source,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptEntity(')
          ..write('transcriptId: $transcriptId, ')
          ..write('consultationId: $consultationId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('source: $source, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transcriptId, consultationId, doctorId,
      rawText, cleanedText, createdAt, lastModifiedAt, source, isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptEntity &&
          other.transcriptId == this.transcriptId &&
          other.consultationId == this.consultationId &&
          other.doctorId == this.doctorId &&
          other.rawText == this.rawText &&
          other.cleanedText == this.cleanedText &&
          other.createdAt == this.createdAt &&
          other.lastModifiedAt == this.lastModifiedAt &&
          other.source == this.source &&
          other.isSynced == this.isSynced);
}

class TranscriptsCompanion extends UpdateCompanion<TranscriptEntity> {
  final Value<String> transcriptId;
  final Value<String> consultationId;
  final Value<String> doctorId;
  final Value<String> rawText;
  final Value<String?> cleanedText;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastModifiedAt;
  final Value<int> source;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const TranscriptsCompanion({
    this.transcriptId = const Value.absent(),
    this.consultationId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.cleanedText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    required String transcriptId,
    required String consultationId,
    required String doctorId,
    required String rawText,
    this.cleanedText = const Value.absent(),
    required DateTime createdAt,
    this.lastModifiedAt = const Value.absent(),
    required int source,
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : transcriptId = Value(transcriptId),
        consultationId = Value(consultationId),
        doctorId = Value(doctorId),
        rawText = Value(rawText),
        createdAt = Value(createdAt),
        source = Value(source);
  static Insertable<TranscriptEntity> custom({
    Expression<String>? transcriptId,
    Expression<String>? consultationId,
    Expression<String>? doctorId,
    Expression<String>? rawText,
    Expression<String>? cleanedText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastModifiedAt,
    Expression<int>? source,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (consultationId != null) 'consultation_id': consultationId,
      if (doctorId != null) 'doctor_id': doctorId,
      if (rawText != null) 'raw_text': rawText,
      if (cleanedText != null) 'cleaned_text': cleanedText,
      if (createdAt != null) 'created_at': createdAt,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
      if (source != null) 'source': source,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptsCompanion copyWith(
      {Value<String>? transcriptId,
      Value<String>? consultationId,
      Value<String>? doctorId,
      Value<String>? rawText,
      Value<String?>? cleanedText,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastModifiedAt,
      Value<int>? source,
      Value<bool>? isSynced,
      Value<int>? rowid}) {
    return TranscriptsCompanion(
      transcriptId: transcriptId ?? this.transcriptId,
      consultationId: consultationId ?? this.consultationId,
      doctorId: doctorId ?? this.doctorId,
      rawText: rawText ?? this.rawText,
      cleanedText: cleanedText ?? this.cleanedText,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      source: source ?? this.source,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
    }
    if (consultationId.present) {
      map['consultation_id'] = Variable<String>(consultationId.value);
    }
    if (doctorId.present) {
      map['doctor_id'] = Variable<String>(doctorId.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (cleanedText.present) {
      map['cleaned_text'] = Variable<String>(cleanedText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(source.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsCompanion(')
          ..write('transcriptId: $transcriptId, ')
          ..write('consultationId: $consultationId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('source: $source, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSummariesTable extends TranscriptSummaries
    with TableInfo<$TranscriptSummariesTable, TranscriptSummaryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _doctorIdMeta =
      const VerificationMeta('doctorId');
  @override
  late final GeneratedColumn<String> doctorId = GeneratedColumn<String>(
      'doctor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _structuredSummaryJsonMeta =
      const VerificationMeta('structuredSummaryJson');
  @override
  late final GeneratedColumn<String> structuredSummaryJson =
      GeneratedColumn<String>('structured_summary_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _executiveSummaryMeta =
      const VerificationMeta('executiveSummary');
  @override
  late final GeneratedColumn<String> executiveSummary = GeneratedColumn<String>(
      'executive_summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contextEnrichedSummaryJsonMeta =
      const VerificationMeta('contextEnrichedSummaryJson');
  @override
  late final GeneratedColumn<String> contextEnrichedSummaryJson =
      GeneratedColumn<String>(
          'context_enriched_summary_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doctorNoteJsonMeta =
      const VerificationMeta('doctorNoteJson');
  @override
  late final GeneratedColumn<String> doctorNoteJson = GeneratedColumn<String>(
      'doctor_note_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastModifiedAtMeta =
      const VerificationMeta('lastModifiedAt');
  @override
  late final GeneratedColumn<DateTime> lastModifiedAt =
      GeneratedColumn<DateTime>('last_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isSyncedMeta =
      const VerificationMeta('isSynced');
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
      'is_synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        consultationId,
        doctorId,
        structuredSummaryJson,
        executiveSummary,
        contextEnrichedSummaryJson,
        doctorNoteJson,
        createdAt,
        lastModifiedAt,
        isSynced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_summaries';
  @override
  VerificationContext validateIntegrity(
      Insertable<TranscriptSummaryEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('consultation_id')) {
      context.handle(
          _consultationIdMeta,
          consultationId.isAcceptableOrUnknown(
              data['consultation_id']!, _consultationIdMeta));
    } else if (isInserting) {
      context.missing(_consultationIdMeta);
    }
    if (data.containsKey('doctor_id')) {
      context.handle(_doctorIdMeta,
          doctorId.isAcceptableOrUnknown(data['doctor_id']!, _doctorIdMeta));
    } else if (isInserting) {
      context.missing(_doctorIdMeta);
    }
    if (data.containsKey('structured_summary_json')) {
      context.handle(
          _structuredSummaryJsonMeta,
          structuredSummaryJson.isAcceptableOrUnknown(
              data['structured_summary_json']!, _structuredSummaryJsonMeta));
    }
    if (data.containsKey('executive_summary')) {
      context.handle(
          _executiveSummaryMeta,
          executiveSummary.isAcceptableOrUnknown(
              data['executive_summary']!, _executiveSummaryMeta));
    }
    if (data.containsKey('context_enriched_summary_json')) {
      context.handle(
          _contextEnrichedSummaryJsonMeta,
          contextEnrichedSummaryJson.isAcceptableOrUnknown(
              data['context_enriched_summary_json']!,
              _contextEnrichedSummaryJsonMeta));
    }
    if (data.containsKey('doctor_note_json')) {
      context.handle(
          _doctorNoteJsonMeta,
          doctorNoteJson.isAcceptableOrUnknown(
              data['doctor_note_json']!, _doctorNoteJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_modified_at')) {
      context.handle(
          _lastModifiedAtMeta,
          lastModifiedAt.isAcceptableOrUnknown(
              data['last_modified_at']!, _lastModifiedAtMeta));
    }
    if (data.containsKey('is_synced')) {
      context.handle(_isSyncedMeta,
          isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {consultationId};
  @override
  TranscriptSummaryEntity map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSummaryEntity(
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      doctorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_id'])!,
      structuredSummaryJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}structured_summary_json']),
      executiveSummary: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}executive_summary']),
      contextEnrichedSummaryJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}context_enriched_summary_json']),
      doctorNoteJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}doctor_note_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified_at']),
      isSynced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_synced'])!,
    );
  }

  @override
  $TranscriptSummariesTable createAlias(String alias) {
    return $TranscriptSummariesTable(attachedDatabase, alias);
  }
}

class TranscriptSummaryEntity extends DataClass
    implements Insertable<TranscriptSummaryEntity> {
  final String consultationId;
  final String doctorId;
  final String? structuredSummaryJson;
  final String? executiveSummary;
  final String? contextEnrichedSummaryJson;
  final String? doctorNoteJson;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final bool isSynced;
  const TranscriptSummaryEntity(
      {required this.consultationId,
      required this.doctorId,
      this.structuredSummaryJson,
      this.executiveSummary,
      this.contextEnrichedSummaryJson,
      this.doctorNoteJson,
      required this.createdAt,
      this.lastModifiedAt,
      required this.isSynced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['consultation_id'] = Variable<String>(consultationId);
    map['doctor_id'] = Variable<String>(doctorId);
    if (!nullToAbsent || structuredSummaryJson != null) {
      map['structured_summary_json'] = Variable<String>(structuredSummaryJson);
    }
    if (!nullToAbsent || executiveSummary != null) {
      map['executive_summary'] = Variable<String>(executiveSummary);
    }
    if (!nullToAbsent || contextEnrichedSummaryJson != null) {
      map['context_enriched_summary_json'] =
          Variable<String>(contextEnrichedSummaryJson);
    }
    if (!nullToAbsent || doctorNoteJson != null) {
      map['doctor_note_json'] = Variable<String>(doctorNoteJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastModifiedAt != null) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    return map;
  }

  TranscriptSummariesCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSummariesCompanion(
      consultationId: Value(consultationId),
      doctorId: Value(doctorId),
      structuredSummaryJson: structuredSummaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(structuredSummaryJson),
      executiveSummary: executiveSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(executiveSummary),
      contextEnrichedSummaryJson:
          contextEnrichedSummaryJson == null && nullToAbsent
              ? const Value.absent()
              : Value(contextEnrichedSummaryJson),
      doctorNoteJson: doctorNoteJson == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorNoteJson),
      createdAt: Value(createdAt),
      lastModifiedAt: lastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModifiedAt),
      isSynced: Value(isSynced),
    );
  }

  factory TranscriptSummaryEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSummaryEntity(
      consultationId: serializer.fromJson<String>(json['consultationId']),
      doctorId: serializer.fromJson<String>(json['doctorId']),
      structuredSummaryJson:
          serializer.fromJson<String?>(json['structuredSummaryJson']),
      executiveSummary: serializer.fromJson<String?>(json['executiveSummary']),
      contextEnrichedSummaryJson:
          serializer.fromJson<String?>(json['contextEnrichedSummaryJson']),
      doctorNoteJson: serializer.fromJson<String?>(json['doctorNoteJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastModifiedAt: serializer.fromJson<DateTime?>(json['lastModifiedAt']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'consultationId': serializer.toJson<String>(consultationId),
      'doctorId': serializer.toJson<String>(doctorId),
      'structuredSummaryJson':
          serializer.toJson<String?>(structuredSummaryJson),
      'executiveSummary': serializer.toJson<String?>(executiveSummary),
      'contextEnrichedSummaryJson':
          serializer.toJson<String?>(contextEnrichedSummaryJson),
      'doctorNoteJson': serializer.toJson<String?>(doctorNoteJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastModifiedAt': serializer.toJson<DateTime?>(lastModifiedAt),
      'isSynced': serializer.toJson<bool>(isSynced),
    };
  }

  TranscriptSummaryEntity copyWith(
          {String? consultationId,
          String? doctorId,
          Value<String?> structuredSummaryJson = const Value.absent(),
          Value<String?> executiveSummary = const Value.absent(),
          Value<String?> contextEnrichedSummaryJson = const Value.absent(),
          Value<String?> doctorNoteJson = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> lastModifiedAt = const Value.absent(),
          bool? isSynced}) =>
      TranscriptSummaryEntity(
        consultationId: consultationId ?? this.consultationId,
        doctorId: doctorId ?? this.doctorId,
        structuredSummaryJson: structuredSummaryJson.present
            ? structuredSummaryJson.value
            : this.structuredSummaryJson,
        executiveSummary: executiveSummary.present
            ? executiveSummary.value
            : this.executiveSummary,
        contextEnrichedSummaryJson: contextEnrichedSummaryJson.present
            ? contextEnrichedSummaryJson.value
            : this.contextEnrichedSummaryJson,
        doctorNoteJson:
            doctorNoteJson.present ? doctorNoteJson.value : this.doctorNoteJson,
        createdAt: createdAt ?? this.createdAt,
        lastModifiedAt:
            lastModifiedAt.present ? lastModifiedAt.value : this.lastModifiedAt,
        isSynced: isSynced ?? this.isSynced,
      );
  TranscriptSummaryEntity copyWithCompanion(TranscriptSummariesCompanion data) {
    return TranscriptSummaryEntity(
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      doctorId: data.doctorId.present ? data.doctorId.value : this.doctorId,
      structuredSummaryJson: data.structuredSummaryJson.present
          ? data.structuredSummaryJson.value
          : this.structuredSummaryJson,
      executiveSummary: data.executiveSummary.present
          ? data.executiveSummary.value
          : this.executiveSummary,
      contextEnrichedSummaryJson: data.contextEnrichedSummaryJson.present
          ? data.contextEnrichedSummaryJson.value
          : this.contextEnrichedSummaryJson,
      doctorNoteJson: data.doctorNoteJson.present
          ? data.doctorNoteJson.value
          : this.doctorNoteJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSummaryEntity(')
          ..write('consultationId: $consultationId, ')
          ..write('doctorId: $doctorId, ')
          ..write('structuredSummaryJson: $structuredSummaryJson, ')
          ..write('executiveSummary: $executiveSummary, ')
          ..write('contextEnrichedSummaryJson: $contextEnrichedSummaryJson, ')
          ..write('doctorNoteJson: $doctorNoteJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('isSynced: $isSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      consultationId,
      doctorId,
      structuredSummaryJson,
      executiveSummary,
      contextEnrichedSummaryJson,
      doctorNoteJson,
      createdAt,
      lastModifiedAt,
      isSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSummaryEntity &&
          other.consultationId == this.consultationId &&
          other.doctorId == this.doctorId &&
          other.structuredSummaryJson == this.structuredSummaryJson &&
          other.executiveSummary == this.executiveSummary &&
          other.contextEnrichedSummaryJson == this.contextEnrichedSummaryJson &&
          other.doctorNoteJson == this.doctorNoteJson &&
          other.createdAt == this.createdAt &&
          other.lastModifiedAt == this.lastModifiedAt &&
          other.isSynced == this.isSynced);
}

class TranscriptSummariesCompanion
    extends UpdateCompanion<TranscriptSummaryEntity> {
  final Value<String> consultationId;
  final Value<String> doctorId;
  final Value<String?> structuredSummaryJson;
  final Value<String?> executiveSummary;
  final Value<String?> contextEnrichedSummaryJson;
  final Value<String?> doctorNoteJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastModifiedAt;
  final Value<bool> isSynced;
  final Value<int> rowid;
  const TranscriptSummariesCompanion({
    this.consultationId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.structuredSummaryJson = const Value.absent(),
    this.executiveSummary = const Value.absent(),
    this.contextEnrichedSummaryJson = const Value.absent(),
    this.doctorNoteJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSummariesCompanion.insert({
    required String consultationId,
    required String doctorId,
    this.structuredSummaryJson = const Value.absent(),
    this.executiveSummary = const Value.absent(),
    this.contextEnrichedSummaryJson = const Value.absent(),
    this.doctorNoteJson = const Value.absent(),
    required DateTime createdAt,
    this.lastModifiedAt = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : consultationId = Value(consultationId),
        doctorId = Value(doctorId),
        createdAt = Value(createdAt);
  static Insertable<TranscriptSummaryEntity> custom({
    Expression<String>? consultationId,
    Expression<String>? doctorId,
    Expression<String>? structuredSummaryJson,
    Expression<String>? executiveSummary,
    Expression<String>? contextEnrichedSummaryJson,
    Expression<String>? doctorNoteJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastModifiedAt,
    Expression<bool>? isSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (consultationId != null) 'consultation_id': consultationId,
      if (doctorId != null) 'doctor_id': doctorId,
      if (structuredSummaryJson != null)
        'structured_summary_json': structuredSummaryJson,
      if (executiveSummary != null) 'executive_summary': executiveSummary,
      if (contextEnrichedSummaryJson != null)
        'context_enriched_summary_json': contextEnrichedSummaryJson,
      if (doctorNoteJson != null) 'doctor_note_json': doctorNoteJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
      if (isSynced != null) 'is_synced': isSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSummariesCompanion copyWith(
      {Value<String>? consultationId,
      Value<String>? doctorId,
      Value<String?>? structuredSummaryJson,
      Value<String?>? executiveSummary,
      Value<String?>? contextEnrichedSummaryJson,
      Value<String?>? doctorNoteJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastModifiedAt,
      Value<bool>? isSynced,
      Value<int>? rowid}) {
    return TranscriptSummariesCompanion(
      consultationId: consultationId ?? this.consultationId,
      doctorId: doctorId ?? this.doctorId,
      structuredSummaryJson:
          structuredSummaryJson ?? this.structuredSummaryJson,
      executiveSummary: executiveSummary ?? this.executiveSummary,
      contextEnrichedSummaryJson:
          contextEnrichedSummaryJson ?? this.contextEnrichedSummaryJson,
      doctorNoteJson: doctorNoteJson ?? this.doctorNoteJson,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isSynced: isSynced ?? this.isSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (consultationId.present) {
      map['consultation_id'] = Variable<String>(consultationId.value);
    }
    if (doctorId.present) {
      map['doctor_id'] = Variable<String>(doctorId.value);
    }
    if (structuredSummaryJson.present) {
      map['structured_summary_json'] =
          Variable<String>(structuredSummaryJson.value);
    }
    if (executiveSummary.present) {
      map['executive_summary'] = Variable<String>(executiveSummary.value);
    }
    if (contextEnrichedSummaryJson.present) {
      map['context_enriched_summary_json'] =
          Variable<String>(contextEnrichedSummaryJson.value);
    }
    if (doctorNoteJson.present) {
      map['doctor_note_json'] = Variable<String>(doctorNoteJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSummariesCompanion(')
          ..write('consultationId: $consultationId, ')
          ..write('doctorId: $doctorId, ')
          ..write('structuredSummaryJson: $structuredSummaryJson, ')
          ..write('executiveSummary: $executiveSummary, ')
          ..write('contextEnrichedSummaryJson: $contextEnrichedSummaryJson, ')
          ..write('doctorNoteJson: $doctorNoteJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastModifiedAt: $lastModifiedAt, ')
          ..write('isSynced: $isSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $DoctorNotesTable doctorNotes = $DoctorNotesTable(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $TranscriptSummariesTable transcriptSummaries =
      $TranscriptSummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [doctorNotes, transcripts, transcriptSummaries];
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
typedef $$TranscriptsTableCreateCompanionBuilder = TranscriptsCompanion
    Function({
  required String transcriptId,
  required String consultationId,
  required String doctorId,
  required String rawText,
  Value<String?> cleanedText,
  required DateTime createdAt,
  Value<DateTime?> lastModifiedAt,
  required int source,
  Value<bool> isSynced,
  Value<int> rowid,
});
typedef $$TranscriptsTableUpdateCompanionBuilder = TranscriptsCompanion
    Function({
  Value<String> transcriptId,
  Value<String> consultationId,
  Value<String> doctorId,
  Value<String> rawText,
  Value<String?> cleanedText,
  Value<DateTime> createdAt,
  Value<DateTime?> lastModifiedAt,
  Value<int> source,
  Value<bool> isSynced,
  Value<int> rowid,
});

class $$TranscriptsTableFilterComposer
    extends Composer<_$LocalDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cleanedText => $composableBuilder(
      column: $table.cleanedText, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$LocalDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cleanedText => $composableBuilder(
      column: $table.cleanedText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId, builder: (column) => column);

  GeneratedColumn<String> get consultationId => $composableBuilder(
      column: $table.consultationId, builder: (column) => column);

  GeneratedColumn<String> get doctorId =>
      $composableBuilder(column: $table.doctorId, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get cleanedText => $composableBuilder(
      column: $table.cleanedText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt, builder: (column) => column);

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$TranscriptsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $TranscriptsTable,
    TranscriptEntity,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (
      TranscriptEntity,
      BaseReferences<_$LocalDatabase, $TranscriptsTable, TranscriptEntity>
    ),
    TranscriptEntity,
    PrefetchHooks Function()> {
  $$TranscriptsTableTableManager(_$LocalDatabase db, $TranscriptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> transcriptId = const Value.absent(),
            Value<String> consultationId = const Value.absent(),
            Value<String> doctorId = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<String?> cleanedText = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastModifiedAt = const Value.absent(),
            Value<int> source = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsCompanion(
            transcriptId: transcriptId,
            consultationId: consultationId,
            doctorId: doctorId,
            rawText: rawText,
            cleanedText: cleanedText,
            createdAt: createdAt,
            lastModifiedAt: lastModifiedAt,
            source: source,
            isSynced: isSynced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String transcriptId,
            required String consultationId,
            required String doctorId,
            required String rawText,
            Value<String?> cleanedText = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> lastModifiedAt = const Value.absent(),
            required int source,
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsCompanion.insert(
            transcriptId: transcriptId,
            consultationId: consultationId,
            doctorId: doctorId,
            rawText: rawText,
            cleanedText: cleanedText,
            createdAt: createdAt,
            lastModifiedAt: lastModifiedAt,
            source: source,
            isSynced: isSynced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TranscriptsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $TranscriptsTable,
    TranscriptEntity,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (
      TranscriptEntity,
      BaseReferences<_$LocalDatabase, $TranscriptsTable, TranscriptEntity>
    ),
    TranscriptEntity,
    PrefetchHooks Function()>;
typedef $$TranscriptSummariesTableCreateCompanionBuilder
    = TranscriptSummariesCompanion Function({
  required String consultationId,
  required String doctorId,
  Value<String?> structuredSummaryJson,
  Value<String?> executiveSummary,
  Value<String?> contextEnrichedSummaryJson,
  Value<String?> doctorNoteJson,
  required DateTime createdAt,
  Value<DateTime?> lastModifiedAt,
  Value<bool> isSynced,
  Value<int> rowid,
});
typedef $$TranscriptSummariesTableUpdateCompanionBuilder
    = TranscriptSummariesCompanion Function({
  Value<String> consultationId,
  Value<String> doctorId,
  Value<String?> structuredSummaryJson,
  Value<String?> executiveSummary,
  Value<String?> contextEnrichedSummaryJson,
  Value<String?> doctorNoteJson,
  Value<DateTime> createdAt,
  Value<DateTime?> lastModifiedAt,
  Value<bool> isSynced,
  Value<int> rowid,
});

class $$TranscriptSummariesTableFilterComposer
    extends Composer<_$LocalDatabase, $TranscriptSummariesTable> {
  $$TranscriptSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get structuredSummaryJson => $composableBuilder(
      column: $table.structuredSummaryJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextEnrichedSummaryJson => $composableBuilder(
      column: $table.contextEnrichedSummaryJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorNoteJson => $composableBuilder(
      column: $table.doctorNoteJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnFilters(column));
}

class $$TranscriptSummariesTableOrderingComposer
    extends Composer<_$LocalDatabase, $TranscriptSummariesTable> {
  $$TranscriptSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get structuredSummaryJson => $composableBuilder(
      column: $table.structuredSummaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextEnrichedSummaryJson => $composableBuilder(
      column: $table.contextEnrichedSummaryJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorNoteJson => $composableBuilder(
      column: $table.doctorNoteJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSynced => $composableBuilder(
      column: $table.isSynced, builder: (column) => ColumnOrderings(column));
}

class $$TranscriptSummariesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TranscriptSummariesTable> {
  $$TranscriptSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get consultationId => $composableBuilder(
      column: $table.consultationId, builder: (column) => column);

  GeneratedColumn<String> get doctorId =>
      $composableBuilder(column: $table.doctorId, builder: (column) => column);

  GeneratedColumn<String> get structuredSummaryJson => $composableBuilder(
      column: $table.structuredSummaryJson, builder: (column) => column);

  GeneratedColumn<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary, builder: (column) => column);

  GeneratedColumn<String> get contextEnrichedSummaryJson => $composableBuilder(
      column: $table.contextEnrichedSummaryJson, builder: (column) => column);

  GeneratedColumn<String> get doctorNoteJson => $composableBuilder(
      column: $table.doctorNoteJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModifiedAt => $composableBuilder(
      column: $table.lastModifiedAt, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);
}

class $$TranscriptSummariesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $TranscriptSummariesTable,
    TranscriptSummaryEntity,
    $$TranscriptSummariesTableFilterComposer,
    $$TranscriptSummariesTableOrderingComposer,
    $$TranscriptSummariesTableAnnotationComposer,
    $$TranscriptSummariesTableCreateCompanionBuilder,
    $$TranscriptSummariesTableUpdateCompanionBuilder,
    (
      TranscriptSummaryEntity,
      BaseReferences<_$LocalDatabase, $TranscriptSummariesTable,
          TranscriptSummaryEntity>
    ),
    TranscriptSummaryEntity,
    PrefetchHooks Function()> {
  $$TranscriptSummariesTableTableManager(
      _$LocalDatabase db, $TranscriptSummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSummariesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSummariesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> consultationId = const Value.absent(),
            Value<String> doctorId = const Value.absent(),
            Value<String?> structuredSummaryJson = const Value.absent(),
            Value<String?> executiveSummary = const Value.absent(),
            Value<String?> contextEnrichedSummaryJson = const Value.absent(),
            Value<String?> doctorNoteJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastModifiedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptSummariesCompanion(
            consultationId: consultationId,
            doctorId: doctorId,
            structuredSummaryJson: structuredSummaryJson,
            executiveSummary: executiveSummary,
            contextEnrichedSummaryJson: contextEnrichedSummaryJson,
            doctorNoteJson: doctorNoteJson,
            createdAt: createdAt,
            lastModifiedAt: lastModifiedAt,
            isSynced: isSynced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String consultationId,
            required String doctorId,
            Value<String?> structuredSummaryJson = const Value.absent(),
            Value<String?> executiveSummary = const Value.absent(),
            Value<String?> contextEnrichedSummaryJson = const Value.absent(),
            Value<String?> doctorNoteJson = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> lastModifiedAt = const Value.absent(),
            Value<bool> isSynced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptSummariesCompanion.insert(
            consultationId: consultationId,
            doctorId: doctorId,
            structuredSummaryJson: structuredSummaryJson,
            executiveSummary: executiveSummary,
            contextEnrichedSummaryJson: contextEnrichedSummaryJson,
            doctorNoteJson: doctorNoteJson,
            createdAt: createdAt,
            lastModifiedAt: lastModifiedAt,
            isSynced: isSynced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TranscriptSummariesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $TranscriptSummariesTable,
    TranscriptSummaryEntity,
    $$TranscriptSummariesTableFilterComposer,
    $$TranscriptSummariesTableOrderingComposer,
    $$TranscriptSummariesTableAnnotationComposer,
    $$TranscriptSummariesTableCreateCompanionBuilder,
    $$TranscriptSummariesTableUpdateCompanionBuilder,
    (
      TranscriptSummaryEntity,
      BaseReferences<_$LocalDatabase, $TranscriptSummariesTable,
          TranscriptSummaryEntity>
    ),
    TranscriptSummaryEntity,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$DoctorNotesTableTableManager get doctorNotes =>
      $$DoctorNotesTableTableManager(_db, _db.doctorNotes);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$TranscriptSummariesTableTableManager get transcriptSummaries =>
      $$TranscriptSummariesTableTableManager(_db, _db.transcriptSummaries);
}
