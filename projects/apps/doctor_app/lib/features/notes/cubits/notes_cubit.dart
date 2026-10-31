import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  NotesCubit({required NoteRepository repository})
    : _repository = repository,
      super(const NotesState());

  final NoteRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final notes = await _repository.getAll();
      if (isClosed) return;
      emit(state.copyWith(notes: notes, isLoading: false, clearError: true));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: error is AppException
              ? error.message
              : 'The local notes could not be loaded.',
        ),
      );
    }
  }

  void setFilter(NotesFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  Future<void> deleteNote(String id) async {
    try {
      await _repository.deleteById(id);
      await load();
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          error: error is AppException
              ? error.message
              : 'The note could not be deleted.',
        ),
      );
    }
  }
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required NoteRepository repository})
    : _repository = repository,
      super(const SearchState());

  final NoteRepository _repository;
  Timer? _debounce;
  int _generation = 0;

  Future<void> search({bool immediate = false}) async {
    _debounce?.cancel();
    if (!immediate) {
      _debounce = Timer(AppConfig.searchDebounce, _run);
      return;
    }
    await _run();
  }

  Future<void> _run() async {
    final generation = ++_generation;
    emit(state.copyWith(isSearching: true, clearError: true));
    try {
      final results = await _repository.search(
        state.query,
        from: state.from,
        to: state.to,
      );
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          results: results,
          isSearching: false,
          hasSearched: true,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          isSearching: false,
          hasSearched: true,
          error: error is AppException
              ? error.message
              : 'Search could not read the local notes.',
        ),
      );
    }
  }

  void setQuery(String value) {
    emit(state.copyWith(query: value, clearError: true));
    search();
  }

  void setDates(DateTime? from, DateTime? to) {
    emit(
      state.copyWith(
        from: from,
        to: to,
        clearDates: from == null && to == null,
      ),
    );
    search(immediate: true);
  }

  void clearDates() {
    emit(state.copyWith(clearDates: true));
    search(immediate: true);
  }

  void clearAll() {
    _debounce?.cancel();
    emit(const SearchState());
    search(immediate: true);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
