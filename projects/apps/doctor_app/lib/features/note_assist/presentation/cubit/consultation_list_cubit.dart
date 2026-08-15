import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'consultation_list_state.dart';

/// Loads and filters the local consultation list.
///
/// Data source is the on-device [NoteLocalRepository], so the list works
/// fully offline. Filtering (search + status + date) and pagination are
/// applied in state so the UI stays declarative.
class ConsultationListCubit extends Cubit<ConsultationListState> {
  final NoteLocalRepository _localRepository;
  final SyncQueueService? _syncQueueService;

  static const _pageSize = 20;
  static const _searchDebounce = Duration(milliseconds: 300);

  Timer? _searchDebounceTimer;

  ConsultationListCubit({
    required NoteLocalRepository localRepository,
    SyncQueueService? syncQueueService,
  })  : _localRepository = localRepository,
        _syncQueueService = syncQueueService,
        super(ConsultationListLoading());

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }

  Future<void> load() async {
    try {
      final notes = await _localRepository.getAllConsultations();
      emit(ConsultationListLoaded(
        all: notes.map(ConsultationListItem.fromNote).toList(),
      ));
    } catch (e) {
      emit(ConsultationListError('Failed to load consultations: $e'));
    }
  }

  /// Reload from disk while preserving the current search/filter.
  ///
  /// Flushes the sync queue first (if available) so freshly-synced notes
  /// appear immediately (pull-to-refresh contract).
  Future<void> refresh() async {
    final current = state;
    if (current is! ConsultationListLoaded) {
      await _flushQueue();
      return load();
    }
    emit(current.copyWith(isRefreshing: true));
    try {
      await _flushQueue();
      final notes = await _localRepository.getAllConsultations();
      emit(ConsultationListLoaded(
        all: notes.map(ConsultationListItem.fromNote).toList(),
        searchQuery: current.searchQuery,
        statusFilter: current.statusFilter,
        dateFilter: current.dateFilter,
        visibleCount: current.visibleCount,
      ));
    } catch (e) {
      emit(current.copyWith(isRefreshing: false));
    }
  }

  Future<void> _flushQueue() async {
    try {
      await _syncQueueService?.syncNow();
    } catch (_) {
      // Sync failure must not block the list refresh.
    }
  }

  /// Debounced search — the query is applied [Duration] after the last
  /// keystroke so state isn't churned on every character.
  void search(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      final current = state;
      if (current is! ConsultationListLoaded) return;
      emit(current.copyWith(
        searchQuery: query,
        visibleCount: _pageSize,
      ));
    });
  }

  void filterByStatus(NoteStatus? status) {
    final current = state;
    if (current is! ConsultationListLoaded) return;
    emit(ConsultationListLoaded(
      all: current.all,
      searchQuery: current.searchQuery,
      statusFilter: status,
      dateFilter: current.dateFilter,
      visibleCount: _pageSize,
    ));
  }

  void filterByDate(DateFilter filter) {
    final current = state;
    if (current is! ConsultationListLoaded) return;
    emit(ConsultationListLoaded(
      all: current.all,
      searchQuery: current.searchQuery,
      statusFilter: current.statusFilter,
      dateFilter: filter,
      visibleCount: _pageSize,
    ));
  }

  /// Reveal the next page of results (clamped to the full result set so the
  /// final partial page is always reachable).
  void loadMore() {
    final current = state;
    if (current is! ConsultationListLoaded) return;
    if (current.visibleCount >= current.filtered.length) return;
    final next = current.visibleCount + _pageSize;
    emit(current.copyWith(
      visibleCount: next > current.filtered.length
          ? current.filtered.length
          : next,
    ));
  }

  /// Whether there are more filtered results to load.
  bool get hasMore {
    final current = state;
    return current is ConsultationListLoaded &&
        current.visibleCount < current.filtered.length;
  }
}
