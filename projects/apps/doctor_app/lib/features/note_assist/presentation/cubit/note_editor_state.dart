import 'package:equatable/equatable.dart';
import '../../domain/models/doctor_note.dart';

abstract class NoteEditorState extends Equatable {
  const NoteEditorState();

  @override
  List<Object?> get props => [];
}

class NoteEditorInitial extends NoteEditorState {}

class NoteEditorLoading extends NoteEditorState {}

class NoteEditorLoaded extends NoteEditorState {
  final DoctorNote note;
  final bool isSaving;
  final bool isSyncing;
  final bool isListening;
  final DateTime? lastSavedAt;
  final String? error;

  const NoteEditorLoaded({
    required this.note,
    this.isSaving = false,
    this.isSyncing = false,
    this.isListening = false,
    this.lastSavedAt,
    this.error,
  });

  NoteEditorLoaded copyWith({
    DoctorNote? note,
    bool? isSaving,
    bool? isSyncing,
    bool? isListening,
    DateTime? lastSavedAt,
    String? error,
  }) {
    return NoteEditorLoaded(
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      isSyncing: isSyncing ?? this.isSyncing,
      isListening: isListening ?? this.isListening,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [note, isSaving, isSyncing, isListening, lastSavedAt, error];
}

class NoteEditorError extends NoteEditorState {
  final String message;

  const NoteEditorError(this.message);

  @override
  List<Object?> get props => [message];
}
