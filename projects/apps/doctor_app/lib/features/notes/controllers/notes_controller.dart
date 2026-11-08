import 'dart:async';

import 'package:signals/signals.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'notes_state.dart';

class NotesController extends Signal<NotesState> {
  NotesController({required NoteRepository repository})
    : _repository = repository,
      super(const NotesState());

  final NoteRepository _repository;

  Future<void> load() async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final notes = await _repository.getAll();
      if (disposed) return;
      value = value.copyWith(notes: notes, isLoading: false, clearError: true);
    } catch (error) {
      if (disposed) return;
      value = value.copyWith(
        isLoading: false,
        error: error is AppException
            ? error.message
            : 'The local notes could not be loaded.',
      );
    }
  }

  void setFilter(NotesFilter filter) {
    value = value.copyWith(filter: filter);
  }

  Future<void> deleteNote(String id) async {
    try {
      await _repository.deleteById(id);
      if (disposed) return;
      await load();
    } catch (error) {
      if (disposed) return;
      value = value.copyWith(
        error: error is AppException
            ? error.message
            : 'The note could not be deleted.',
      );
    }
  }
}

class NoteSearchController extends Signal<SearchState> {
  NoteSearchController({required NoteRepository repository})
    : _repository = repository,
      super(const SearchState());

  final NoteRepository _repository;
  Timer? _debounce;
  int _generation = 0;

  Future<void> search({bool immediate = false}) async {
    if (disposed) return;
    _debounce?.cancel();
    if (!immediate) {
      _debounce = Timer(AppConfig.searchDebounce, _run);
      return;
    }
    await _run();
  }

  Future<void> _run() async {
    if (disposed) return;
    final generation = ++_generation;
    value = value.copyWith(isSearching: true, clearError: true);
    try {
      final results = await _repository.search(
        value.query,
        from: value.from,
        to: value.to,
      );
      if (disposed || generation != _generation) return;
      value = value.copyWith(
        results: results,
        isSearching: false,
        hasSearched: true,
        clearError: true,
      );
    } catch (error) {
      if (disposed || generation != _generation) return;
      value = value.copyWith(
        isSearching: false,
        hasSearched: true,
        error: error is AppException
            ? error.message
            : 'Search could not read the local notes.',
      );
    }
  }

  void setQuery(String query) {
    value = value.copyWith(query: query, clearError: true);
    search();
  }

  void setDates(DateTime? from, DateTime? to) {
    value = value.copyWith(
      from: from,
      to: to,
      clearDates: from == null && to == null,
    );
    search(immediate: true);
  }

  void clearDates() {
    value = value.copyWith(clearDates: true);
    search(immediate: true);
  }

  void clearAll() {
    _debounce?.cancel();
    value = const SearchState();
    search(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
