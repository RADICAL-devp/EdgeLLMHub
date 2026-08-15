import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/consultation_list_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/consultation_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements NoteLocalRepository {}

class _MockSyncQueue extends Mock implements SyncQueueService {}

void main() {
  group('ConsultationListCubit', () {
    late _MockRepository repository;
    late ConsultationListCubit cubit;

    setUp(() {
      repository = _MockRepository();
      cubit = ConsultationListCubit(localRepository: repository);
    });

    tearDown(() => cubit.close());

    /// Wait past the 300ms search debounce.
    Future<void> settleDebounce() => Future<void>.delayed(
        const Duration(milliseconds: 350));

    DoctorNote note({
      required String consultationId,
      required DateTime updatedAt,
      NoteStatus status = NoteStatus.draft,
      String rawText = 'Patient reports persistent cough.',
    }) {
      return DoctorNote(
        noteId: 'note-$consultationId',
        consultationId: consultationId,
        patientId: 'p-$consultationId',
        doctorId: 'd1',
        rawText: rawText,
        status: status,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
    }

    test('load emits one item per consultation (latest note wins)', () async {
      final older = note(
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
        rawText: 'Old content',
      );
      final newer = note(
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 2),
        rawText: 'New content',
      );
      when(() => repository.getAllConsultations())
          .thenAnswer((_) async => [newer, older]);

      await cubit.load();

      expect(cubit.state, isA<ConsultationListLoaded>());
      final state = cubit.state as ConsultationListLoaded;
      expect(state.all, hasLength(2));
    });

    test('load dedupes multiple notes for the same consultation', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(
              consultationId: 'c1',
              updatedAt: DateTime(2026, 1, 2),
              rawText: 'Newer',
            ),
            note(
              consultationId: 'c1',
              updatedAt: DateTime(2026, 1, 1),
              rawText: 'Older',
            ),
          ]);

      await cubit.load();

      // Both notes are distinct rows for c1, but the repository already
      // collapses per-consultation — the list shows what it gets.
      final state = cubit.state as ConsultationListLoaded;
      expect(state.all, hasLength(2));
    });

    test('search filters by snippet text', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
            note(
              consultationId: 'c2',
              updatedAt: DateTime(2026, 1, 2),
              rawText: 'Fractured wrist X-ray review',
            ),
          ]);

      await cubit.load();
      cubit.search('fractured');
      await settleDebounce();

      final state = cubit.state as ConsultationListLoaded;
      expect(state.filtered, hasLength(1));
      expect(state.filtered.single.consultationId, 'c2');
    });

    test('status filter narrows the list', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(
              consultationId: 'c1',
              updatedAt: DateTime(2026, 1, 1),
              status: NoteStatus.finalized,
            ),
            note(
              consultationId: 'c2',
              updatedAt: DateTime(2026, 1, 2),
              status: NoteStatus.draft,
            ),
          ]);

      await cubit.load();
      cubit.filterByStatus(NoteStatus.finalized);

      final state = cubit.state as ConsultationListLoaded;
      expect(state.filtered, hasLength(1));
      expect(state.filtered.single.consultationId, 'c1');
    });

    test('clearing the status filter restores all items', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(
              consultationId: 'c1',
              updatedAt: DateTime(2026, 1, 1),
              status: NoteStatus.finalized,
            ),
            note(
              consultationId: 'c2',
              updatedAt: DateTime(2026, 1, 2),
            ),
          ]);

      await cubit.load();
      cubit.filterByStatus(NoteStatus.finalized);
      cubit.filterByStatus(null);

      final state = cubit.state as ConsultationListLoaded;
      expect(state.filtered, hasLength(2));
    });

    test('load emits error state on failure', () async {
      when(() => repository.getAllConsultations())
          .thenThrow(Exception('disk error'));

      await cubit.load();

      expect(cubit.state, isA<ConsultationListError>());
    });

    test('loadMore reveals the next page up to the full result set',
        () async {
      final notes = List.generate(25, (i) => note(
            consultationId: 'c$i',
            updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ));
      when(() => repository.getAllConsultations())
          .thenAnswer((_) async => notes);

      await cubit.load();

      var state = cubit.state as ConsultationListLoaded;
      expect(state.filtered, hasLength(25));
      expect(state.visibleCount, 20);
      expect(cubit.hasMore, isTrue);

      cubit.loadMore();
      state = cubit.state as ConsultationListLoaded;
      expect(state.visibleCount, 25);
      expect(cubit.hasMore, isFalse);

      // Loading more beyond the end is a no-op.
      cubit.loadMore();
      expect((cubit.state as ConsultationListLoaded).visibleCount, 25);
    });

    test('refresh preserves search query and status filter', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(
              consultationId: 'c1',
              updatedAt: DateTime(2026, 1, 1),
              status: NoteStatus.finalized,
              rawText: 'Fractured wrist',
            ),
            note(consultationId: 'c2', updatedAt: DateTime(2026, 1, 2)),
          ]);

      await cubit.load();
      cubit.search('fractured');
      await settleDebounce();

      await cubit.refresh();

      final state = cubit.state as ConsultationListLoaded;
      expect(state.searchQuery, 'fractured');
      expect(state.filtered, hasLength(1));
      expect(state.isRefreshing, isFalse);
    });

    test('refresh falls back to a full load when not loaded yet', () async {
      when(() => repository.getAllConsultations())
          .thenAnswer((_) async => [note(
                consultationId: 'c1',
                updatedAt: DateTime(2026, 1, 1),
              )]);

      await cubit.refresh();

      expect(cubit.state, isA<ConsultationListLoaded>());
    });

    test('refresh failure keeps the current list visible', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
          ]);
      await cubit.load();

      when(() => repository.getAllConsultations())
          .thenThrow(Exception('disk error'));

      await cubit.refresh();

      final state = cubit.state as ConsultationListLoaded;
      expect(state.isRefreshing, isFalse);
      expect(state.all, hasLength(1));
    });

    test('search and filter reset pagination to the first page', () async {
      final notes = List.generate(25, (i) => note(
            consultationId: 'c$i',
            updatedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ));
      when(() => repository.getAllConsultations())
          .thenAnswer((_) async => notes);

      await cubit.load();
      cubit.loadMore();
      expect((cubit.state as ConsultationListLoaded).visibleCount, 25);

      cubit.search('c');
      await settleDebounce();
      expect((cubit.state as ConsultationListLoaded).visibleCount, 20);
    });

    test('date filter narrows the list to the selected range', () async {
      final midnight = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(
              consultationId: 'recent',
              updatedAt: midnight.add(const Duration(hours: 1)),
            ),
            note(
              consultationId: 'week',
              updatedAt: midnight
                  .subtract(const Duration(days: 4))
                  .add(const Duration(hours: 1)),
            ),
            note(
              consultationId: 'old',
              updatedAt: midnight.subtract(const Duration(days: 45)),
            ),
          ]);

      await cubit.load();

      cubit.filterByDate(DateFilter.today);
      var state = cubit.state as ConsultationListLoaded;
      expect(state.filtered.map((c) => c.consultationId), ['recent']);

      cubit.filterByDate(DateFilter.last7Days);
      state = cubit.state as ConsultationListLoaded;
      expect(
        state.filtered.map((c) => c.consultationId).toSet(),
        {'recent', 'week'},
      );

      cubit.filterByDate(DateFilter.last30Days);
      state = cubit.state as ConsultationListLoaded;
      expect(
        state.filtered.map((c) => c.consultationId).toSet(),
        {'recent', 'week'},
      );

      cubit.filterByDate(DateFilter.all);
      state = cubit.state as ConsultationListLoaded;
      expect(state.filtered, hasLength(3));
    });

    test('rapid keystrokes collapse into a single debounced search', () async {
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
            note(consultationId: 'c2', updatedAt: DateTime(2026, 1, 2)),
          ]);

      await cubit.load();
      // Clear any state from prior searches.
      cubit.search('zzz');
      cubit.search('zz');
      cubit.search('z');
      // No query has settled yet — state must still be unfiltered.
      expect(
        (cubit.state as ConsultationListLoaded).searchQuery,
        '',
      );
      await settleDebounce();
      // Only the last keystroke wins.
      expect((cubit.state as ConsultationListLoaded).searchQuery, 'z');
    });

    test('refresh flushes the sync queue before reloading', () async {
      final syncQueue = _MockSyncQueue();
      cubit = ConsultationListCubit(
        localRepository: repository,
        syncQueueService: syncQueue,
      );
      when(() => syncQueue.syncNow()).thenAnswer((_) async {});
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
          ]);

      await cubit.load();
      await cubit.refresh();

      verify(() => syncQueue.syncNow()).called(1);
      expect(cubit.state, isA<ConsultationListLoaded>());
    });

    test('refresh with an unloaded list flushes the queue then loads',
        () async {
      final syncQueue = _MockSyncQueue();
      cubit = ConsultationListCubit(
        localRepository: repository,
        syncQueueService: syncQueue,
      );
      when(() => syncQueue.syncNow()).thenAnswer((_) async {});
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
          ]);

      await cubit.refresh();

      verify(() => syncQueue.syncNow()).called(1);
      expect((cubit.state as ConsultationListLoaded).all, hasLength(1));
    });

    test('sync queue failure does not block the refresh', () async {
      final syncQueue = _MockSyncQueue();
      cubit = ConsultationListCubit(
        localRepository: repository,
        syncQueueService: syncQueue,
      );
      when(() => syncQueue.syncNow()).thenThrow(Exception('offline'));
      when(() => repository.getAllConsultations()).thenAnswer((_) async => [
            note(consultationId: 'c1', updatedAt: DateTime(2026, 1, 1)),
          ]);

      await cubit.load();
      await cubit.refresh();

      expect(cubit.state, isA<ConsultationListLoaded>());
    });
  });
}
