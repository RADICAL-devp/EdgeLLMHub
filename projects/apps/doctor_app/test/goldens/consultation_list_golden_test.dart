import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/consultation_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_helpers.dart';

class _MockNoteLocalRepository extends Mock implements NoteLocalRepository {}

class _NoopSyncQueueService extends Mock implements SyncQueueService {}

void main() {
  late _MockNoteLocalRepository localRepository;
  late _NoopSyncQueueService syncQueueService;

  setUp(() {
    localRepository = _MockNoteLocalRepository();
    syncQueueService = _NoopSyncQueueService();
    GetIt.I.registerSingleton<NoteLocalRepository>(localRepository);
    GetIt.I.registerSingleton<SyncQueueService>(syncQueueService);
  });

  tearDown(() => GetIt.I.reset());

  DoctorNote note(String consultationId, String snippet, NoteStatus status,
      {DateTime? updatedAt}) {
    return DoctorNote(
      noteId: 'n-$consultationId',
      consultationId: consultationId,
      patientId: 'p$consultationId',
      doctorId: 'd1',
      rawText: snippet,
      status: status,
      createdAt: updatedAt ?? DateTime(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    );
  }

  GoRouter router() => GoRouter(
        initialLocation: '/consultations',
        routes: [
          GoRoute(
            path: '/consultations',
            builder: (context, state) => const ConsultationListPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Text('settings')),
          ),
          GoRoute(
            path: '/model_manager',
            builder: (context, state) =>
                const Scaffold(body: Text('model manager')),
          ),
        ],
      );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final suffix = brightness == Brightness.dark ? ' dark' : '';

    testWidgets('empty list$suffix', (tester) async {
      when(() => localRepository.getAllConsultations())
          .thenAnswer((_) async => []);
      await matchGolden(
        tester,
        const ConsultationListPage(),
        name: 'consultation_list_empty',
        brightness: brightness,
        router: router(),
      );
    });

    testWidgets('list with consultations$suffix', (tester) async {
      when(() => localRepository.getAllConsultations()).thenAnswer(
        (_) async => [
          note('c1', 'Patient reports persistent cough for three days.',
              NoteStatus.finalized,
              updatedAt: DateTime(2026, 2, 1)),
          note('c2', 'Follow-up on hypertension medication adjustments.',
              NoteStatus.draft,
              updatedAt: DateTime(2026, 2, 2)),
          note('c3', 'Pre-op assessment for knee replacement surgery.',
              NoteStatus.draft,
              updatedAt: DateTime(2026, 2, 3)),
        ],
      );
      await matchGolden(
        tester,
        const ConsultationListPage(),
        name: 'consultation_list_loaded',
        brightness: brightness,
        router: router(),
      );
    });
  }
}
