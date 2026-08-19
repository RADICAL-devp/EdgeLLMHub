// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clinical_database.dart';

// ignore_for_file: type=lint
class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, Transcript> {
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
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doctorIdMeta =
      const VerificationMeta('doctorId');
  @override
  late final GeneratedColumn<String> doctorId = GeneratedColumn<String>(
      'doctor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sleepLabIdMeta =
      const VerificationMeta('sleepLabId');
  @override
  late final GeneratedColumn<String> sleepLabId = GeneratedColumn<String>(
      'sleep_lab_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transcriptTextMeta =
      const VerificationMeta('transcriptText');
  @override
  late final GeneratedColumn<String> transcriptText = GeneratedColumn<String>(
      'transcript_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consultationModeMeta =
      const VerificationMeta('consultationMode');
  @override
  late final GeneratedColumn<String> consultationMode = GeneratedColumn<String>(
      'consultation_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        transcriptId,
        consultationId,
        patientId,
        doctorId,
        sleepLabId,
        transcriptText,
        consultationMode,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(Insertable<Transcript> instance,
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
    if (data.containsKey('patient_id')) {
      context.handle(_patientIdMeta,
          patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta));
    }
    if (data.containsKey('doctor_id')) {
      context.handle(_doctorIdMeta,
          doctorId.isAcceptableOrUnknown(data['doctor_id']!, _doctorIdMeta));
    }
    if (data.containsKey('sleep_lab_id')) {
      context.handle(
          _sleepLabIdMeta,
          sleepLabId.isAcceptableOrUnknown(
              data['sleep_lab_id']!, _sleepLabIdMeta));
    }
    if (data.containsKey('transcript_text')) {
      context.handle(
          _transcriptTextMeta,
          transcriptText.isAcceptableOrUnknown(
              data['transcript_text']!, _transcriptTextMeta));
    } else if (isInserting) {
      context.missing(_transcriptTextMeta);
    }
    if (data.containsKey('consultation_mode')) {
      context.handle(
          _consultationModeMeta,
          consultationMode.isAcceptableOrUnknown(
              data['consultation_mode']!, _consultationModeMeta));
    } else if (isInserting) {
      context.missing(_consultationModeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transcriptId};
  @override
  Transcript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transcript(
      transcriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transcript_id'])!,
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id']),
      doctorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_id']),
      sleepLabId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sleep_lab_id']),
      transcriptText: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}transcript_text'])!,
      consultationMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_mode'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }
}

class Transcript extends DataClass implements Insertable<Transcript> {
  final String transcriptId;
  final String consultationId;
  final String? patientId;
  final String? doctorId;
  final String? sleepLabId;
  final String transcriptText;
  final String consultationMode;
  final DateTime createdAt;
  const Transcript(
      {required this.transcriptId,
      required this.consultationId,
      this.patientId,
      this.doctorId,
      this.sleepLabId,
      required this.transcriptText,
      required this.consultationMode,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transcript_id'] = Variable<String>(transcriptId);
    map['consultation_id'] = Variable<String>(consultationId);
    if (!nullToAbsent || patientId != null) {
      map['patient_id'] = Variable<String>(patientId);
    }
    if (!nullToAbsent || doctorId != null) {
      map['doctor_id'] = Variable<String>(doctorId);
    }
    if (!nullToAbsent || sleepLabId != null) {
      map['sleep_lab_id'] = Variable<String>(sleepLabId);
    }
    map['transcript_text'] = Variable<String>(transcriptText);
    map['consultation_mode'] = Variable<String>(consultationMode);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      transcriptId: Value(transcriptId),
      consultationId: Value(consultationId),
      patientId: patientId == null && nullToAbsent
          ? const Value.absent()
          : Value(patientId),
      doctorId: doctorId == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorId),
      sleepLabId: sleepLabId == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepLabId),
      transcriptText: Value(transcriptText),
      consultationMode: Value(consultationMode),
      createdAt: Value(createdAt),
    );
  }

  factory Transcript.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transcript(
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      consultationId: serializer.fromJson<String>(json['consultationId']),
      patientId: serializer.fromJson<String?>(json['patientId']),
      doctorId: serializer.fromJson<String?>(json['doctorId']),
      sleepLabId: serializer.fromJson<String?>(json['sleepLabId']),
      transcriptText: serializer.fromJson<String>(json['transcriptText']),
      consultationMode: serializer.fromJson<String>(json['consultationMode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transcriptId': serializer.toJson<String>(transcriptId),
      'consultationId': serializer.toJson<String>(consultationId),
      'patientId': serializer.toJson<String?>(patientId),
      'doctorId': serializer.toJson<String?>(doctorId),
      'sleepLabId': serializer.toJson<String?>(sleepLabId),
      'transcriptText': serializer.toJson<String>(transcriptText),
      'consultationMode': serializer.toJson<String>(consultationMode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Transcript copyWith(
          {String? transcriptId,
          String? consultationId,
          Value<String?> patientId = const Value.absent(),
          Value<String?> doctorId = const Value.absent(),
          Value<String?> sleepLabId = const Value.absent(),
          String? transcriptText,
          String? consultationMode,
          DateTime? createdAt}) =>
      Transcript(
        transcriptId: transcriptId ?? this.transcriptId,
        consultationId: consultationId ?? this.consultationId,
        patientId: patientId.present ? patientId.value : this.patientId,
        doctorId: doctorId.present ? doctorId.value : this.doctorId,
        sleepLabId: sleepLabId.present ? sleepLabId.value : this.sleepLabId,
        transcriptText: transcriptText ?? this.transcriptText,
        consultationMode: consultationMode ?? this.consultationMode,
        createdAt: createdAt ?? this.createdAt,
      );
  Transcript copyWithCompanion(TranscriptsCompanion data) {
    return Transcript(
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      doctorId: data.doctorId.present ? data.doctorId.value : this.doctorId,
      sleepLabId:
          data.sleepLabId.present ? data.sleepLabId.value : this.sleepLabId,
      transcriptText: data.transcriptText.present
          ? data.transcriptText.value
          : this.transcriptText,
      consultationMode: data.consultationMode.present
          ? data.consultationMode.value
          : this.consultationMode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transcript(')
          ..write('transcriptId: $transcriptId, ')
          ..write('consultationId: $consultationId, ')
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('sleepLabId: $sleepLabId, ')
          ..write('transcriptText: $transcriptText, ')
          ..write('consultationMode: $consultationMode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transcriptId, consultationId, patientId,
      doctorId, sleepLabId, transcriptText, consultationMode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.transcriptId == this.transcriptId &&
          other.consultationId == this.consultationId &&
          other.patientId == this.patientId &&
          other.doctorId == this.doctorId &&
          other.sleepLabId == this.sleepLabId &&
          other.transcriptText == this.transcriptText &&
          other.consultationMode == this.consultationMode &&
          other.createdAt == this.createdAt);
}

class TranscriptsCompanion extends UpdateCompanion<Transcript> {
  final Value<String> transcriptId;
  final Value<String> consultationId;
  final Value<String?> patientId;
  final Value<String?> doctorId;
  final Value<String?> sleepLabId;
  final Value<String> transcriptText;
  final Value<String> consultationMode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TranscriptsCompanion({
    this.transcriptId = const Value.absent(),
    this.consultationId = const Value.absent(),
    this.patientId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.sleepLabId = const Value.absent(),
    this.transcriptText = const Value.absent(),
    this.consultationMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    required String transcriptId,
    required String consultationId,
    this.patientId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.sleepLabId = const Value.absent(),
    required String transcriptText,
    required String consultationMode,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : transcriptId = Value(transcriptId),
        consultationId = Value(consultationId),
        transcriptText = Value(transcriptText),
        consultationMode = Value(consultationMode),
        createdAt = Value(createdAt);
  static Insertable<Transcript> custom({
    Expression<String>? transcriptId,
    Expression<String>? consultationId,
    Expression<String>? patientId,
    Expression<String>? doctorId,
    Expression<String>? sleepLabId,
    Expression<String>? transcriptText,
    Expression<String>? consultationMode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (consultationId != null) 'consultation_id': consultationId,
      if (patientId != null) 'patient_id': patientId,
      if (doctorId != null) 'doctor_id': doctorId,
      if (sleepLabId != null) 'sleep_lab_id': sleepLabId,
      if (transcriptText != null) 'transcript_text': transcriptText,
      if (consultationMode != null) 'consultation_mode': consultationMode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptsCompanion copyWith(
      {Value<String>? transcriptId,
      Value<String>? consultationId,
      Value<String?>? patientId,
      Value<String?>? doctorId,
      Value<String?>? sleepLabId,
      Value<String>? transcriptText,
      Value<String>? consultationMode,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return TranscriptsCompanion(
      transcriptId: transcriptId ?? this.transcriptId,
      consultationId: consultationId ?? this.consultationId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      sleepLabId: sleepLabId ?? this.sleepLabId,
      transcriptText: transcriptText ?? this.transcriptText,
      consultationMode: consultationMode ?? this.consultationMode,
      createdAt: createdAt ?? this.createdAt,
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
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (doctorId.present) {
      map['doctor_id'] = Variable<String>(doctorId.value);
    }
    if (sleepLabId.present) {
      map['sleep_lab_id'] = Variable<String>(sleepLabId.value);
    }
    if (transcriptText.present) {
      map['transcript_text'] = Variable<String>(transcriptText.value);
    }
    if (consultationMode.present) {
      map['consultation_mode'] = Variable<String>(consultationMode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('sleepLabId: $sleepLabId, ')
          ..write('transcriptText: $transcriptText, ')
          ..write('consultationMode: $consultationMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SummaryBundlesTable extends SummaryBundles
    with TableInfo<$SummaryBundlesTable, SummaryBundle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SummaryBundlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _transcriptIdMeta =
      const VerificationMeta('transcriptId');
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
      'transcript_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _structuredMedicalSummaryMeta =
      const VerificationMeta('structuredMedicalSummary');
  @override
  late final GeneratedColumn<String> structuredMedicalSummary =
      GeneratedColumn<String>('structured_medical_summary', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _executiveSummaryMeta =
      const VerificationMeta('executiveSummary');
  @override
  late final GeneratedColumn<String> executiveSummary = GeneratedColumn<String>(
      'executive_summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doctorNoteMeta =
      const VerificationMeta('doctorNote');
  @override
  late final GeneratedColumn<String> doctorNote = GeneratedColumn<String>(
      'doctor_note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _generatedAtMeta =
      const VerificationMeta('generatedAt');
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
      'generated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _consultationModeMeta =
      const VerificationMeta('consultationMode');
  @override
  late final GeneratedColumn<String> consultationMode = GeneratedColumn<String>(
      'consultation_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        consultationId,
        transcriptId,
        structuredMedicalSummary,
        executiveSummary,
        doctorNote,
        generatedAt,
        consultationMode
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'summary_bundles';
  @override
  VerificationContext validateIntegrity(Insertable<SummaryBundle> instance,
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
    if (data.containsKey('transcript_id')) {
      context.handle(
          _transcriptIdMeta,
          transcriptId.isAcceptableOrUnknown(
              data['transcript_id']!, _transcriptIdMeta));
    } else if (isInserting) {
      context.missing(_transcriptIdMeta);
    }
    if (data.containsKey('structured_medical_summary')) {
      context.handle(
          _structuredMedicalSummaryMeta,
          structuredMedicalSummary.isAcceptableOrUnknown(
              data['structured_medical_summary']!,
              _structuredMedicalSummaryMeta));
    } else if (isInserting) {
      context.missing(_structuredMedicalSummaryMeta);
    }
    if (data.containsKey('executive_summary')) {
      context.handle(
          _executiveSummaryMeta,
          executiveSummary.isAcceptableOrUnknown(
              data['executive_summary']!, _executiveSummaryMeta));
    }
    if (data.containsKey('doctor_note')) {
      context.handle(
          _doctorNoteMeta,
          doctorNote.isAcceptableOrUnknown(
              data['doctor_note']!, _doctorNoteMeta));
    }
    if (data.containsKey('generated_at')) {
      context.handle(
          _generatedAtMeta,
          generatedAt.isAcceptableOrUnknown(
              data['generated_at']!, _generatedAtMeta));
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('consultation_mode')) {
      context.handle(
          _consultationModeMeta,
          consultationMode.isAcceptableOrUnknown(
              data['consultation_mode']!, _consultationModeMeta));
    } else if (isInserting) {
      context.missing(_consultationModeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {consultationId};
  @override
  SummaryBundle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SummaryBundle(
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      transcriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transcript_id'])!,
      structuredMedicalSummary: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}structured_medical_summary'])!,
      executiveSummary: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}executive_summary']),
      doctorNote: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_note']),
      generatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}generated_at'])!,
      consultationMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_mode'])!,
    );
  }

  @override
  $SummaryBundlesTable createAlias(String alias) {
    return $SummaryBundlesTable(attachedDatabase, alias);
  }
}

class SummaryBundle extends DataClass implements Insertable<SummaryBundle> {
  final String consultationId;
  final String transcriptId;
  final String structuredMedicalSummary;
  final String? executiveSummary;
  final String? doctorNote;
  final DateTime generatedAt;
  final String consultationMode;
  const SummaryBundle(
      {required this.consultationId,
      required this.transcriptId,
      required this.structuredMedicalSummary,
      this.executiveSummary,
      this.doctorNote,
      required this.generatedAt,
      required this.consultationMode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['consultation_id'] = Variable<String>(consultationId);
    map['transcript_id'] = Variable<String>(transcriptId);
    map['structured_medical_summary'] =
        Variable<String>(structuredMedicalSummary);
    if (!nullToAbsent || executiveSummary != null) {
      map['executive_summary'] = Variable<String>(executiveSummary);
    }
    if (!nullToAbsent || doctorNote != null) {
      map['doctor_note'] = Variable<String>(doctorNote);
    }
    map['generated_at'] = Variable<DateTime>(generatedAt);
    map['consultation_mode'] = Variable<String>(consultationMode);
    return map;
  }

  SummaryBundlesCompanion toCompanion(bool nullToAbsent) {
    return SummaryBundlesCompanion(
      consultationId: Value(consultationId),
      transcriptId: Value(transcriptId),
      structuredMedicalSummary: Value(structuredMedicalSummary),
      executiveSummary: executiveSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(executiveSummary),
      doctorNote: doctorNote == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorNote),
      generatedAt: Value(generatedAt),
      consultationMode: Value(consultationMode),
    );
  }

  factory SummaryBundle.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SummaryBundle(
      consultationId: serializer.fromJson<String>(json['consultationId']),
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      structuredMedicalSummary:
          serializer.fromJson<String>(json['structuredMedicalSummary']),
      executiveSummary: serializer.fromJson<String?>(json['executiveSummary']),
      doctorNote: serializer.fromJson<String?>(json['doctorNote']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      consultationMode: serializer.fromJson<String>(json['consultationMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'consultationId': serializer.toJson<String>(consultationId),
      'transcriptId': serializer.toJson<String>(transcriptId),
      'structuredMedicalSummary':
          serializer.toJson<String>(structuredMedicalSummary),
      'executiveSummary': serializer.toJson<String?>(executiveSummary),
      'doctorNote': serializer.toJson<String?>(doctorNote),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'consultationMode': serializer.toJson<String>(consultationMode),
    };
  }

  SummaryBundle copyWith(
          {String? consultationId,
          String? transcriptId,
          String? structuredMedicalSummary,
          Value<String?> executiveSummary = const Value.absent(),
          Value<String?> doctorNote = const Value.absent(),
          DateTime? generatedAt,
          String? consultationMode}) =>
      SummaryBundle(
        consultationId: consultationId ?? this.consultationId,
        transcriptId: transcriptId ?? this.transcriptId,
        structuredMedicalSummary:
            structuredMedicalSummary ?? this.structuredMedicalSummary,
        executiveSummary: executiveSummary.present
            ? executiveSummary.value
            : this.executiveSummary,
        doctorNote: doctorNote.present ? doctorNote.value : this.doctorNote,
        generatedAt: generatedAt ?? this.generatedAt,
        consultationMode: consultationMode ?? this.consultationMode,
      );
  SummaryBundle copyWithCompanion(SummaryBundlesCompanion data) {
    return SummaryBundle(
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      structuredMedicalSummary: data.structuredMedicalSummary.present
          ? data.structuredMedicalSummary.value
          : this.structuredMedicalSummary,
      executiveSummary: data.executiveSummary.present
          ? data.executiveSummary.value
          : this.executiveSummary,
      doctorNote:
          data.doctorNote.present ? data.doctorNote.value : this.doctorNote,
      generatedAt:
          data.generatedAt.present ? data.generatedAt.value : this.generatedAt,
      consultationMode: data.consultationMode.present
          ? data.consultationMode.value
          : this.consultationMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SummaryBundle(')
          ..write('consultationId: $consultationId, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('structuredMedicalSummary: $structuredMedicalSummary, ')
          ..write('executiveSummary: $executiveSummary, ')
          ..write('doctorNote: $doctorNote, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('consultationMode: $consultationMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      consultationId,
      transcriptId,
      structuredMedicalSummary,
      executiveSummary,
      doctorNote,
      generatedAt,
      consultationMode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SummaryBundle &&
          other.consultationId == this.consultationId &&
          other.transcriptId == this.transcriptId &&
          other.structuredMedicalSummary == this.structuredMedicalSummary &&
          other.executiveSummary == this.executiveSummary &&
          other.doctorNote == this.doctorNote &&
          other.generatedAt == this.generatedAt &&
          other.consultationMode == this.consultationMode);
}

class SummaryBundlesCompanion extends UpdateCompanion<SummaryBundle> {
  final Value<String> consultationId;
  final Value<String> transcriptId;
  final Value<String> structuredMedicalSummary;
  final Value<String?> executiveSummary;
  final Value<String?> doctorNote;
  final Value<DateTime> generatedAt;
  final Value<String> consultationMode;
  final Value<int> rowid;
  const SummaryBundlesCompanion({
    this.consultationId = const Value.absent(),
    this.transcriptId = const Value.absent(),
    this.structuredMedicalSummary = const Value.absent(),
    this.executiveSummary = const Value.absent(),
    this.doctorNote = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.consultationMode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SummaryBundlesCompanion.insert({
    required String consultationId,
    required String transcriptId,
    required String structuredMedicalSummary,
    this.executiveSummary = const Value.absent(),
    this.doctorNote = const Value.absent(),
    required DateTime generatedAt,
    required String consultationMode,
    this.rowid = const Value.absent(),
  })  : consultationId = Value(consultationId),
        transcriptId = Value(transcriptId),
        structuredMedicalSummary = Value(structuredMedicalSummary),
        generatedAt = Value(generatedAt),
        consultationMode = Value(consultationMode);
  static Insertable<SummaryBundle> custom({
    Expression<String>? consultationId,
    Expression<String>? transcriptId,
    Expression<String>? structuredMedicalSummary,
    Expression<String>? executiveSummary,
    Expression<String>? doctorNote,
    Expression<DateTime>? generatedAt,
    Expression<String>? consultationMode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (consultationId != null) 'consultation_id': consultationId,
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (structuredMedicalSummary != null)
        'structured_medical_summary': structuredMedicalSummary,
      if (executiveSummary != null) 'executive_summary': executiveSummary,
      if (doctorNote != null) 'doctor_note': doctorNote,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (consultationMode != null) 'consultation_mode': consultationMode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SummaryBundlesCompanion copyWith(
      {Value<String>? consultationId,
      Value<String>? transcriptId,
      Value<String>? structuredMedicalSummary,
      Value<String?>? executiveSummary,
      Value<String?>? doctorNote,
      Value<DateTime>? generatedAt,
      Value<String>? consultationMode,
      Value<int>? rowid}) {
    return SummaryBundlesCompanion(
      consultationId: consultationId ?? this.consultationId,
      transcriptId: transcriptId ?? this.transcriptId,
      structuredMedicalSummary:
          structuredMedicalSummary ?? this.structuredMedicalSummary,
      executiveSummary: executiveSummary ?? this.executiveSummary,
      doctorNote: doctorNote ?? this.doctorNote,
      generatedAt: generatedAt ?? this.generatedAt,
      consultationMode: consultationMode ?? this.consultationMode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (consultationId.present) {
      map['consultation_id'] = Variable<String>(consultationId.value);
    }
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
    }
    if (structuredMedicalSummary.present) {
      map['structured_medical_summary'] =
          Variable<String>(structuredMedicalSummary.value);
    }
    if (executiveSummary.present) {
      map['executive_summary'] = Variable<String>(executiveSummary.value);
    }
    if (doctorNote.present) {
      map['doctor_note'] = Variable<String>(doctorNote.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (consultationMode.present) {
      map['consultation_mode'] = Variable<String>(consultationMode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SummaryBundlesCompanion(')
          ..write('consultationId: $consultationId, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('structuredMedicalSummary: $structuredMedicalSummary, ')
          ..write('executiveSummary: $executiveSummary, ')
          ..write('doctorNote: $doctorNote, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('consultationMode: $consultationMode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProcessedOutputsTable extends ProcessedOutputs
    with TableInfo<$ProcessedOutputsTable, ProcessedOutput> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessedOutputsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _processingModeMeta =
      const VerificationMeta('processingMode');
  @override
  late final GeneratedColumn<String> processingMode = GeneratedColumn<String>(
      'processing_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _inputTextMeta =
      const VerificationMeta('inputText');
  @override
  late final GeneratedColumn<String> inputText = GeneratedColumn<String>(
      'input_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _processedTextMeta =
      const VerificationMeta('processedText');
  @override
  late final GeneratedColumn<String> processedText = GeneratedColumn<String>(
      'processed_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> warnings =
      GeneratedColumn<String>('warnings', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $ProcessedOutputsTable.$converterwarnings);
  static const VerificationMeta _generatedAtMeta =
      const VerificationMeta('generatedAt');
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
      'generated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
      metadata = GeneratedColumn<String>('metadata', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<Map<String, dynamic>>(
              $ProcessedOutputsTable.$convertermetadata);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        consultationId,
        processingMode,
        source,
        inputText,
        processedText,
        warnings,
        generatedAt,
        metadata
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processed_outputs';
  @override
  VerificationContext validateIntegrity(Insertable<ProcessedOutput> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('consultation_id')) {
      context.handle(
          _consultationIdMeta,
          consultationId.isAcceptableOrUnknown(
              data['consultation_id']!, _consultationIdMeta));
    }
    if (data.containsKey('processing_mode')) {
      context.handle(
          _processingModeMeta,
          processingMode.isAcceptableOrUnknown(
              data['processing_mode']!, _processingModeMeta));
    } else if (isInserting) {
      context.missing(_processingModeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('input_text')) {
      context.handle(_inputTextMeta,
          inputText.isAcceptableOrUnknown(data['input_text']!, _inputTextMeta));
    } else if (isInserting) {
      context.missing(_inputTextMeta);
    }
    if (data.containsKey('processed_text')) {
      context.handle(
          _processedTextMeta,
          processedText.isAcceptableOrUnknown(
              data['processed_text']!, _processedTextMeta));
    } else if (isInserting) {
      context.missing(_processedTextMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
          _generatedAtMeta,
          generatedAt.isAcceptableOrUnknown(
              data['generated_at']!, _generatedAtMeta));
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessedOutput map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessedOutput(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      consultationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consultation_id']),
      processingMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}processing_mode'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source']),
      inputText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}input_text'])!,
      processedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}processed_text'])!,
      warnings: $ProcessedOutputsTable.$converterwarnings.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.string, data['${effectivePrefix}warnings'])!),
      generatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}generated_at'])!,
      metadata: $ProcessedOutputsTable.$convertermetadata.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.string, data['${effectivePrefix}metadata'])!),
    );
  }

  @override
  $ProcessedOutputsTable createAlias(String alias) {
    return $ProcessedOutputsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterwarnings =
      const StringListConverter();
  static TypeConverter<Map<String, dynamic>, String> $convertermetadata =
      const JsonMapConverter();
}

class ProcessedOutput extends DataClass implements Insertable<ProcessedOutput> {
  final String id;
  final String? consultationId;
  final String processingMode;
  final String? source;
  final String inputText;
  final String processedText;
  final List<String> warnings;
  final DateTime generatedAt;
  final Map<String, dynamic> metadata;
  const ProcessedOutput(
      {required this.id,
      this.consultationId,
      required this.processingMode,
      this.source,
      required this.inputText,
      required this.processedText,
      required this.warnings,
      required this.generatedAt,
      required this.metadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || consultationId != null) {
      map['consultation_id'] = Variable<String>(consultationId);
    }
    map['processing_mode'] = Variable<String>(processingMode);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['input_text'] = Variable<String>(inputText);
    map['processed_text'] = Variable<String>(processedText);
    {
      map['warnings'] = Variable<String>(
          $ProcessedOutputsTable.$converterwarnings.toSql(warnings));
    }
    map['generated_at'] = Variable<DateTime>(generatedAt);
    {
      map['metadata'] = Variable<String>(
          $ProcessedOutputsTable.$convertermetadata.toSql(metadata));
    }
    return map;
  }

  ProcessedOutputsCompanion toCompanion(bool nullToAbsent) {
    return ProcessedOutputsCompanion(
      id: Value(id),
      consultationId: consultationId == null && nullToAbsent
          ? const Value.absent()
          : Value(consultationId),
      processingMode: Value(processingMode),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      inputText: Value(inputText),
      processedText: Value(processedText),
      warnings: Value(warnings),
      generatedAt: Value(generatedAt),
      metadata: Value(metadata),
    );
  }

  factory ProcessedOutput.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessedOutput(
      id: serializer.fromJson<String>(json['id']),
      consultationId: serializer.fromJson<String?>(json['consultationId']),
      processingMode: serializer.fromJson<String>(json['processingMode']),
      source: serializer.fromJson<String?>(json['source']),
      inputText: serializer.fromJson<String>(json['inputText']),
      processedText: serializer.fromJson<String>(json['processedText']),
      warnings: serializer.fromJson<List<String>>(json['warnings']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      metadata: serializer.fromJson<Map<String, dynamic>>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'consultationId': serializer.toJson<String?>(consultationId),
      'processingMode': serializer.toJson<String>(processingMode),
      'source': serializer.toJson<String?>(source),
      'inputText': serializer.toJson<String>(inputText),
      'processedText': serializer.toJson<String>(processedText),
      'warnings': serializer.toJson<List<String>>(warnings),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'metadata': serializer.toJson<Map<String, dynamic>>(metadata),
    };
  }

  ProcessedOutput copyWith(
          {String? id,
          Value<String?> consultationId = const Value.absent(),
          String? processingMode,
          Value<String?> source = const Value.absent(),
          String? inputText,
          String? processedText,
          List<String>? warnings,
          DateTime? generatedAt,
          Map<String, dynamic>? metadata}) =>
      ProcessedOutput(
        id: id ?? this.id,
        consultationId:
            consultationId.present ? consultationId.value : this.consultationId,
        processingMode: processingMode ?? this.processingMode,
        source: source.present ? source.value : this.source,
        inputText: inputText ?? this.inputText,
        processedText: processedText ?? this.processedText,
        warnings: warnings ?? this.warnings,
        generatedAt: generatedAt ?? this.generatedAt,
        metadata: metadata ?? this.metadata,
      );
  ProcessedOutput copyWithCompanion(ProcessedOutputsCompanion data) {
    return ProcessedOutput(
      id: data.id.present ? data.id.value : this.id,
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      processingMode: data.processingMode.present
          ? data.processingMode.value
          : this.processingMode,
      source: data.source.present ? data.source.value : this.source,
      inputText: data.inputText.present ? data.inputText.value : this.inputText,
      processedText: data.processedText.present
          ? data.processedText.value
          : this.processedText,
      warnings: data.warnings.present ? data.warnings.value : this.warnings,
      generatedAt:
          data.generatedAt.present ? data.generatedAt.value : this.generatedAt,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedOutput(')
          ..write('id: $id, ')
          ..write('consultationId: $consultationId, ')
          ..write('processingMode: $processingMode, ')
          ..write('source: $source, ')
          ..write('inputText: $inputText, ')
          ..write('processedText: $processedText, ')
          ..write('warnings: $warnings, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, consultationId, processingMode, source,
      inputText, processedText, warnings, generatedAt, metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessedOutput &&
          other.id == this.id &&
          other.consultationId == this.consultationId &&
          other.processingMode == this.processingMode &&
          other.source == this.source &&
          other.inputText == this.inputText &&
          other.processedText == this.processedText &&
          other.warnings == this.warnings &&
          other.generatedAt == this.generatedAt &&
          other.metadata == this.metadata);
}

class ProcessedOutputsCompanion extends UpdateCompanion<ProcessedOutput> {
  final Value<String> id;
  final Value<String?> consultationId;
  final Value<String> processingMode;
  final Value<String?> source;
  final Value<String> inputText;
  final Value<String> processedText;
  final Value<List<String>> warnings;
  final Value<DateTime> generatedAt;
  final Value<Map<String, dynamic>> metadata;
  final Value<int> rowid;
  const ProcessedOutputsCompanion({
    this.id = const Value.absent(),
    this.consultationId = const Value.absent(),
    this.processingMode = const Value.absent(),
    this.source = const Value.absent(),
    this.inputText = const Value.absent(),
    this.processedText = const Value.absent(),
    this.warnings = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessedOutputsCompanion.insert({
    required String id,
    this.consultationId = const Value.absent(),
    required String processingMode,
    this.source = const Value.absent(),
    required String inputText,
    required String processedText,
    required List<String> warnings,
    required DateTime generatedAt,
    required Map<String, dynamic> metadata,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        processingMode = Value(processingMode),
        inputText = Value(inputText),
        processedText = Value(processedText),
        warnings = Value(warnings),
        generatedAt = Value(generatedAt),
        metadata = Value(metadata);
  static Insertable<ProcessedOutput> custom({
    Expression<String>? id,
    Expression<String>? consultationId,
    Expression<String>? processingMode,
    Expression<String>? source,
    Expression<String>? inputText,
    Expression<String>? processedText,
    Expression<String>? warnings,
    Expression<DateTime>? generatedAt,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (consultationId != null) 'consultation_id': consultationId,
      if (processingMode != null) 'processing_mode': processingMode,
      if (source != null) 'source': source,
      if (inputText != null) 'input_text': inputText,
      if (processedText != null) 'processed_text': processedText,
      if (warnings != null) 'warnings': warnings,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessedOutputsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? consultationId,
      Value<String>? processingMode,
      Value<String?>? source,
      Value<String>? inputText,
      Value<String>? processedText,
      Value<List<String>>? warnings,
      Value<DateTime>? generatedAt,
      Value<Map<String, dynamic>>? metadata,
      Value<int>? rowid}) {
    return ProcessedOutputsCompanion(
      id: id ?? this.id,
      consultationId: consultationId ?? this.consultationId,
      processingMode: processingMode ?? this.processingMode,
      source: source ?? this.source,
      inputText: inputText ?? this.inputText,
      processedText: processedText ?? this.processedText,
      warnings: warnings ?? this.warnings,
      generatedAt: generatedAt ?? this.generatedAt,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (consultationId.present) {
      map['consultation_id'] = Variable<String>(consultationId.value);
    }
    if (processingMode.present) {
      map['processing_mode'] = Variable<String>(processingMode.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (inputText.present) {
      map['input_text'] = Variable<String>(inputText.value);
    }
    if (processedText.present) {
      map['processed_text'] = Variable<String>(processedText.value);
    }
    if (warnings.present) {
      map['warnings'] = Variable<String>(
          $ProcessedOutputsTable.$converterwarnings.toSql(warnings.value));
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(
          $ProcessedOutputsTable.$convertermetadata.toSql(metadata.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessedOutputsCompanion(')
          ..write('id: $id, ')
          ..write('consultationId: $consultationId, ')
          ..write('processingMode: $processingMode, ')
          ..write('source: $source, ')
          ..write('inputText: $inputText, ')
          ..write('processedText: $processedText, ')
          ..write('warnings: $warnings, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _correlationIdMeta =
      const VerificationMeta('correlationId');
  @override
  late final GeneratedColumn<String> correlationId = GeneratedColumn<String>(
      'correlation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clinicIdMeta =
      const VerificationMeta('clinicId');
  @override
  late final GeneratedColumn<String> clinicId = GeneratedColumn<String>(
      'clinic_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceMeta =
      const VerificationMeta('resource');
  @override
  late final GeneratedColumn<String> resource = GeneratedColumn<String>(
      'resource', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceIdMeta =
      const VerificationMeta('resourceId');
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        correlationId,
        userId,
        clinicId,
        action,
        resource,
        resourceId,
        outcome,
        metadataJson,
        timestamp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(Insertable<AuditLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('correlation_id')) {
      context.handle(
          _correlationIdMeta,
          correlationId.isAcceptableOrUnknown(
              data['correlation_id']!, _correlationIdMeta));
    } else if (isInserting) {
      context.missing(_correlationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('clinic_id')) {
      context.handle(_clinicIdMeta,
          clinicId.isAcceptableOrUnknown(data['clinic_id']!, _clinicIdMeta));
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('resource')) {
      context.handle(_resourceMeta,
          resource.isAcceptableOrUnknown(data['resource']!, _resourceMeta));
    } else if (isInserting) {
      context.missing(_resourceMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
          _resourceIdMeta,
          resourceId.isAcceptableOrUnknown(
              data['resource_id']!, _resourceIdMeta));
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      correlationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}correlation_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      clinicId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clinic_id']),
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      resource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource'])!,
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id']),
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final int id;
  final String correlationId;
  final String? userId;
  final String? clinicId;
  final String action;
  final String resource;
  final String? resourceId;
  final String outcome;
  final String? metadataJson;
  final DateTime timestamp;
  const AuditLog(
      {required this.id,
      required this.correlationId,
      this.userId,
      this.clinicId,
      required this.action,
      required this.resource,
      this.resourceId,
      required this.outcome,
      this.metadataJson,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['correlation_id'] = Variable<String>(correlationId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || clinicId != null) {
      map['clinic_id'] = Variable<String>(clinicId);
    }
    map['action'] = Variable<String>(action);
    map['resource'] = Variable<String>(resource);
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      correlationId: Value(correlationId),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      clinicId: clinicId == null && nullToAbsent
          ? const Value.absent()
          : Value(clinicId),
      action: Value(action),
      resource: Value(resource),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      outcome: Value(outcome),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      timestamp: Value(timestamp),
    );
  }

  factory AuditLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<int>(json['id']),
      correlationId: serializer.fromJson<String>(json['correlationId']),
      userId: serializer.fromJson<String?>(json['userId']),
      clinicId: serializer.fromJson<String?>(json['clinicId']),
      action: serializer.fromJson<String>(json['action']),
      resource: serializer.fromJson<String>(json['resource']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      outcome: serializer.fromJson<String>(json['outcome']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'correlationId': serializer.toJson<String>(correlationId),
      'userId': serializer.toJson<String?>(userId),
      'clinicId': serializer.toJson<String?>(clinicId),
      'action': serializer.toJson<String>(action),
      'resource': serializer.toJson<String>(resource),
      'resourceId': serializer.toJson<String?>(resourceId),
      'outcome': serializer.toJson<String>(outcome),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  AuditLog copyWith(
          {int? id,
          String? correlationId,
          Value<String?> userId = const Value.absent(),
          Value<String?> clinicId = const Value.absent(),
          String? action,
          String? resource,
          Value<String?> resourceId = const Value.absent(),
          String? outcome,
          Value<String?> metadataJson = const Value.absent(),
          DateTime? timestamp}) =>
      AuditLog(
        id: id ?? this.id,
        correlationId: correlationId ?? this.correlationId,
        userId: userId.present ? userId.value : this.userId,
        clinicId: clinicId.present ? clinicId.value : this.clinicId,
        action: action ?? this.action,
        resource: resource ?? this.resource,
        resourceId: resourceId.present ? resourceId.value : this.resourceId,
        outcome: outcome ?? this.outcome,
        metadataJson:
            metadataJson.present ? metadataJson.value : this.metadataJson,
        timestamp: timestamp ?? this.timestamp,
      );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      correlationId: data.correlationId.present
          ? data.correlationId.value
          : this.correlationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      clinicId: data.clinicId.present ? data.clinicId.value : this.clinicId,
      action: data.action.present ? data.action.value : this.action,
      resource: data.resource.present ? data.resource.value : this.resource,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('correlationId: $correlationId, ')
          ..write('userId: $userId, ')
          ..write('clinicId: $clinicId, ')
          ..write('action: $action, ')
          ..write('resource: $resource, ')
          ..write('resourceId: $resourceId, ')
          ..write('outcome: $outcome, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, correlationId, userId, clinicId, action,
      resource, resourceId, outcome, metadataJson, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.correlationId == this.correlationId &&
          other.userId == this.userId &&
          other.clinicId == this.clinicId &&
          other.action == this.action &&
          other.resource == this.resource &&
          other.resourceId == this.resourceId &&
          other.outcome == this.outcome &&
          other.metadataJson == this.metadataJson &&
          other.timestamp == this.timestamp);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<int> id;
  final Value<String> correlationId;
  final Value<String?> userId;
  final Value<String?> clinicId;
  final Value<String> action;
  final Value<String> resource;
  final Value<String?> resourceId;
  final Value<String> outcome;
  final Value<String?> metadataJson;
  final Value<DateTime> timestamp;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.correlationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.clinicId = const Value.absent(),
    this.action = const Value.absent(),
    this.resource = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.outcome = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    required String correlationId,
    this.userId = const Value.absent(),
    this.clinicId = const Value.absent(),
    required String action,
    required String resource,
    this.resourceId = const Value.absent(),
    required String outcome,
    this.metadataJson = const Value.absent(),
    required DateTime timestamp,
  })  : correlationId = Value(correlationId),
        action = Value(action),
        resource = Value(resource),
        outcome = Value(outcome),
        timestamp = Value(timestamp);
  static Insertable<AuditLog> custom({
    Expression<int>? id,
    Expression<String>? correlationId,
    Expression<String>? userId,
    Expression<String>? clinicId,
    Expression<String>? action,
    Expression<String>? resource,
    Expression<String>? resourceId,
    Expression<String>? outcome,
    Expression<String>? metadataJson,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (correlationId != null) 'correlation_id': correlationId,
      if (userId != null) 'user_id': userId,
      if (clinicId != null) 'clinic_id': clinicId,
      if (action != null) 'action': action,
      if (resource != null) 'resource': resource,
      if (resourceId != null) 'resource_id': resourceId,
      if (outcome != null) 'outcome': outcome,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  AuditLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? correlationId,
      Value<String?>? userId,
      Value<String?>? clinicId,
      Value<String>? action,
      Value<String>? resource,
      Value<String?>? resourceId,
      Value<String>? outcome,
      Value<String?>? metadataJson,
      Value<DateTime>? timestamp}) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      correlationId: correlationId ?? this.correlationId,
      userId: userId ?? this.userId,
      clinicId: clinicId ?? this.clinicId,
      action: action ?? this.action,
      resource: resource ?? this.resource,
      resourceId: resourceId ?? this.resourceId,
      outcome: outcome ?? this.outcome,
      metadataJson: metadataJson ?? this.metadataJson,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (correlationId.present) {
      map['correlation_id'] = Variable<String>(correlationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (clinicId.present) {
      map['clinic_id'] = Variable<String>(clinicId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (resource.present) {
      map['resource'] = Variable<String>(resource.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('correlationId: $correlationId, ')
          ..write('userId: $userId, ')
          ..write('clinicId: $clinicId, ')
          ..write('action: $action, ')
          ..write('resource: $resource, ')
          ..write('resourceId: $resourceId, ')
          ..write('outcome: $outcome, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $SyncedDoctorNotesTable extends SyncedDoctorNotes
    with TableInfo<$SyncedDoctorNotesTable, SyncedDoctorNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncedDoctorNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
      'note_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 128),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _consultationIdMeta =
      const VerificationMeta('consultationId');
  @override
  late final GeneratedColumn<String> consultationId = GeneratedColumn<String>(
      'consultation_id', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 64),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _patientIdMeta =
      const VerificationMeta('patientId');
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
      'patient_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doctorIdMeta =
      const VerificationMeta('doctorId');
  @override
  late final GeneratedColumn<String> doctorId = GeneratedColumn<String>(
      'doctor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _richTextDeltaMeta =
      const VerificationMeta('richTextDelta');
  @override
  late final GeneratedColumn<String> richTextDelta = GeneratedColumn<String>(
      'rich_text_delta', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
        richTextDelta,
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
  static const String $name = 'synced_doctor_notes';
  @override
  VerificationContext validateIntegrity(Insertable<SyncedDoctorNote> instance,
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
    }
    if (data.containsKey('doctor_id')) {
      context.handle(_doctorIdMeta,
          doctorId.isAcceptableOrUnknown(data['doctor_id']!, _doctorIdMeta));
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('rich_text_delta')) {
      context.handle(
          _richTextDeltaMeta,
          richTextDelta.isAcceptableOrUnknown(
              data['rich_text_delta']!, _richTextDeltaMeta));
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
  SyncedDoctorNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncedDoctorNote(
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      consultationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}consultation_id'])!,
      patientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patient_id']),
      doctorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doctor_id']),
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      richTextDelta: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rich_text_delta']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
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
  $SyncedDoctorNotesTable createAlias(String alias) {
    return $SyncedDoctorNotesTable(attachedDatabase, alias);
  }
}

class SyncedDoctorNote extends DataClass
    implements Insertable<SyncedDoctorNote> {
  final String noteId;
  final String consultationId;
  final String? patientId;
  final String? doctorId;
  final String rawText;
  final String? richTextDelta;
  final String status;
  final String? extractedFields;
  final String? patientRecap;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncedDoctorNote(
      {required this.noteId,
      required this.consultationId,
      this.patientId,
      this.doctorId,
      required this.rawText,
      this.richTextDelta,
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
    if (!nullToAbsent || patientId != null) {
      map['patient_id'] = Variable<String>(patientId);
    }
    if (!nullToAbsent || doctorId != null) {
      map['doctor_id'] = Variable<String>(doctorId);
    }
    map['raw_text'] = Variable<String>(rawText);
    if (!nullToAbsent || richTextDelta != null) {
      map['rich_text_delta'] = Variable<String>(richTextDelta);
    }
    map['status'] = Variable<String>(status);
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

  SyncedDoctorNotesCompanion toCompanion(bool nullToAbsent) {
    return SyncedDoctorNotesCompanion(
      noteId: Value(noteId),
      consultationId: Value(consultationId),
      patientId: patientId == null && nullToAbsent
          ? const Value.absent()
          : Value(patientId),
      doctorId: doctorId == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorId),
      rawText: Value(rawText),
      richTextDelta: richTextDelta == null && nullToAbsent
          ? const Value.absent()
          : Value(richTextDelta),
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

  factory SyncedDoctorNote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncedDoctorNote(
      noteId: serializer.fromJson<String>(json['noteId']),
      consultationId: serializer.fromJson<String>(json['consultationId']),
      patientId: serializer.fromJson<String?>(json['patientId']),
      doctorId: serializer.fromJson<String?>(json['doctorId']),
      rawText: serializer.fromJson<String>(json['rawText']),
      richTextDelta: serializer.fromJson<String?>(json['richTextDelta']),
      status: serializer.fromJson<String>(json['status']),
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
      'patientId': serializer.toJson<String?>(patientId),
      'doctorId': serializer.toJson<String?>(doctorId),
      'rawText': serializer.toJson<String>(rawText),
      'richTextDelta': serializer.toJson<String?>(richTextDelta),
      'status': serializer.toJson<String>(status),
      'extractedFields': serializer.toJson<String?>(extractedFields),
      'patientRecap': serializer.toJson<String?>(patientRecap),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncedDoctorNote copyWith(
          {String? noteId,
          String? consultationId,
          Value<String?> patientId = const Value.absent(),
          Value<String?> doctorId = const Value.absent(),
          String? rawText,
          Value<String?> richTextDelta = const Value.absent(),
          String? status,
          Value<String?> extractedFields = const Value.absent(),
          Value<String?> patientRecap = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SyncedDoctorNote(
        noteId: noteId ?? this.noteId,
        consultationId: consultationId ?? this.consultationId,
        patientId: patientId.present ? patientId.value : this.patientId,
        doctorId: doctorId.present ? doctorId.value : this.doctorId,
        rawText: rawText ?? this.rawText,
        richTextDelta:
            richTextDelta.present ? richTextDelta.value : this.richTextDelta,
        status: status ?? this.status,
        extractedFields: extractedFields.present
            ? extractedFields.value
            : this.extractedFields,
        patientRecap:
            patientRecap.present ? patientRecap.value : this.patientRecap,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncedDoctorNote copyWithCompanion(SyncedDoctorNotesCompanion data) {
    return SyncedDoctorNote(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      consultationId: data.consultationId.present
          ? data.consultationId.value
          : this.consultationId,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      doctorId: data.doctorId.present ? data.doctorId.value : this.doctorId,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      richTextDelta: data.richTextDelta.present
          ? data.richTextDelta.value
          : this.richTextDelta,
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
    return (StringBuffer('SyncedDoctorNote(')
          ..write('noteId: $noteId, ')
          ..write('consultationId: $consultationId, ')
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('richTextDelta: $richTextDelta, ')
          ..write('status: $status, ')
          ..write('extractedFields: $extractedFields, ')
          ..write('patientRecap: $patientRecap, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      noteId,
      consultationId,
      patientId,
      doctorId,
      rawText,
      richTextDelta,
      status,
      extractedFields,
      patientRecap,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncedDoctorNote &&
          other.noteId == this.noteId &&
          other.consultationId == this.consultationId &&
          other.patientId == this.patientId &&
          other.doctorId == this.doctorId &&
          other.rawText == this.rawText &&
          other.richTextDelta == this.richTextDelta &&
          other.status == this.status &&
          other.extractedFields == this.extractedFields &&
          other.patientRecap == this.patientRecap &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncedDoctorNotesCompanion extends UpdateCompanion<SyncedDoctorNote> {
  final Value<String> noteId;
  final Value<String> consultationId;
  final Value<String?> patientId;
  final Value<String?> doctorId;
  final Value<String> rawText;
  final Value<String?> richTextDelta;
  final Value<String> status;
  final Value<String?> extractedFields;
  final Value<String?> patientRecap;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncedDoctorNotesCompanion({
    this.noteId = const Value.absent(),
    this.consultationId = const Value.absent(),
    this.patientId = const Value.absent(),
    this.doctorId = const Value.absent(),
    this.rawText = const Value.absent(),
    this.richTextDelta = const Value.absent(),
    this.status = const Value.absent(),
    this.extractedFields = const Value.absent(),
    this.patientRecap = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncedDoctorNotesCompanion.insert({
    required String noteId,
    required String consultationId,
    this.patientId = const Value.absent(),
    this.doctorId = const Value.absent(),
    required String rawText,
    this.richTextDelta = const Value.absent(),
    required String status,
    this.extractedFields = const Value.absent(),
    this.patientRecap = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : noteId = Value(noteId),
        consultationId = Value(consultationId),
        rawText = Value(rawText),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SyncedDoctorNote> custom({
    Expression<String>? noteId,
    Expression<String>? consultationId,
    Expression<String>? patientId,
    Expression<String>? doctorId,
    Expression<String>? rawText,
    Expression<String>? richTextDelta,
    Expression<String>? status,
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
      if (richTextDelta != null) 'rich_text_delta': richTextDelta,
      if (status != null) 'status': status,
      if (extractedFields != null) 'extracted_fields': extractedFields,
      if (patientRecap != null) 'patient_recap': patientRecap,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncedDoctorNotesCompanion copyWith(
      {Value<String>? noteId,
      Value<String>? consultationId,
      Value<String?>? patientId,
      Value<String?>? doctorId,
      Value<String>? rawText,
      Value<String?>? richTextDelta,
      Value<String>? status,
      Value<String?>? extractedFields,
      Value<String?>? patientRecap,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SyncedDoctorNotesCompanion(
      noteId: noteId ?? this.noteId,
      consultationId: consultationId ?? this.consultationId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      rawText: rawText ?? this.rawText,
      richTextDelta: richTextDelta ?? this.richTextDelta,
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
    if (richTextDelta.present) {
      map['rich_text_delta'] = Variable<String>(richTextDelta.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
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
    return (StringBuffer('SyncedDoctorNotesCompanion(')
          ..write('noteId: $noteId, ')
          ..write('consultationId: $consultationId, ')
          ..write('patientId: $patientId, ')
          ..write('doctorId: $doctorId, ')
          ..write('rawText: $rawText, ')
          ..write('richTextDelta: $richTextDelta, ')
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

abstract class _$ClinicalDatabase extends GeneratedDatabase {
  _$ClinicalDatabase(QueryExecutor e) : super(e);
  $ClinicalDatabaseManager get managers => $ClinicalDatabaseManager(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $SummaryBundlesTable summaryBundles = $SummaryBundlesTable(this);
  late final $ProcessedOutputsTable processedOutputs =
      $ProcessedOutputsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $SyncedDoctorNotesTable syncedDoctorNotes =
      $SyncedDoctorNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        transcripts,
        summaryBundles,
        processedOutputs,
        auditLogs,
        syncedDoctorNotes
      ];
}

typedef $$TranscriptsTableCreateCompanionBuilder = TranscriptsCompanion
    Function({
  required String transcriptId,
  required String consultationId,
  Value<String?> patientId,
  Value<String?> doctorId,
  Value<String?> sleepLabId,
  required String transcriptText,
  required String consultationMode,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TranscriptsTableUpdateCompanionBuilder = TranscriptsCompanion
    Function({
  Value<String> transcriptId,
  Value<String> consultationId,
  Value<String?> patientId,
  Value<String?> doctorId,
  Value<String?> sleepLabId,
  Value<String> transcriptText,
  Value<String> consultationMode,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$TranscriptsTableFilterComposer
    extends Composer<_$ClinicalDatabase, $TranscriptsTable> {
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

  ColumnFilters<String> get patientId => $composableBuilder(
      column: $table.patientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sleepLabId => $composableBuilder(
      column: $table.sleepLabId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transcriptText => $composableBuilder(
      column: $table.transcriptText,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$ClinicalDatabase, $TranscriptsTable> {
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

  ColumnOrderings<String> get patientId => $composableBuilder(
      column: $table.patientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorId => $composableBuilder(
      column: $table.doctorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sleepLabId => $composableBuilder(
      column: $table.sleepLabId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transcriptText => $composableBuilder(
      column: $table.transcriptText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$ClinicalDatabase, $TranscriptsTable> {
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

  GeneratedColumn<String> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get doctorId =>
      $composableBuilder(column: $table.doctorId, builder: (column) => column);

  GeneratedColumn<String> get sleepLabId => $composableBuilder(
      column: $table.sleepLabId, builder: (column) => column);

  GeneratedColumn<String> get transcriptText => $composableBuilder(
      column: $table.transcriptText, builder: (column) => column);

  GeneratedColumn<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TranscriptsTableTableManager extends RootTableManager<
    _$ClinicalDatabase,
    $TranscriptsTable,
    Transcript,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (
      Transcript,
      BaseReferences<_$ClinicalDatabase, $TranscriptsTable, Transcript>
    ),
    Transcript,
    PrefetchHooks Function()> {
  $$TranscriptsTableTableManager(_$ClinicalDatabase db, $TranscriptsTable table)
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
            Value<String?> patientId = const Value.absent(),
            Value<String?> doctorId = const Value.absent(),
            Value<String?> sleepLabId = const Value.absent(),
            Value<String> transcriptText = const Value.absent(),
            Value<String> consultationMode = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsCompanion(
            transcriptId: transcriptId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            sleepLabId: sleepLabId,
            transcriptText: transcriptText,
            consultationMode: consultationMode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String transcriptId,
            required String consultationId,
            Value<String?> patientId = const Value.absent(),
            Value<String?> doctorId = const Value.absent(),
            Value<String?> sleepLabId = const Value.absent(),
            required String transcriptText,
            required String consultationMode,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TranscriptsCompanion.insert(
            transcriptId: transcriptId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            sleepLabId: sleepLabId,
            transcriptText: transcriptText,
            consultationMode: consultationMode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TranscriptsTableProcessedTableManager = ProcessedTableManager<
    _$ClinicalDatabase,
    $TranscriptsTable,
    Transcript,
    $$TranscriptsTableFilterComposer,
    $$TranscriptsTableOrderingComposer,
    $$TranscriptsTableAnnotationComposer,
    $$TranscriptsTableCreateCompanionBuilder,
    $$TranscriptsTableUpdateCompanionBuilder,
    (
      Transcript,
      BaseReferences<_$ClinicalDatabase, $TranscriptsTable, Transcript>
    ),
    Transcript,
    PrefetchHooks Function()>;
typedef $$SummaryBundlesTableCreateCompanionBuilder = SummaryBundlesCompanion
    Function({
  required String consultationId,
  required String transcriptId,
  required String structuredMedicalSummary,
  Value<String?> executiveSummary,
  Value<String?> doctorNote,
  required DateTime generatedAt,
  required String consultationMode,
  Value<int> rowid,
});
typedef $$SummaryBundlesTableUpdateCompanionBuilder = SummaryBundlesCompanion
    Function({
  Value<String> consultationId,
  Value<String> transcriptId,
  Value<String> structuredMedicalSummary,
  Value<String?> executiveSummary,
  Value<String?> doctorNote,
  Value<DateTime> generatedAt,
  Value<String> consultationMode,
  Value<int> rowid,
});

class $$SummaryBundlesTableFilterComposer
    extends Composer<_$ClinicalDatabase, $SummaryBundlesTable> {
  $$SummaryBundlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get structuredMedicalSummary => $composableBuilder(
      column: $table.structuredMedicalSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doctorNote => $composableBuilder(
      column: $table.doctorNote, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode,
      builder: (column) => ColumnFilters(column));
}

class $$SummaryBundlesTableOrderingComposer
    extends Composer<_$ClinicalDatabase, $SummaryBundlesTable> {
  $$SummaryBundlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get structuredMedicalSummary => $composableBuilder(
      column: $table.structuredMedicalSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doctorNote => $composableBuilder(
      column: $table.doctorNote, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode,
      builder: (column) => ColumnOrderings(column));
}

class $$SummaryBundlesTableAnnotationComposer
    extends Composer<_$ClinicalDatabase, $SummaryBundlesTable> {
  $$SummaryBundlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get consultationId => $composableBuilder(
      column: $table.consultationId, builder: (column) => column);

  GeneratedColumn<String> get transcriptId => $composableBuilder(
      column: $table.transcriptId, builder: (column) => column);

  GeneratedColumn<String> get structuredMedicalSummary => $composableBuilder(
      column: $table.structuredMedicalSummary, builder: (column) => column);

  GeneratedColumn<String> get executiveSummary => $composableBuilder(
      column: $table.executiveSummary, builder: (column) => column);

  GeneratedColumn<String> get doctorNote => $composableBuilder(
      column: $table.doctorNote, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => column);

  GeneratedColumn<String> get consultationMode => $composableBuilder(
      column: $table.consultationMode, builder: (column) => column);
}

class $$SummaryBundlesTableTableManager extends RootTableManager<
    _$ClinicalDatabase,
    $SummaryBundlesTable,
    SummaryBundle,
    $$SummaryBundlesTableFilterComposer,
    $$SummaryBundlesTableOrderingComposer,
    $$SummaryBundlesTableAnnotationComposer,
    $$SummaryBundlesTableCreateCompanionBuilder,
    $$SummaryBundlesTableUpdateCompanionBuilder,
    (
      SummaryBundle,
      BaseReferences<_$ClinicalDatabase, $SummaryBundlesTable, SummaryBundle>
    ),
    SummaryBundle,
    PrefetchHooks Function()> {
  $$SummaryBundlesTableTableManager(
      _$ClinicalDatabase db, $SummaryBundlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SummaryBundlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SummaryBundlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SummaryBundlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> consultationId = const Value.absent(),
            Value<String> transcriptId = const Value.absent(),
            Value<String> structuredMedicalSummary = const Value.absent(),
            Value<String?> executiveSummary = const Value.absent(),
            Value<String?> doctorNote = const Value.absent(),
            Value<DateTime> generatedAt = const Value.absent(),
            Value<String> consultationMode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SummaryBundlesCompanion(
            consultationId: consultationId,
            transcriptId: transcriptId,
            structuredMedicalSummary: structuredMedicalSummary,
            executiveSummary: executiveSummary,
            doctorNote: doctorNote,
            generatedAt: generatedAt,
            consultationMode: consultationMode,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String consultationId,
            required String transcriptId,
            required String structuredMedicalSummary,
            Value<String?> executiveSummary = const Value.absent(),
            Value<String?> doctorNote = const Value.absent(),
            required DateTime generatedAt,
            required String consultationMode,
            Value<int> rowid = const Value.absent(),
          }) =>
              SummaryBundlesCompanion.insert(
            consultationId: consultationId,
            transcriptId: transcriptId,
            structuredMedicalSummary: structuredMedicalSummary,
            executiveSummary: executiveSummary,
            doctorNote: doctorNote,
            generatedAt: generatedAt,
            consultationMode: consultationMode,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SummaryBundlesTableProcessedTableManager = ProcessedTableManager<
    _$ClinicalDatabase,
    $SummaryBundlesTable,
    SummaryBundle,
    $$SummaryBundlesTableFilterComposer,
    $$SummaryBundlesTableOrderingComposer,
    $$SummaryBundlesTableAnnotationComposer,
    $$SummaryBundlesTableCreateCompanionBuilder,
    $$SummaryBundlesTableUpdateCompanionBuilder,
    (
      SummaryBundle,
      BaseReferences<_$ClinicalDatabase, $SummaryBundlesTable, SummaryBundle>
    ),
    SummaryBundle,
    PrefetchHooks Function()>;
typedef $$ProcessedOutputsTableCreateCompanionBuilder
    = ProcessedOutputsCompanion Function({
  required String id,
  Value<String?> consultationId,
  required String processingMode,
  Value<String?> source,
  required String inputText,
  required String processedText,
  required List<String> warnings,
  required DateTime generatedAt,
  required Map<String, dynamic> metadata,
  Value<int> rowid,
});
typedef $$ProcessedOutputsTableUpdateCompanionBuilder
    = ProcessedOutputsCompanion Function({
  Value<String> id,
  Value<String?> consultationId,
  Value<String> processingMode,
  Value<String?> source,
  Value<String> inputText,
  Value<String> processedText,
  Value<List<String>> warnings,
  Value<DateTime> generatedAt,
  Value<Map<String, dynamic>> metadata,
  Value<int> rowid,
});

class $$ProcessedOutputsTableFilterComposer
    extends Composer<_$ClinicalDatabase, $ProcessedOutputsTable> {
  $$ProcessedOutputsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get processingMode => $composableBuilder(
      column: $table.processingMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inputText => $composableBuilder(
      column: $table.inputText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get processedText => $composableBuilder(
      column: $table.processedText, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get warnings => $composableBuilder(
          column: $table.warnings,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<Map<String, dynamic>, Map<String, dynamic>,
          String>
      get metadata => $composableBuilder(
          column: $table.metadata,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$ProcessedOutputsTableOrderingComposer
    extends Composer<_$ClinicalDatabase, $ProcessedOutputsTable> {
  $$ProcessedOutputsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consultationId => $composableBuilder(
      column: $table.consultationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get processingMode => $composableBuilder(
      column: $table.processingMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inputText => $composableBuilder(
      column: $table.inputText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get processedText => $composableBuilder(
      column: $table.processedText,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get warnings => $composableBuilder(
      column: $table.warnings, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));
}

class $$ProcessedOutputsTableAnnotationComposer
    extends Composer<_$ClinicalDatabase, $ProcessedOutputsTable> {
  $$ProcessedOutputsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get consultationId => $composableBuilder(
      column: $table.consultationId, builder: (column) => column);

  GeneratedColumn<String> get processingMode => $composableBuilder(
      column: $table.processingMode, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get inputText =>
      $composableBuilder(column: $table.inputText, builder: (column) => column);

  GeneratedColumn<String> get processedText => $composableBuilder(
      column: $table.processedText, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get warnings =>
      $composableBuilder(column: $table.warnings, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
      column: $table.generatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$ProcessedOutputsTableTableManager extends RootTableManager<
    _$ClinicalDatabase,
    $ProcessedOutputsTable,
    ProcessedOutput,
    $$ProcessedOutputsTableFilterComposer,
    $$ProcessedOutputsTableOrderingComposer,
    $$ProcessedOutputsTableAnnotationComposer,
    $$ProcessedOutputsTableCreateCompanionBuilder,
    $$ProcessedOutputsTableUpdateCompanionBuilder,
    (
      ProcessedOutput,
      BaseReferences<_$ClinicalDatabase, $ProcessedOutputsTable,
          ProcessedOutput>
    ),
    ProcessedOutput,
    PrefetchHooks Function()> {
  $$ProcessedOutputsTableTableManager(
      _$ClinicalDatabase db, $ProcessedOutputsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessedOutputsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessedOutputsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessedOutputsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> consultationId = const Value.absent(),
            Value<String> processingMode = const Value.absent(),
            Value<String?> source = const Value.absent(),
            Value<String> inputText = const Value.absent(),
            Value<String> processedText = const Value.absent(),
            Value<List<String>> warnings = const Value.absent(),
            Value<DateTime> generatedAt = const Value.absent(),
            Value<Map<String, dynamic>> metadata = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessedOutputsCompanion(
            id: id,
            consultationId: consultationId,
            processingMode: processingMode,
            source: source,
            inputText: inputText,
            processedText: processedText,
            warnings: warnings,
            generatedAt: generatedAt,
            metadata: metadata,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> consultationId = const Value.absent(),
            required String processingMode,
            Value<String?> source = const Value.absent(),
            required String inputText,
            required String processedText,
            required List<String> warnings,
            required DateTime generatedAt,
            required Map<String, dynamic> metadata,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProcessedOutputsCompanion.insert(
            id: id,
            consultationId: consultationId,
            processingMode: processingMode,
            source: source,
            inputText: inputText,
            processedText: processedText,
            warnings: warnings,
            generatedAt: generatedAt,
            metadata: metadata,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProcessedOutputsTableProcessedTableManager = ProcessedTableManager<
    _$ClinicalDatabase,
    $ProcessedOutputsTable,
    ProcessedOutput,
    $$ProcessedOutputsTableFilterComposer,
    $$ProcessedOutputsTableOrderingComposer,
    $$ProcessedOutputsTableAnnotationComposer,
    $$ProcessedOutputsTableCreateCompanionBuilder,
    $$ProcessedOutputsTableUpdateCompanionBuilder,
    (
      ProcessedOutput,
      BaseReferences<_$ClinicalDatabase, $ProcessedOutputsTable,
          ProcessedOutput>
    ),
    ProcessedOutput,
    PrefetchHooks Function()>;
typedef $$AuditLogsTableCreateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  required String correlationId,
  Value<String?> userId,
  Value<String?> clinicId,
  required String action,
  required String resource,
  Value<String?> resourceId,
  required String outcome,
  Value<String?> metadataJson,
  required DateTime timestamp,
});
typedef $$AuditLogsTableUpdateCompanionBuilder = AuditLogsCompanion Function({
  Value<int> id,
  Value<String> correlationId,
  Value<String?> userId,
  Value<String?> clinicId,
  Value<String> action,
  Value<String> resource,
  Value<String?> resourceId,
  Value<String> outcome,
  Value<String?> metadataJson,
  Value<DateTime> timestamp,
});

class $$AuditLogsTableFilterComposer
    extends Composer<_$ClinicalDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get correlationId => $composableBuilder(
      column: $table.correlationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clinicId => $composableBuilder(
      column: $table.clinicId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resource => $composableBuilder(
      column: $table.resource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$ClinicalDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get correlationId => $composableBuilder(
      column: $table.correlationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clinicId => $composableBuilder(
      column: $table.clinicId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resource => $composableBuilder(
      column: $table.resource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$ClinicalDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get correlationId => $composableBuilder(
      column: $table.correlationId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get clinicId =>
      $composableBuilder(column: $table.clinicId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get resource =>
      $composableBuilder(column: $table.resource, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
      column: $table.resourceId, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AuditLogsTableTableManager extends RootTableManager<
    _$ClinicalDatabase,
    $AuditLogsTable,
    AuditLog,
    $$AuditLogsTableFilterComposer,
    $$AuditLogsTableOrderingComposer,
    $$AuditLogsTableAnnotationComposer,
    $$AuditLogsTableCreateCompanionBuilder,
    $$AuditLogsTableUpdateCompanionBuilder,
    (AuditLog, BaseReferences<_$ClinicalDatabase, $AuditLogsTable, AuditLog>),
    AuditLog,
    PrefetchHooks Function()> {
  $$AuditLogsTableTableManager(_$ClinicalDatabase db, $AuditLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> correlationId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String?> clinicId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> resource = const Value.absent(),
            Value<String?> resourceId = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<String?> metadataJson = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              AuditLogsCompanion(
            id: id,
            correlationId: correlationId,
            userId: userId,
            clinicId: clinicId,
            action: action,
            resource: resource,
            resourceId: resourceId,
            outcome: outcome,
            metadataJson: metadataJson,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String correlationId,
            Value<String?> userId = const Value.absent(),
            Value<String?> clinicId = const Value.absent(),
            required String action,
            required String resource,
            Value<String?> resourceId = const Value.absent(),
            required String outcome,
            Value<String?> metadataJson = const Value.absent(),
            required DateTime timestamp,
          }) =>
              AuditLogsCompanion.insert(
            id: id,
            correlationId: correlationId,
            userId: userId,
            clinicId: clinicId,
            action: action,
            resource: resource,
            resourceId: resourceId,
            outcome: outcome,
            metadataJson: metadataJson,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditLogsTableProcessedTableManager = ProcessedTableManager<
    _$ClinicalDatabase,
    $AuditLogsTable,
    AuditLog,
    $$AuditLogsTableFilterComposer,
    $$AuditLogsTableOrderingComposer,
    $$AuditLogsTableAnnotationComposer,
    $$AuditLogsTableCreateCompanionBuilder,
    $$AuditLogsTableUpdateCompanionBuilder,
    (AuditLog, BaseReferences<_$ClinicalDatabase, $AuditLogsTable, AuditLog>),
    AuditLog,
    PrefetchHooks Function()>;
typedef $$SyncedDoctorNotesTableCreateCompanionBuilder
    = SyncedDoctorNotesCompanion Function({
  required String noteId,
  required String consultationId,
  Value<String?> patientId,
  Value<String?> doctorId,
  required String rawText,
  Value<String?> richTextDelta,
  required String status,
  Value<String?> extractedFields,
  Value<String?> patientRecap,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SyncedDoctorNotesTableUpdateCompanionBuilder
    = SyncedDoctorNotesCompanion Function({
  Value<String> noteId,
  Value<String> consultationId,
  Value<String?> patientId,
  Value<String?> doctorId,
  Value<String> rawText,
  Value<String?> richTextDelta,
  Value<String> status,
  Value<String?> extractedFields,
  Value<String?> patientRecap,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SyncedDoctorNotesTableFilterComposer
    extends Composer<_$ClinicalDatabase, $SyncedDoctorNotesTable> {
  $$SyncedDoctorNotesTableFilterComposer({
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

  ColumnFilters<String> get richTextDelta => $composableBuilder(
      column: $table.richTextDelta, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
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

class $$SyncedDoctorNotesTableOrderingComposer
    extends Composer<_$ClinicalDatabase, $SyncedDoctorNotesTable> {
  $$SyncedDoctorNotesTableOrderingComposer({
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

  ColumnOrderings<String> get richTextDelta => $composableBuilder(
      column: $table.richTextDelta,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
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

class $$SyncedDoctorNotesTableAnnotationComposer
    extends Composer<_$ClinicalDatabase, $SyncedDoctorNotesTable> {
  $$SyncedDoctorNotesTableAnnotationComposer({
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

  GeneratedColumn<String> get richTextDelta => $composableBuilder(
      column: $table.richTextDelta, builder: (column) => column);

  GeneratedColumn<String> get status =>
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

class $$SyncedDoctorNotesTableTableManager extends RootTableManager<
    _$ClinicalDatabase,
    $SyncedDoctorNotesTable,
    SyncedDoctorNote,
    $$SyncedDoctorNotesTableFilterComposer,
    $$SyncedDoctorNotesTableOrderingComposer,
    $$SyncedDoctorNotesTableAnnotationComposer,
    $$SyncedDoctorNotesTableCreateCompanionBuilder,
    $$SyncedDoctorNotesTableUpdateCompanionBuilder,
    (
      SyncedDoctorNote,
      BaseReferences<_$ClinicalDatabase, $SyncedDoctorNotesTable,
          SyncedDoctorNote>
    ),
    SyncedDoctorNote,
    PrefetchHooks Function()> {
  $$SyncedDoctorNotesTableTableManager(
      _$ClinicalDatabase db, $SyncedDoctorNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncedDoctorNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncedDoctorNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncedDoctorNotesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> noteId = const Value.absent(),
            Value<String> consultationId = const Value.absent(),
            Value<String?> patientId = const Value.absent(),
            Value<String?> doctorId = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<String?> richTextDelta = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> extractedFields = const Value.absent(),
            Value<String?> patientRecap = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncedDoctorNotesCompanion(
            noteId: noteId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            rawText: rawText,
            richTextDelta: richTextDelta,
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
            Value<String?> patientId = const Value.absent(),
            Value<String?> doctorId = const Value.absent(),
            required String rawText,
            Value<String?> richTextDelta = const Value.absent(),
            required String status,
            Value<String?> extractedFields = const Value.absent(),
            Value<String?> patientRecap = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncedDoctorNotesCompanion.insert(
            noteId: noteId,
            consultationId: consultationId,
            patientId: patientId,
            doctorId: doctorId,
            rawText: rawText,
            richTextDelta: richTextDelta,
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

typedef $$SyncedDoctorNotesTableProcessedTableManager = ProcessedTableManager<
    _$ClinicalDatabase,
    $SyncedDoctorNotesTable,
    SyncedDoctorNote,
    $$SyncedDoctorNotesTableFilterComposer,
    $$SyncedDoctorNotesTableOrderingComposer,
    $$SyncedDoctorNotesTableAnnotationComposer,
    $$SyncedDoctorNotesTableCreateCompanionBuilder,
    $$SyncedDoctorNotesTableUpdateCompanionBuilder,
    (
      SyncedDoctorNote,
      BaseReferences<_$ClinicalDatabase, $SyncedDoctorNotesTable,
          SyncedDoctorNote>
    ),
    SyncedDoctorNote,
    PrefetchHooks Function()>;

class $ClinicalDatabaseManager {
  final _$ClinicalDatabase _db;
  $ClinicalDatabaseManager(this._db);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$SummaryBundlesTableTableManager get summaryBundles =>
      $$SummaryBundlesTableTableManager(_db, _db.summaryBundles);
  $$ProcessedOutputsTableTableManager get processedOutputs =>
      $$ProcessedOutputsTableTableManager(_db, _db.processedOutputs);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$SyncedDoctorNotesTableTableManager get syncedDoctorNotes =>
      $$SyncedDoctorNotesTableTableManager(_db, _db.syncedDoctorNotes);
}
