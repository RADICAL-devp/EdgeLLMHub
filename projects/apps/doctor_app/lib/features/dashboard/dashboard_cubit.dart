import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/data/note_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/models/clinical_note.dart';
import '../../../core/models/model_install_progress.dart';
import '../../../core/services/model_manager_service.dart';

class DashboardState extends Equatable {
  const DashboardState({
    this.totalNotes = 0,
    this.drafts = 0,
    this.finalized = 0,
    this.updatedToday = 0,
    this.recentNotes = const [],
    this.modelStatus,
    this.isLoading = true,
    this.error,
  });

  final int totalNotes;
  final int drafts;
  final int finalized;
  final int updatedToday;
  final List<ClinicalNote> recentNotes;
  final ModelStatus? modelStatus;
  final bool isLoading;
  final String? error;

  DashboardState copyWith({
    int? totalNotes,
    int? drafts,
    int? finalized,
    int? updatedToday,
    List<ClinicalNote>? recentNotes,
    ModelStatus? modelStatus,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      totalNotes: totalNotes ?? this.totalNotes,
      drafts: drafts ?? this.drafts,
      finalized: finalized ?? this.finalized,
      updatedToday: updatedToday ?? this.updatedToday,
      recentNotes: recentNotes ?? this.recentNotes,
      modelStatus: modelStatus ?? this.modelStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    totalNotes,
    drafts,
    finalized,
    updatedToday,
    recentNotes,
    modelStatus,
    isLoading,
    error,
  ];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required NoteRepository repository,
    required ModelManagerService models,
  }) : _repository = repository,
       _models = models,
       super(const DashboardState());

  final NoteRepository _repository;
  final ModelManagerService _models;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final notes = await _repository.getAll();
      final status = await _models.getStatus();
      if (isClosed) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final updatedToday = notes.where((note) {
        final date = note.updatedAt.toLocal();
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      }).length;
      emit(
        state.copyWith(
          totalNotes: notes.length,
          drafts: notes.where((note) => note.status == NoteStatus.draft).length,
          finalized: notes
              .where((note) => note.status == NoteStatus.finalized)
              .length,
          updatedToday: updatedToday,
          recentNotes: notes.take(3).toList(growable: false),
          modelStatus: status,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: error is AppException
              ? error.message
              : 'The dashboard could not load the local notes.',
        ),
      );
    }
  }
}
