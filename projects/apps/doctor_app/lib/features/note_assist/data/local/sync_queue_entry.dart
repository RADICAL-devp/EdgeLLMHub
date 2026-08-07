import 'package:drift/drift.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';

@DataClassName('SyncQueueEntryEntity')
class SyncQueueEntries extends Table {
  TextColumn get id => text()(); // UUID
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

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueueEntry {
  final String id;
  final String noteId;
  final String consultationId;
  final String operation; // 'create', 'update', 'delete'
  final DoctorNote note;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextRetryAt;
  final String? lastError;
  final bool isDeadLetter;

  SyncQueueEntry({
    required this.id,
    required this.noteId,
    required this.consultationId,
    required this.operation,
    required this.note,
    this.retryCount = 0,
    this.maxRetries = 5,
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
    this.lastError,
    this.isDeadLetter = false,
  });

  SyncQueueEntry copyWith({
    String? id,
    String? noteId,
    String? consultationId,
    String? operation,
    DoctorNote? note,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextRetryAt,
    String? lastError,
    bool? isDeadLetter,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      consultationId: consultationId ?? this.consultationId,
      operation: operation ?? this.operation,
      note: note ?? this.note,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      isDeadLetter: isDeadLetter ?? this.isDeadLetter,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'noteId': noteId,
    'consultationId': consultationId,
    'operation': operation,
    'note': note.toJson(),
    'retryCount': retryCount,
    'maxRetries': maxRetries,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'nextRetryAt': nextRetryAt?.toIso8601String(),
    'lastError': lastError,
    'isDeadLetter': isDeadLetter,
  };

  static SyncQueueEntry fromJson(Map<String, dynamic> json) {
    return SyncQueueEntry(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      consultationId: json['consultationId'] as String,
      operation: json['operation'] as String,
      note: DoctorNote.fromJson(json['note'] as Map<String, dynamic>),
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 5,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      nextRetryAt: json['nextRetryAt'] != null 
          ? DateTime.parse(json['nextRetryAt'] as String) 
          : null,
      lastError: json['lastError'] as String?,
      isDeadLetter: json['isDeadLetter'] as bool? ?? false,
    );
  }
}
