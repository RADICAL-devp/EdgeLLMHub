import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/widgets/sync_status_indicator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_helpers.dart';

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

void main() {
  late LocalDatabase db;
  late SyncQueueService service;

  setUp(() {
    db = LocalDatabase.connect(NativeDatabase.memory());
    service = SyncQueueService(
      syncRepository: _MockSyncRepository(),
      database: db,
    );
    GetIt.I.registerSingleton<SyncQueueService>(service);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  DoctorNote note({required DateTime updatedAt, String rawText = 'content'}) {
    return DoctorNote(
      noteId: 'n-c1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final suffix = brightness == Brightness.dark ? ' dark' : '';

    testWidgets('saved state$suffix', (tester) async {
      await matchGolden(
        tester,
        const Scaffold(
          body: Center(
            child: SyncStatusIndicator(consultationId: 'c1'),
          ),
        ),
        name: 'sync_status_saved',
        brightness: brightness,
      );
      await unmountTree(tester);
    });

    testWidgets('pending state$suffix', (tester) async {
      await service.enqueueNote(note(updatedAt: DateTime(2026, 1, 1)));
      await matchGolden(
        tester,
        const Scaffold(
          body: Center(
            child: SyncStatusIndicator(consultationId: 'c1'),
          ),
        ),
        name: 'sync_status_pending',
        brightness: brightness,
      );
      await unmountTree(tester);
    });

    testWidgets('conflict state$suffix', (tester) async {
      await service.enqueueNote(note(updatedAt: DateTime(2026, 1, 1)));
      await service.enqueueNote(
        note(updatedAt: DateTime(2026, 1, 1), rawText: 'second edit'),
      );
      await matchGolden(
        tester,
        const Scaffold(
          body: Center(
            child: SyncStatusIndicator(consultationId: 'c1'),
          ),
        ),
        name: 'sync_status_conflict',
        brightness: brightness,
      );
      await unmountTree(tester);
    });

    testWidgets('syncing state$suffix', (tester) async {
      await matchGolden(
        tester,
        const Scaffold(
          body: Center(
            child: SyncStatusIndicator(
              consultationId: 'c1',
              isSyncing: true,
            ),
          ),
        ),
        name: 'sync_status_syncing',
        brightness: brightness,
        settle: false,
      );
      await unmountTree(tester);
    });

    testWidgets('offline state$suffix', (tester) async {
      await matchGolden(
        tester,
        const Scaffold(
          body: Center(
            child: SyncStatusIndicator(
              consultationId: 'c1',
              syncError: 'server unreachable',
            ),
          ),
        ),
        name: 'sync_status_offline',
        brightness: brightness,
      );
      await unmountTree(tester);
    });
  }
}
