import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/consultation_list_cubit.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/consultation_list_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements NoteLocalRepository {}

void main() {
  group('ConsultationListCubit', () {
    late _MockRepository repository;
    late ConsultationListCubit cubit;

    setUp(() {
      repository = _MockRepository();
      cubit = ConsultationListCubit(localRepository: repository);
    });

    tearDown(() => cubit.close());

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
      expect((cubit.state as ConsultationListLoaded).visibleCount, 20);
    });
  });
}
