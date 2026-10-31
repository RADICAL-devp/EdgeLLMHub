import 'package:equatable/equatable.dart';

import '../../../core/models/clinical_note.dart';

enum NotesFilter { all, drafts, finalized }

class NotesState extends Equatable {
  const NotesState({
    this.notes = const [],
    this.filter = NotesFilter.all,
    this.isLoading = false,
    this.error,
  });

  final List<ClinicalNote> notes;
  final NotesFilter filter;
  final bool isLoading;
  final String? error;

  List<ClinicalNote> get visibleNotes {
    switch (filter) {
      case NotesFilter.all:
        return notes;
      case NotesFilter.drafts:
        return notes
            .where((note) => note.status == NoteStatus.draft)
            .toList(growable: false);
      case NotesFilter.finalized:
        return notes
            .where((note) => note.status == NoteStatus.finalized)
            .toList(growable: false);
    }
  }

  int get draftCount =>
      notes.where((note) => note.status == NoteStatus.draft).length;

  int get finalizedCount =>
      notes.where((note) => note.status == NoteStatus.finalized).length;

  NotesState copyWith({
    List<ClinicalNote>? notes,
    NotesFilter? filter,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [notes, filter, isLoading, error];
}

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.from,
    this.to,
    this.results = const [],
    this.isSearching = false,
    this.hasSearched = false,
    this.error,
  });

  final String query;
  final DateTime? from;
  final DateTime? to;
  final List<ClinicalNote> results;
  final bool isSearching;
  final bool hasSearched;
  final String? error;

  bool get hasDateFilter => from != null || to != null;

  SearchState copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    List<ClinicalNote>? results,
    bool? isSearching,
    bool? hasSearched,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      hasSearched: hasSearched ?? this.hasSearched,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    query,
    from,
    to,
    results,
    isSearching,
    hasSearched,
    error,
  ];
}
