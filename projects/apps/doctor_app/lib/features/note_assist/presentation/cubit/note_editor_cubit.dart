import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/doctor_note.dart';
import '../../data/local/note_local_repository.dart';
import '../../data/repositories/note_sync_repository.dart';
import 'note_editor_state.dart';

class NoteEditorCubit extends Cubit<NoteEditorState> {
  final NoteLocalRepository _localRepository;
  final NoteSyncRepository _syncRepository;
  Timer? _debounce;
  Timer? _syncDebounce;

  NoteEditorCubit({
    required NoteLocalRepository localRepository,
    required NoteSyncRepository syncRepository,
  })  : _localRepository = localRepository,
        _syncRepository = syncRepository,
        super(NoteEditorInitial());

  Future<void> loadOrCreateNote({
    required String consultationId,
    required String patientId,
    required String doctorId,
  }) async {
    emit(NoteEditorLoading());
    try {
      final existingNotes = await _localRepository.getNotesForConsultation(consultationId);
      
      if (existingNotes.isEmpty) {
        final note = DoctorNote(
          noteId: const Uuid().v4(),
          consultationId: consultationId,
          patientId: patientId,
          doctorId: doctorId,
          rawText: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _localRepository.saveNote(note);
      }
      
      final note = await _localRepository.getNoteByConsultationId(consultationId);
      
      emit(NoteEditorLoaded(
        note: note!,
        lastSavedAt: DateTime.now(),
      ));

      // Trigger sync after saving locally
      _triggerSync(consultationId);
    } catch (e) {
      emit(NoteEditorError(e.toString()));
    }
  }

  void _triggerSync(String consultationId) {
    if (_syncDebounce?.isActive ?? false) _syncDebounce!.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () async {
      if (state is NoteEditorLoaded) {
        emit((state as NoteEditorLoaded).copyWith(isSyncing: true));
        try {
          await _syncRepository.syncNoteToBackend(consultationId);
          if (!isClosed) {
            emit((state as NoteEditorLoaded).copyWith(isSyncing: false));
          }
        } catch (e) {
          if (!isClosed) {
            emit((state as NoteEditorLoaded).copyWith(
              isSyncing: false,
              error: 'Failed to sync with server.',
            ));
          }
        }
      }
    });
  }

  void updateText(String text) {
    if (state is NoteEditorLoaded) {
      final currentState = state as NoteEditorLoaded;
      final updatedNote = currentState.note.copyWith(
        rawText: text,
        updatedAt: DateTime.now(),
      );
      
      emit(currentState.copyWith(note: updatedNote));
      _scheduleAutoSave(updatedNote);
    }
  }

  void _scheduleAutoSave(DoctorNote note) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _saveNote(note);
    });
  }

  Future<void> _saveNote(DoctorNote note) async {
    if (state is NoteEditorLoaded) {
      final currentState = state as NoteEditorLoaded;
      emit(currentState.copyWith(isSaving: true));
      
      try {
        await _localRepository.saveNote(note);
        emit(currentState.copyWith(isSaving: false, lastSavedAt: DateTime.now()));
        _triggerSync(note.consultationId);
      } catch (e) {
        emit(currentState.copyWith(isSaving: false));
      }
    }
  }

  void saveNoteFields(DoctorNote note) {
    if (state is NoteEditorLoaded) {
      final currentState = state as NoteEditorLoaded;
      emit(currentState.copyWith(note: note));
      _scheduleAutoSave(note);
    }
  }

  void setListening(bool isListening) {
    if (state is NoteEditorLoaded) {
      final currentState = state as NoteEditorLoaded;
      emit(currentState.copyWith(isListening: isListening));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _syncDebounce?.cancel();
    return super.close();
  }
}
