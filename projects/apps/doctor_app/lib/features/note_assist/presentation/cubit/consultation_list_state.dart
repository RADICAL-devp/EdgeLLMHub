import 'package:equatable/equatable.dart';
import '../../domain/models/doctor_note.dart';

/// Lightweight summary of a single consultation shown in the list view.
class ConsultationListItem extends Equatable {
  final String consultationId;
  final String patientId;
  final String doctorId;
  final String noteId;
  final String snippet;
  final NoteStatus status;
  final DateTime updatedAt;

  const ConsultationListItem({
    required this.consultationId,
    required this.patientId,
    required this.doctorId,
    required this.noteId,
    required this.snippet,
    required this.status,
    required this.updatedAt,
  });

  factory ConsultationListItem.fromNote(DoctorNote note) {
    final text = note.rawText.trim();
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ');
    final snippet = singleLine.length > 140
        ? '${singleLine.substring(0, 140)}…'
        : singleLine;

    return ConsultationListItem(
      consultationId: note.consultationId,
      patientId: note.patientId,
      doctorId: note.doctorId,
      noteId: note.noteId,
      snippet: snippet.isEmpty
          ? 'No notes yet — tap to start dictating'
          : snippet,
      status: note.status,
      updatedAt: note.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        consultationId,
        patientId,
        doctorId,
        noteId,
        snippet,
        status,
        updatedAt,
      ];
}

abstract class ConsultationListState extends Equatable {
  const ConsultationListState();

  @override
  List<Object?> get props => [];
}

/// Preset date ranges for the list filter.
enum DateFilter {
  all('All'),
  today('Today'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days');

  const DateFilter(this.label);

  final String label;
}

class ConsultationListLoading extends ConsultationListState {}

class ConsultationListError extends ConsultationListState {
  final String message;

  const ConsultationListError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Value-based state: [list] always holds freshly-filtered results, so the
/// list widget never has to re-apply search/filter logic itself.
class ConsultationListLoaded extends ConsultationListState {
  final List<ConsultationListItem> all;
  final String searchQuery;
  final NoteStatus? statusFilter;
  final DateFilter dateFilter;
  final bool isRefreshing;
  final int visibleCount;

  const ConsultationListLoaded({
    required this.all,
    this.searchQuery = '',
    this.statusFilter,
    this.dateFilter = DateFilter.all,
    this.isRefreshing = false,
    this.visibleCount = 20,
  });

  /// Consultations matching the active search query, status, and date filters.
  List<ConsultationListItem> get filtered {
    final q = searchQuery.trim().toLowerCase();
    final cutoff = switch (dateFilter) {
      DateFilter.all => null,
      DateFilter.today => _startOfToday(),
      DateFilter.last7Days => DateTime.now().subtract(const Duration(days: 7)),
      DateFilter.last30Days =>
        DateTime.now().subtract(const Duration(days: 30)),
    };
    return all.where((c) {
      if (statusFilter != null && c.status != statusFilter) return false;
      if (cutoff != null && c.updatedAt.isBefore(cutoff)) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${c.consultationId} ${c.patientId} ${c.snippet}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Whether [index] in [filtered] is visible (pagination).
  bool isVisible(int index) => index < visibleCount;

  ConsultationListLoaded copyWith({
    List<ConsultationListItem>? all,
    String? searchQuery,
    NoteStatus? statusFilter,
    DateFilter? dateFilter,
    bool? isRefreshing,
    int? visibleCount,
  }) {
    return ConsultationListLoaded(
      all: all ?? this.all,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      visibleCount: visibleCount ?? this.visibleCount,
    );
  }

  @override
  List<Object?> get props => [
        all,
        searchQuery,
        statusFilter,
        dateFilter,
        isRefreshing,
        visibleCount,
      ];
}