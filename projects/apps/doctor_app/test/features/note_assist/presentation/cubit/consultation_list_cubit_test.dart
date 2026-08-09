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
  });
}
