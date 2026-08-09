import 'package:bloc/bloc.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'consultation_list_state.dart';

/// Loads and filters the local consultation list.
///
/// Data source is the on-device [NoteLocalRepository], so the list works
/// fully offline. Filtering (search + status) and pagination are applied in
/// state so the UI stays declarative.
class ConsultationListCubit extends Cubit<ConsultationListState> {
  final NoteLocalRepository _localRepository;

  static const _pageSize = 20;

  ConsultationListCubit({required NoteLocalRepository localRepository})
      : _localRepository = localRepository,
        super(ConsultationListLoading());

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
  Future<void> refresh() async {
    final current = state;
    if (current is! ConsultationListLoaded) {
      return load();
    }
    emit(current.copyWith(isRefreshing: true));
    try {
      final notes = await _localRepository.getAllConsultations();
      emit(ConsultationListLoaded(
        all: notes.map(ConsultationListItem.fromNote).toList(),
        searchQuery: current.searchQuery,
        statusFilter: current.statusFilter,
        visibleCount: current.visibleCount,
      ));
    } catch (e) {
      emit(current.copyWith(isRefreshing: false));
    }
  }

  void search(String query) {
    final current = state;
    if (current is! ConsultationListLoaded) return;
    emit(current.copyWith(
      searchQuery: query,
      visibleCount: _pageSize,
    ));
  }

  void filterByStatus(NoteStatus? status) {
    final current = state;
    if (current is! ConsultationListLoaded) return;
    emit(ConsultationListLoaded(
      all: current.all,
      searchQuery: current.searchQuery,
      statusFilter: status,
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
