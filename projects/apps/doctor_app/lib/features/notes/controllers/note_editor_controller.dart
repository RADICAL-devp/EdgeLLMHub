import 'dart:async';

import 'package:shared_models/shared_models.dart';
import 'package:signals/signals.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/clinical_note.dart';
import '../../../core/utils/debouncer.dart';
import 'note_editor_state.dart';

/// Owns one note while it is open and persists edits on a 2-second debounce.
class NoteEditorController extends Signal<NoteEditorState> {
  NoteEditorController({
    required NoteRepository repository,
    Debouncer? debouncer,
  }) : _repository = repository,
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
    if (disposed) return null;
    value = NoteEditorLoading();
    try {
      final note = await _repository.getById(id);
      if (disposed) return null;
      if (note == null) {
        value = const NoteEditorFailure('This note could not be found.');
        return null;
      }
      value = NoteEditorLoaded(note: note, lastSavedAt: note.updatedAt);
      return note;
    } catch (error) {
      if (!disposed) value = NoteEditorFailure(_messageFor(error));
      return null;
    }
  }

  Future<ClinicalNote?> create({
    required String title,
    required String patientName,
    required String languageCode,
  }) async {
    if (disposed) return null;
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
      if (disposed) return note;
      value = NoteEditorLoaded(note: note, lastSavedAt: note.updatedAt);
      return note;
    } catch (error) {
      if (!disposed) value = NoteEditorFailure(_messageFor(error));
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
    if (disposed) return;
    final current = value;
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
    if (!disposed) {
      value = current.copyWith(isSaving: true, clearError: true);
    }
    try {
      await _repository.save(noteToSave);
      if (disposed || _deleted) return;
      final latest = value;
      if (latest is NoteEditorLoaded &&
          latest.note.updatedAt.isAfter(noteToSave.updatedAt)) {
        // An edit landed while the write was in flight; keep it dirty and
        // let the next debounce write it instead of overwriting it.
        value = latest.copyWith(
          isSaving: false,
          hasUnsavedChanges: true,
          lastSavedAt: DateTime.now(),
        );
        _debouncer(() => saveNow());
      } else {
        value = NoteEditorLoaded(
          note: noteToSave,
          isSaving: false,
          hasUnsavedChanges: false,
          lastSavedAt: DateTime.now(),
        );
      }
    } on AppException catch (error) {
      if (!disposed && !_deleted) {
        _reportSaveFailure(current, error.message);
      }
    } catch (_) {
      if (!disposed && !_deleted) {
        _reportSaveFailure(current, 'Could not save this note on the device.');
      }
    } finally {
      _saveInFlight = false;
      if (identical(_saveDone, done)) _saveDone = null;
      if (!done.isCompleted) done.complete();
      if (_saveAgain && !_deleted && !disposed) {
        _saveAgain = false;
        await saveNow();
      }
    }
  }

  void _reportSaveFailure(NoteEditorLoaded fallback, String message) {
    final latest = value;
    final base = latest is NoteEditorLoaded ? latest : fallback;
    value = base.copyWith(
      isSaving: false,
      hasUnsavedChanges: true,
      error: message,
    );
  }

  Future<void> finalizeNote() async {
    if (disposed) return;
    final current = value;
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
    if (disposed) return;
    final current = value;
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
    if (disposed) return false;
    final current = value;
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
      if (!disposed) {
        final latest = value;
        final base = latest is NoteEditorLoaded ? latest : current;
        value = base.copyWith(
          isSaving: false,
          error: 'This note could not be deleted from the device.',
        );
      }
      return false;
    }
  }

  void _update(ClinicalNote Function(ClinicalNote note) transform) {
    if (disposed) return;
    final current = value;
    if (_deleted || current is! NoteEditorLoaded) return;
    final updated = transform(current.note).copyWith(updatedAt: DateTime.now());
    value = current.copyWith(
      note: updated,
      hasUnsavedChanges: true,
      clearError: true,
    );
    _debouncer(() => saveNow());
  }

  static String _messageFor(Object error) {
    if (error is AppException) return error.message;
    return 'The note could not be loaded from this device.';
  }

  Future<void>? _closeFuture;

  /// Flushes pending edits and tears the editor down.
  ///
  /// Callers that can await (tests, explicit teardown) use [close]; widget
  /// lifecycle calls [dispose], which starts the same flush without awaiting.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _debouncer.cancel();
    final current = value;
    if (!_deleted &&
        !disposed &&
        current is NoteEditorLoaded &&
        current.hasUnsavedChanges) {
      // Flush pending edits before tearing the editor down.
      try {
        await _repository.save(
          current.note.copyWith(updatedAt: DateTime.now()),
        );
      } catch (_) {
        // Close must not mask teardown with a failed best-effort save.
      }
    }
    super.dispose();
  }

  @override
  void dispose() {
    close().ignore();
  }
}
