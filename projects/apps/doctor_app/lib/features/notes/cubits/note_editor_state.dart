import 'package:equatable/equatable.dart';

import '../../../core/models/clinical_note.dart';

abstract class NoteEditorState extends Equatable {
  const NoteEditorState();

  @override
  List<Object?> get props => [];
}

class NoteEditorInitial extends NoteEditorState {}

class NoteEditorLoading extends NoteEditorState {}

class NoteEditorLoaded extends NoteEditorState {
  const NoteEditorLoaded({
    required this.note,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.lastSavedAt,
    this.error,
  });

  final ClinicalNote note;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedAt;
  final String? error;

  NoteEditorLoaded copyWith({
    ClinicalNote? note,
    bool? isSaving,
    bool? hasUnsavedChanges,
    DateTime? lastSavedAt,
    String? error,
    bool clearError = false,
  }) {
    return NoteEditorLoaded(
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    note,
    isSaving,
    hasUnsavedChanges,
    lastSavedAt,
    error,
  ];
}

class NoteEditorFailure extends NoteEditorState {
  const NoteEditorFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
