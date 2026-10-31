import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/clinical_note.dart';
import '../../../core/utils/debouncer.dart';
import 'note_editor_state.dart';

/// Owns one note while it is open and persists edits on a 2-second debounce.
class NoteEditorCubit extends Cubit<NoteEditorState> {
  NoteEditorCubit({required NoteRepository repository, Debouncer? debouncer})
    : _repository = repository,
      _debouncer = debouncer ?? Debouncer(AppConfig.autoSaveDebounce),
      super(NoteEditorInitial());

  final NoteRepository _repository;
  final Debouncer _debouncer;
  final Uuid _uuid = const Uuid();

  bool _saveInFlight = false;
  bool _saveAgain = false;
  bool _deleted = false;
  Completer<void>? _saveDone;

  Future<ClinicalNote?> load(String id) async {
    emit(NoteEditorLoading());
    try {
      final note = await _repository.getById(id);
      if (note == null) {
        emit(const NoteEditorFailure('This note could not be found.'));
        return null;
      }
      emit(NoteEditorLoaded(note: note, lastSavedAt: note.updatedAt));
      return note;
    } catch (error) {
      emit(NoteEditorFailure(_messageFor(error)));
      return null;
    }
  }

  Future<ClinicalNote?> create({
    required String title,
    required String patientName,
    required String languageCode,
  }) async {
    try {
      final note = ClinicalNote.create(
        id: _uuid.v4(),
        title: title,
        patientName: patientName,
        languageCode: AppConfig.supportedLanguages.containsKey(languageCode)
            ? languageCode
            : AppConfig.defaultLanguageCode,
      );
      await _repository.save(note);
      if (isClosed) return note;
      emit(NoteEditorLoaded(note: note, lastSavedAt: note.updatedAt));
      return note;
    } catch (error) {
      if (!isClosed) emit(NoteEditorFailure(_messageFor(error)));
      return null;
    }
  }

  void updateTitle(String value) {
    _update((note) => note.copyWith(title: value));
  }

  void updatePatientName(String value) {
    _update((note) => note.copyWith(patientName: value));
  }

  void updateTranscript(String value) {
    if (value.length > AppConfig.maxTranscriptCharacters) {
      value = value.substring(0, AppConfig.maxTranscriptCharacters);
    }
    _update((note) => note.copyWith(transcript: value));
  }

  void updateCleanedTranscript(String? value) {
    _update((note) => note.copyWith(cleanedTranscript: value));
  }

  void updateSections(StructuredNoteSections sections) {
    _update((note) => note.copyWith(sections: sections));
  }

  void setThinkingModeUsed(bool value) {
    _update((note) => note.copyWith(thinkingModeUsed: value));
  }

  void updateModelName(String? value) {
    _update((note) => note.copyWith(modelName: value));
  }

  Future<void> saveNow() async {
    final current = state;
    if (_deleted || current is! NoteEditorLoaded) return;
    if (_saveInFlight) {
      _saveAgain = true;
      return;
    }

    _saveInFlight = true;
    _debouncer.cancel();
    final done = Completer<void>();
    _saveDone = done;
    final noteToSave = current.note.copyWith(updatedAt: DateTime.now());
    if (!isClosed) {
      emit(current.copyWith(isSaving: true, clearError: true));
    }
    try {
      await _repository.save(noteToSave);
      if (isClosed || _deleted) return;
      final latest = state;
      if (latest is NoteEditorLoaded &&
          latest.note.updatedAt.isAfter(noteToSave.updatedAt)) {
        // An edit landed while the write was in flight; keep it dirty and
        // let the next debounce write it instead of overwriting it.
        emit(
          latest.copyWith(
            isSaving: false,
            hasUnsavedChanges: true,
            lastSavedAt: DateTime.now(),
          ),
        );
        _debouncer(() => saveNow());
      } else {
        emit(
          NoteEditorLoaded(
            note: noteToSave,
            isSaving: false,
            hasUnsavedChanges: false,
            lastSavedAt: DateTime.now(),
          ),
        );
      }
    } on AppException catch (error) {
      if (!isClosed && !_deleted) {
        _emitSaveFailure(current, error.message);
      }
    } catch (_) {
      if (!isClosed && !_deleted) {
        _emitSaveFailure(current, 'Could not save this note on the device.');
      }
    } finally {
      _saveInFlight = false;
      if (identical(_saveDone, done)) _saveDone = null;
      if (!done.isCompleted) done.complete();
      if (_saveAgain && !_deleted) {
        _saveAgain = false;
        await saveNow();
      }
    }
  }

  void _emitSaveFailure(NoteEditorLoaded fallback, String message) {
    final latest = state;
    final base = latest is NoteEditorLoaded ? latest : fallback;
    emit(
      base.copyWith(isSaving: false, hasUnsavedChanges: true, error: message),
    );
  }

  Future<void> finalizeNote() async {
    final current = state;
    if (current is! NoteEditorLoaded) return;
    _update(
      (note) => note.copyWith(
        status: NoteStatus.finalized,
        updatedAt: DateTime.now(),
      ),
    );
    await saveNow();
  }

  Future<void> reopenNote() async {
    final current = state;
    if (current is! NoteEditorLoaded) return;
    _update(
      (note) =>
          note.copyWith(status: NoteStatus.draft, updatedAt: DateTime.now()),
    );
    await saveNow();
  }

  /// Permanently removes this note.
  ///
  /// A save may already be in flight when the user confirms deletion. Wait for
  /// it to settle first, otherwise a late write could recreate the record after
  /// the delete. Returns false when the delete did not complete.
  Future<bool> deleteNote() async {
    final current = state;
    if (_deleted || current is! NoteEditorLoaded) return false;
    _deleted = true;
    _debouncer.cancel();
    _saveAgain = false;
    try {
      while (_saveInFlight) {
        final done = _saveDone;
        if (done == null) break;
        await done.future;
      }
      await _repository.deleteById(current.note.id);
      return true;
    } catch (_) {
      _deleted = false;
      if (!isClosed) {
        final latest = state;
        final base = latest is NoteEditorLoaded ? latest : current;
        emit(
          base.copyWith(
            isSaving: false,
            error: 'This note could not be deleted from the device.',
          ),
        );
      }
      return false;
    }
  }

  void _update(ClinicalNote Function(ClinicalNote note) transform) {
    final current = state;
    if (_deleted || current is! NoteEditorLoaded || isClosed) return;
    final updated = transform(current.note).copyWith(updatedAt: DateTime.now());
    emit(
      current.copyWith(
        note: updated,
        hasUnsavedChanges: true,
        clearError: true,
      ),
    );
    _debouncer(() => saveNow());
  }

  static String _messageFor(Object error) {
    if (error is AppException) return error.message;
    return 'The note could not be loaded from this device.';
  }

  @override
  Future<void> close() async {
    _debouncer.cancel();
    final current = state;
    if (!_deleted && current is NoteEditorLoaded && current.hasUnsavedChanges) {
      // Flush pending edits before tearing the editor down.
      try {
        await _repository.save(
          current.note.copyWith(updatedAt: DateTime.now()),
        );
      } catch (_) {
        // Close must not mask teardown with a failed best-effort save.
      }
    }
    return super.close();
  }
}
