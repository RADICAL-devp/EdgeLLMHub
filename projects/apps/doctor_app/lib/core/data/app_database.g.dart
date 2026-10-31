// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ClinicalNotesTable extends ClinicalNotes
    with TableInfo<$ClinicalNotesTable, ClinicalNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClinicalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleCipherMeta = const VerificationMeta(
    'titleCipher',
  );
  @override
  late final GeneratedColumn<String> titleCipher = GeneratedColumn<String>(
    'title_cipher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientNameCipherMeta = const VerificationMeta(
    'patientNameCipher',
  );
  @override
  late final GeneratedColumn<String> patientNameCipher =
      GeneratedColumn<String>(
        'patient_name_cipher',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _transcriptCipherMeta = const VerificationMeta(
    'transcriptCipher',
  );
  @override
  late final GeneratedColumn<String> transcriptCipher = GeneratedColumn<String>(
    'transcript_cipher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleanedTranscriptCipherMeta =
      const VerificationMeta('cleanedTranscriptCipher');
  @override
  late final GeneratedColumn<String> cleanedTranscriptCipher =
      GeneratedColumn<String>(
        'cleaned_transcript_cipher',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sectionsCipherMeta = const VerificationMeta(
    'sectionsCipher',
  );
  @override
  late final GeneratedColumn<String> sectionsCipher = GeneratedColumn<String>(
    'sections_cipher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _thinkingModeUsedMeta = const VerificationMeta(
    'thinkingModeUsed',
  );
  @override
  late final GeneratedColumn<bool> thinkingModeUsed = GeneratedColumn<bool>(
    'thinking_mode_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("thinking_mode_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titleCipher,
    patientNameCipher,
    transcriptCipher,
    cleanedTranscriptCipher,
    sectionsCipher,
    status,
    languageCode,
    thinkingModeUsed,
    modelName,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clinical_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClinicalNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title_cipher')) {
      context.handle(
        _titleCipherMeta,
        titleCipher.isAcceptableOrUnknown(
          data['title_cipher']!,
          _titleCipherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleCipherMeta);
    }
    if (data.containsKey('patient_name_cipher')) {
      context.handle(
        _patientNameCipherMeta,
        patientNameCipher.isAcceptableOrUnknown(
          data['patient_name_cipher']!,
          _patientNameCipherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_patientNameCipherMeta);
    }
    if (data.containsKey('transcript_cipher')) {
      context.handle(
        _transcriptCipherMeta,
        transcriptCipher.isAcceptableOrUnknown(
          data['transcript_cipher']!,
          _transcriptCipherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptCipherMeta);
    }
    if (data.containsKey('cleaned_transcript_cipher')) {
      context.handle(
        _cleanedTranscriptCipherMeta,
        cleanedTranscriptCipher.isAcceptableOrUnknown(
          data['cleaned_transcript_cipher']!,
          _cleanedTranscriptCipherMeta,
        ),
      );
    }
    if (data.containsKey('sections_cipher')) {
      context.handle(
        _sectionsCipherMeta,
        sectionsCipher.isAcceptableOrUnknown(
          data['sections_cipher']!,
          _sectionsCipherMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionsCipherMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    }
    if (data.containsKey('thinking_mode_used')) {
      context.handle(
        _thinkingModeUsedMeta,
        thinkingModeUsed.isAcceptableOrUnknown(
          data['thinking_mode_used']!,
          _thinkingModeUsedMeta,
        ),
      );
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClinicalNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClinicalNoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      titleCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_cipher'],
      )!,
      patientNameCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_name_cipher'],
      )!,
      transcriptCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_cipher'],
      )!,
      cleanedTranscriptCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cleaned_transcript_cipher'],
      ),
      sectionsCipher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sections_cipher'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      thinkingModeUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}thinking_mode_used'],
      )!,
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ClinicalNotesTable createAlias(String alias) {
    return $ClinicalNotesTable(attachedDatabase, alias);
  }
}

class ClinicalNoteRow extends DataClass implements Insertable<ClinicalNoteRow> {
  final String id;
  final String titleCipher;
  final String patientNameCipher;
  final String transcriptCipher;
  final String? cleanedTranscriptCipher;
  final String sectionsCipher;
  final int status;
  final String languageCode;
  final bool thinkingModeUsed;
  final String? modelName;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ClinicalNoteRow({
    required this.id,
    required this.titleCipher,
    required this.patientNameCipher,
    required this.transcriptCipher,
    this.cleanedTranscriptCipher,
    required this.sectionsCipher,
    required this.status,
    required this.languageCode,
    required this.thinkingModeUsed,
    this.modelName,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title_cipher'] = Variable<String>(titleCipher);
    map['patient_name_cipher'] = Variable<String>(patientNameCipher);
    map['transcript_cipher'] = Variable<String>(transcriptCipher);
    if (!nullToAbsent || cleanedTranscriptCipher != null) {
      map['cleaned_transcript_cipher'] = Variable<String>(
        cleanedTranscriptCipher,
      );
    }
    map['sections_cipher'] = Variable<String>(sectionsCipher);
    map['status'] = Variable<int>(status);
    map['language_code'] = Variable<String>(languageCode);
    map['thinking_mode_used'] = Variable<bool>(thinkingModeUsed);
    if (!nullToAbsent || modelName != null) {
      map['model_name'] = Variable<String>(modelName);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ClinicalNotesCompanion toCompanion(bool nullToAbsent) {
    return ClinicalNotesCompanion(
      id: Value(id),
      titleCipher: Value(titleCipher),
      patientNameCipher: Value(patientNameCipher),
      transcriptCipher: Value(transcriptCipher),
      cleanedTranscriptCipher: cleanedTranscriptCipher == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanedTranscriptCipher),
      sectionsCipher: Value(sectionsCipher),
      status: Value(status),
      languageCode: Value(languageCode),
      thinkingModeUsed: Value(thinkingModeUsed),
      modelName: modelName == null && nullToAbsent
          ? const Value.absent()
          : Value(modelName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ClinicalNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClinicalNoteRow(
      id: serializer.fromJson<String>(json['id']),
      titleCipher: serializer.fromJson<String>(json['titleCipher']),
      patientNameCipher: serializer.fromJson<String>(json['patientNameCipher']),
      transcriptCipher: serializer.fromJson<String>(json['transcriptCipher']),
      cleanedTranscriptCipher: serializer.fromJson<String?>(
        json['cleanedTranscriptCipher'],
      ),
      sectionsCipher: serializer.fromJson<String>(json['sectionsCipher']),
      status: serializer.fromJson<int>(json['status']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      thinkingModeUsed: serializer.fromJson<bool>(json['thinkingModeUsed']),
      modelName: serializer.fromJson<String?>(json['modelName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titleCipher': serializer.toJson<String>(titleCipher),
      'patientNameCipher': serializer.toJson<String>(patientNameCipher),
      'transcriptCipher': serializer.toJson<String>(transcriptCipher),
      'cleanedTranscriptCipher': serializer.toJson<String?>(
        cleanedTranscriptCipher,
      ),
      'sectionsCipher': serializer.toJson<String>(sectionsCipher),
      'status': serializer.toJson<int>(status),
      'languageCode': serializer.toJson<String>(languageCode),
      'thinkingModeUsed': serializer.toJson<bool>(thinkingModeUsed),
      'modelName': serializer.toJson<String?>(modelName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ClinicalNoteRow copyWith({
    String? id,
    String? titleCipher,
    String? patientNameCipher,
    String? transcriptCipher,
    Value<String?> cleanedTranscriptCipher = const Value.absent(),
    String? sectionsCipher,
    int? status,
    String? languageCode,
    bool? thinkingModeUsed,
    Value<String?> modelName = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ClinicalNoteRow(
    id: id ?? this.id,
    titleCipher: titleCipher ?? this.titleCipher,
    patientNameCipher: patientNameCipher ?? this.patientNameCipher,
    transcriptCipher: transcriptCipher ?? this.transcriptCipher,
    cleanedTranscriptCipher: cleanedTranscriptCipher.present
        ? cleanedTranscriptCipher.value
        : this.cleanedTranscriptCipher,
    sectionsCipher: sectionsCipher ?? this.sectionsCipher,
    status: status ?? this.status,
    languageCode: languageCode ?? this.languageCode,
    thinkingModeUsed: thinkingModeUsed ?? this.thinkingModeUsed,
    modelName: modelName.present ? modelName.value : this.modelName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ClinicalNoteRow copyWithCompanion(ClinicalNotesCompanion data) {
    return ClinicalNoteRow(
      id: data.id.present ? data.id.value : this.id,
      titleCipher: data.titleCipher.present
          ? data.titleCipher.value
          : this.titleCipher,
      patientNameCipher: data.patientNameCipher.present
          ? data.patientNameCipher.value
          : this.patientNameCipher,
      transcriptCipher: data.transcriptCipher.present
          ? data.transcriptCipher.value
          : this.transcriptCipher,
      cleanedTranscriptCipher: data.cleanedTranscriptCipher.present
          ? data.cleanedTranscriptCipher.value
          : this.cleanedTranscriptCipher,
      sectionsCipher: data.sectionsCipher.present
          ? data.sectionsCipher.value
          : this.sectionsCipher,
      status: data.status.present ? data.status.value : this.status,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      thinkingModeUsed: data.thinkingModeUsed.present
          ? data.thinkingModeUsed.value
          : this.thinkingModeUsed,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClinicalNoteRow(')
          ..write('id: $id, ')
          ..write('titleCipher: $titleCipher, ')
          ..write('patientNameCipher: $patientNameCipher, ')
          ..write('transcriptCipher: $transcriptCipher, ')
          ..write('cleanedTranscriptCipher: $cleanedTranscriptCipher, ')
          ..write('sectionsCipher: $sectionsCipher, ')
          ..write('status: $status, ')
          ..write('languageCode: $languageCode, ')
          ..write('thinkingModeUsed: $thinkingModeUsed, ')
          ..write('modelName: $modelName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titleCipher,
    patientNameCipher,
    transcriptCipher,
    cleanedTranscriptCipher,
    sectionsCipher,
    status,
    languageCode,
    thinkingModeUsed,
    modelName,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClinicalNoteRow &&
          other.id == this.id &&
          other.titleCipher == this.titleCipher &&
          other.patientNameCipher == this.patientNameCipher &&
          other.transcriptCipher == this.transcriptCipher &&
          other.cleanedTranscriptCipher == this.cleanedTranscriptCipher &&
          other.sectionsCipher == this.sectionsCipher &&
          other.status == this.status &&
          other.languageCode == this.languageCode &&
          other.thinkingModeUsed == this.thinkingModeUsed &&
          other.modelName == this.modelName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ClinicalNotesCompanion extends UpdateCompanion<ClinicalNoteRow> {
  final Value<String> id;
  final Value<String> titleCipher;
  final Value<String> patientNameCipher;
  final Value<String> transcriptCipher;
  final Value<String?> cleanedTranscriptCipher;
  final Value<String> sectionsCipher;
  final Value<int> status;
  final Value<String> languageCode;
  final Value<bool> thinkingModeUsed;
  final Value<String?> modelName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ClinicalNotesCompanion({
    this.id = const Value.absent(),
    this.titleCipher = const Value.absent(),
    this.patientNameCipher = const Value.absent(),
    this.transcriptCipher = const Value.absent(),
    this.cleanedTranscriptCipher = const Value.absent(),
    this.sectionsCipher = const Value.absent(),
    this.status = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.thinkingModeUsed = const Value.absent(),
    this.modelName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClinicalNotesCompanion.insert({
    required String id,
    required String titleCipher,
    required String patientNameCipher,
    required String transcriptCipher,
    this.cleanedTranscriptCipher = const Value.absent(),
    required String sectionsCipher,
    required int status,
    this.languageCode = const Value.absent(),
    this.thinkingModeUsed = const Value.absent(),
    this.modelName = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       titleCipher = Value(titleCipher),
       patientNameCipher = Value(patientNameCipher),
       transcriptCipher = Value(transcriptCipher),
       sectionsCipher = Value(sectionsCipher),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ClinicalNoteRow> custom({
    Expression<String>? id,
    Expression<String>? titleCipher,
    Expression<String>? patientNameCipher,
    Expression<String>? transcriptCipher,
    Expression<String>? cleanedTranscriptCipher,
    Expression<String>? sectionsCipher,
    Expression<int>? status,
    Expression<String>? languageCode,
    Expression<bool>? thinkingModeUsed,
    Expression<String>? modelName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titleCipher != null) 'title_cipher': titleCipher,
      if (patientNameCipher != null) 'patient_name_cipher': patientNameCipher,
      if (transcriptCipher != null) 'transcript_cipher': transcriptCipher,
      if (cleanedTranscriptCipher != null)
        'cleaned_transcript_cipher': cleanedTranscriptCipher,
      if (sectionsCipher != null) 'sections_cipher': sectionsCipher,
      if (status != null) 'status': status,
      if (languageCode != null) 'language_code': languageCode,
      if (thinkingModeUsed != null) 'thinking_mode_used': thinkingModeUsed,
      if (modelName != null) 'model_name': modelName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClinicalNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? titleCipher,
    Value<String>? patientNameCipher,
    Value<String>? transcriptCipher,
    Value<String?>? cleanedTranscriptCipher,
    Value<String>? sectionsCipher,
    Value<int>? status,
    Value<String>? languageCode,
    Value<bool>? thinkingModeUsed,
    Value<String?>? modelName,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ClinicalNotesCompanion(
      id: id ?? this.id,
      titleCipher: titleCipher ?? this.titleCipher,
      patientNameCipher: patientNameCipher ?? this.patientNameCipher,
      transcriptCipher: transcriptCipher ?? this.transcriptCipher,
      cleanedTranscriptCipher:
          cleanedTranscriptCipher ?? this.cleanedTranscriptCipher,
      sectionsCipher: sectionsCipher ?? this.sectionsCipher,
      status: status ?? this.status,
      languageCode: languageCode ?? this.languageCode,
      thinkingModeUsed: thinkingModeUsed ?? this.thinkingModeUsed,
      modelName: modelName ?? this.modelName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titleCipher.present) {
      map['title_cipher'] = Variable<String>(titleCipher.value);
    }
    if (patientNameCipher.present) {
      map['patient_name_cipher'] = Variable<String>(patientNameCipher.value);
    }
    if (transcriptCipher.present) {
      map['transcript_cipher'] = Variable<String>(transcriptCipher.value);
    }
    if (cleanedTranscriptCipher.present) {
      map['cleaned_transcript_cipher'] = Variable<String>(
        cleanedTranscriptCipher.value,
      );
    }
    if (sectionsCipher.present) {
      map['sections_cipher'] = Variable<String>(sectionsCipher.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (thinkingModeUsed.present) {
      map['thinking_mode_used'] = Variable<bool>(thinkingModeUsed.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
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
    return (StringBuffer('ClinicalNotesCompanion(')
          ..write('id: $id, ')
          ..write('titleCipher: $titleCipher, ')
          ..write('patientNameCipher: $patientNameCipher, ')
          ..write('transcriptCipher: $transcriptCipher, ')
          ..write('cleanedTranscriptCipher: $cleanedTranscriptCipher, ')
          ..write('sectionsCipher: $sectionsCipher, ')
          ..write('status: $status, ')
          ..write('languageCode: $languageCode, ')
          ..write('thinkingModeUsed: $thinkingModeUsed, ')
          ..write('modelName: $modelName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ClinicalNotesTable clinicalNotes = $ClinicalNotesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [clinicalNotes];
}

typedef $$ClinicalNotesTableCreateCompanionBuilder =
    ClinicalNotesCompanion Function({
      required String id,
      required String titleCipher,
      required String patientNameCipher,
      required String transcriptCipher,
      Value<String?> cleanedTranscriptCipher,
      required String sectionsCipher,
      required int status,
      Value<String> languageCode,
      Value<bool> thinkingModeUsed,
      Value<String?> modelName,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ClinicalNotesTableUpdateCompanionBuilder =
    ClinicalNotesCompanion Function({
      Value<String> id,
      Value<String> titleCipher,
      Value<String> patientNameCipher,
      Value<String> transcriptCipher,
      Value<String?> cleanedTranscriptCipher,
      Value<String> sectionsCipher,
      Value<int> status,
      Value<String> languageCode,
      Value<bool> thinkingModeUsed,
      Value<String?> modelName,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ClinicalNotesTableFilterComposer
    extends Composer<_$AppDatabase, $ClinicalNotesTable> {
  $$ClinicalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleCipher => $composableBuilder(
    column: $table.titleCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientNameCipher => $composableBuilder(
    column: $table.patientNameCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptCipher => $composableBuilder(
    column: $table.transcriptCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanedTranscriptCipher => $composableBuilder(
    column: $table.cleanedTranscriptCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sectionsCipher => $composableBuilder(
    column: $table.sectionsCipher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get thinkingModeUsed => $composableBuilder(
    column: $table.thinkingModeUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClinicalNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClinicalNotesTable> {
  $$ClinicalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleCipher => $composableBuilder(
    column: $table.titleCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientNameCipher => $composableBuilder(
    column: $table.patientNameCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptCipher => $composableBuilder(
    column: $table.transcriptCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanedTranscriptCipher => $composableBuilder(
    column: $table.cleanedTranscriptCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sectionsCipher => $composableBuilder(
    column: $table.sectionsCipher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get thinkingModeUsed => $composableBuilder(
    column: $table.thinkingModeUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClinicalNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClinicalNotesTable> {
  $$ClinicalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titleCipher => $composableBuilder(
    column: $table.titleCipher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get patientNameCipher => $composableBuilder(
    column: $table.patientNameCipher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptCipher => $composableBuilder(
    column: $table.transcriptCipher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cleanedTranscriptCipher => $composableBuilder(
    column: $table.cleanedTranscriptCipher,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sectionsCipher => $composableBuilder(
    column: $table.sectionsCipher,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get thinkingModeUsed => $composableBuilder(
    column: $table.thinkingModeUsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ClinicalNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClinicalNotesTable,
          ClinicalNoteRow,
          $$ClinicalNotesTableFilterComposer,
          $$ClinicalNotesTableOrderingComposer,
          $$ClinicalNotesTableAnnotationComposer,
          $$ClinicalNotesTableCreateCompanionBuilder,
          $$ClinicalNotesTableUpdateCompanionBuilder,
          (
            ClinicalNoteRow,
            BaseReferences<_$AppDatabase, $ClinicalNotesTable, ClinicalNoteRow>,
          ),
          ClinicalNoteRow,
          PrefetchHooks Function()
        > {
  $$ClinicalNotesTableTableManager(_$AppDatabase db, $ClinicalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClinicalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClinicalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClinicalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> titleCipher = const Value.absent(),
                Value<String> patientNameCipher = const Value.absent(),
                Value<String> transcriptCipher = const Value.absent(),
                Value<String?> cleanedTranscriptCipher = const Value.absent(),
                Value<String> sectionsCipher = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<bool> thinkingModeUsed = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClinicalNotesCompanion(
                id: id,
                titleCipher: titleCipher,
                patientNameCipher: patientNameCipher,
                transcriptCipher: transcriptCipher,
                cleanedTranscriptCipher: cleanedTranscriptCipher,
                sectionsCipher: sectionsCipher,
                status: status,
                languageCode: languageCode,
                thinkingModeUsed: thinkingModeUsed,
                modelName: modelName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String titleCipher,
                required String patientNameCipher,
                required String transcriptCipher,
                Value<String?> cleanedTranscriptCipher = const Value.absent(),
                required String sectionsCipher,
                required int status,
                Value<String> languageCode = const Value.absent(),
                Value<bool> thinkingModeUsed = const Value.absent(),
                Value<String?> modelName = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ClinicalNotesCompanion.insert(
                id: id,
                titleCipher: titleCipher,
                patientNameCipher: patientNameCipher,
                transcriptCipher: transcriptCipher,
                cleanedTranscriptCipher: cleanedTranscriptCipher,
                sectionsCipher: sectionsCipher,
                status: status,
                languageCode: languageCode,
                thinkingModeUsed: thinkingModeUsed,
                modelName: modelName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClinicalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClinicalNotesTable,
      ClinicalNoteRow,
      $$ClinicalNotesTableFilterComposer,
      $$ClinicalNotesTableOrderingComposer,
      $$ClinicalNotesTableAnnotationComposer,
      $$ClinicalNotesTableCreateCompanionBuilder,
      $$ClinicalNotesTableUpdateCompanionBuilder,
      (
        ClinicalNoteRow,
        BaseReferences<_$AppDatabase, $ClinicalNotesTable, ClinicalNoteRow>,
      ),
      ClinicalNoteRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ClinicalNotesTableTableManager get clinicalNotes =>
      $$ClinicalNotesTableTableManager(_db, _db.clinicalNotes);
}
