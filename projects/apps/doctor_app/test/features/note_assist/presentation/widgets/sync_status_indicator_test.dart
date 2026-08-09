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

  DoctorNote note({
    required String consultationId,
    required DateTime updatedAt,
    String rawText = 'content',
  }) {
    return DoctorNote(
      noteId: 'n-$consultationId',
      consultationId: consultationId,
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  // Drift's watch() stream schedules a zero-duration timer when the
  // StreamBuilder is disposed. Unmounting the tree inside the test body and
  // pumping lets the fake clock flush that timer before the end-of-test
  // pending-timer check.
  Future<void> unmountTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('shows Saved when nothing is queued', (tester) async {
    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(consultationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('shows Pending sync when an entry is queued', (tester) async {
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(consultationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pending sync'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('shows Conflict when the entry is conflicted', (tester) async {
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
    ));
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
      rawText: 'second edit',
    ));

    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(consultationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Conflict'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('shows Syncing when isSyncing is set', (tester) async {
    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(
        consultationId: 'c1',
        isSyncing: true,
      ),
    ));
    // The spinner animates indefinitely — pump instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Syncing…'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('shows Offline when syncError is present', (tester) async {
    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(
        consultationId: 'c1',
        syncError: 'server unreachable',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('tapping the indicator opens the details sheet', (tester) async {
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(consultationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pending sync'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync details'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
    await unmountTree(tester);
  });

  testWidgets('conflicted entry shows Resolve conflict action',
      (tester) async {
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
    ));
    await service.enqueueNote(note(
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
      rawText: 'second edit',
    ));

    await tester.pumpWidget(wrap(
      const SyncStatusIndicator(consultationId: 'c1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conflict'));
    await tester.pumpAndSettle();

    expect(find.text('Resolve conflict'), findsOneWidget);
    await unmountTree(tester);
  });
}
