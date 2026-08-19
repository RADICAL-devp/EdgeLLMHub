import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_repository.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase db;
  late _MockSyncRepository syncRepository;
  late SyncQueueService service;

  setUp(() {
    db = LocalDatabase.connect(NativeDatabase.memory());
    syncRepository = _MockSyncRepository();
    service = SyncQueueService(
      syncRepository: syncRepository,
      database: db,
    );
    registerFallbackValue(DoctorNote(
      noteId: 'n',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
  });

  tearDown(() async => db.close());

  DoctorNote note({
    required String consultationId,
    DateTime? updatedAt,
    NoteStatus status = NoteStatus.draft,
    String rawText = 'content',
  }) {
    return DoctorNote(
      noteId: 'note-$consultationId',
      consultationId: consultationId,
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      status: status,
      createdAt: updatedAt ?? DateTime(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    );
  }

  group('syncNow / queue processing', () {
    test('successful sync drains the queue', () async {
      when(() => syncRepository.syncNoteToBackend('c1'))
          .thenAnswer((_) async {});
      await service.enqueueNote(note(consultationId: 'c1'));

      await service.syncNow();

      expect(await service.getPendingCount(), 0);
      verify(() => syncRepository.syncNoteToBackend('c1')).called(1);
    });

    test('network failure applies backoff and keeps the entry pending',
        () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      await service.enqueueNote(note(consultationId: 'c1'));

      await service.syncNow();

      // The entry is scheduled for a future retry, so it is no longer
      // part of the ready-to-sync pending set — inspect the raw row.
      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw, hasLength(1));
      expect(raw.single.retryCount, 1);
      expect(raw.single.lastError, contains('Cannot reach server'));
      expect(raw.single.nextRetryAt, isNotNull);
      expect(raw.single.isDeadLetter, isFalse);
    });

    test('max retries exhausted moves the entry to the dead letter queue',
        () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      await service.enqueueNote(note(consultationId: 'c1'));

      // The default maxRetries is 5 — pump the retry counter to the limit.
      final repo = SyncQueueRepository(db);
      for (var i = 1; i < 5; i++) {
        await repo.updateEntry(
          (await service.getPendingEntries()).single.copyWith(
            retryCount: i,
            lastError: 'x',
            nextRetryAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          ),
        );
      }

      await service.syncNow();

      expect(await service.getPendingCount(), 0);
      final dead = await service.getDeadLetterEntries();
      expect(dead, hasLength(1));
      expect(dead.single.isDeadLetter, isTrue);
      expect(dead.single.lastError, contains('Max retries'));
    });

    test('non-transient failures skip the queue as dead letters', () async {
      when(() => syncRepository.syncNoteToBackend('c1'))
          .thenThrow(const DatabaseException('Invalid note reference'));
      await service.enqueueNote(note(consultationId: 'c1'));

      await service.syncNow();

      expect(await service.getPendingCount(), 0);
      expect(await service.getDeadLetterEntries(), hasLength(1));
      expect(
        (await service.getDeadLetterEntries()).single.lastError,
        contains('Invalid note reference'),
      );
    });

    test('unexpected errors are treated as transient and retried', () async {
      when(() => syncRepository.syncNoteToBackend('c1'))
          .thenThrow(StateError('boom'));
      await service.enqueueNote(note(consultationId: 'c1'));

      await service.syncNow();

      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw, hasLength(1));
      expect(raw.single.retryCount, 1);
      expect(raw.single.lastError, contains('Unexpected sync error'));
    });

    test('backoff delay is capped at 60s (min(2^n * 1s, 60s) + jitter)',
        () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      await service.enqueueNote(note(consultationId: 'c1'));

      // retryCount 7 → nextRetryCount 8 → 2^8 = 256s, which must be capped
      // at 60s. maxRetries 20 keeps the entry out of the dead letter queue.
      final repo = SyncQueueRepository(db);
      await repo.updateEntry(
        (await service.getPendingEntries()).single.copyWith(
          retryCount: 7,
          maxRetries: 20,
          lastError: 'seed',
          nextRetryAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        ),
      );

      await service.syncNow();

      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw, hasLength(1));
      expect(raw.single.retryCount, 8);
      expect(raw.single.isDeadLetter, isFalse);
      final delay = raw.single.nextRetryAt!.difference(DateTime.now().toUtc());
      // Cap of 60s + up to 1s jitter. Lower bound allows for wall-clock
      // drift between the retry-scheduling timestamp and this read.
      expect(delay.inSeconds, inInclusiveRange(59, 61));
    });

    test('dispose stops further queue processing', () async {
      when(() => syncRepository.syncNoteToBackend('c1'))
          .thenAnswer((_) async {});
      await service.enqueueNote(note(consultationId: 'c1'));

      service.dispose();
      await service.syncNow();

      // No processing happened — the entry is still queued.
      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw, hasLength(1));
      verifyNever(() => syncRepository.syncNoteToBackend('c1'));
    });
  });

  group('initialize / lifecycle', () {
    const backgroundTaskChannel = MethodChannel(
      'be.tramckrijte.workmanager/background_channel_work_manager',
    );
    const foregroundTaskChannel = MethodChannel(
      'be.tramckrijte.workmanager/foreground_channel_work_manager',
    );
    late _MockConnectivity connectivity;
    late StreamController<List<ConnectivityResult>> connectivityStream;

    setUp(() {
      connectivity = _MockConnectivity();
      connectivityStream = StreamController<List<ConnectivityResult>>.broadcast();
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityStream.stream);
      for (final channel in [backgroundTaskChannel, foregroundTaskChannel]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);
      }
    });

    tearDown(() async {
      for (final channel in [backgroundTaskChannel, foregroundTaskChannel]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
      await connectivityStream.close();
      service.dispose();
    });

    SyncQueueService lifecycleService() => SyncQueueService(
          syncRepository: syncRepository,
          database: db,
          connectivity: connectivity,
        );

    test('initialize processes the pending queue and registers listeners',
        () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      final svc = lifecycleService();
      await svc.enqueueNote(note(consultationId: 'c1'));

      await svc.initialize();

      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw, hasLength(1));
      expect(raw.single.retryCount, 1);
      svc.dispose();
    });

    test('regained connectivity flushes the queue', () async {
      when(() => syncRepository.syncNoteToBackend(any()))
          .thenAnswer((_) async {});
      final svc = lifecycleService();
      await svc.enqueueNote(note(consultationId: 'c1'));

      expect(await svc.getPendingCount(), 1);
      await svc.initialize();
      expect(await svc.getPendingCount(), 0);

      await svc.enqueueNote(note(consultationId: 'c2'));
      expect(await svc.getPendingCount(), 1);

      connectivityStream.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(await svc.getPendingCount(), 0);
      verify(() => syncRepository.syncNoteToBackend('c2')).called(1);
      svc.dispose();
    });

    test('offline connectivity events do not trigger processing', () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      final svc = lifecycleService();
      await svc.enqueueNote(note(consultationId: 'c1'));
      await svc.initialize();
      expect((await db.select(db.syncQueueEntries).get()).single.retryCount, 1);

      connectivityStream.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final raw = await db.select(db.syncQueueEntries).get();
      expect(raw.single.retryCount, 1);
      svc.dispose();
    });

    test('background task dispatcher acknowledges the sync task', () async {
      callbackDispatcher();
      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        backgroundTaskChannel.name,
        codec.encodeMethodCall(const MethodCall('backgroundChannelInitialized', {
          'be.tramckrijte.workmanager.DART_TASK':
              'com.doctorapp.syncQueue.backgroundSync',
          'be.tramckrijte.workmanager.INPUT_DATA': null,
        })),
        (_) {},
      );
    });
  });

  group('dead letter management', () {
    test('retryDeadLetterEntry resets and reprocesses the entry', () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      await service.enqueueNote(note(consultationId: 'c1'));
      final repo = SyncQueueRepository(db);
      await repo.updateEntry(
        (await service.getPendingEntries()).single.copyWith(
          retryCount: 4,
          isDeadLetter: true,
          lastError: 'exhausted',
        ),
      );
      expect(await service.getDeadLetterEntries(), hasLength(1));

      // Now the backend recovers.
      when(() => syncRepository.syncNoteToBackend('c1'))
          .thenAnswer((_) async {});

      final entry = (await service.getDeadLetterEntries()).single;
      await service.retryDeadLetterEntry(entry.id);

      expect(await service.getPendingCount(), 0);
      expect(await service.getDeadLetterEntries(), isEmpty);
      verify(() => syncRepository.syncNoteToBackend('c1')).called(1);
    });

    test('removeDeadLetterEntry permanently deletes it', () async {
      when(() => syncRepository.syncNoteToBackend('c1')).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );
      await service.enqueueNote(note(consultationId: 'c1'));
      final repo = SyncQueueRepository(db);
      await repo.updateEntry(
        (await service.getPendingEntries()).single.copyWith(
          retryCount: 4,
          isDeadLetter: true,
          lastError: 'exhausted',
        ),
      );

      final entry = (await service.getDeadLetterEntries()).single;
      await service.removeDeadLetterEntry(entry.id);

      expect(await service.getDeadLetterEntries(), isEmpty);
    });
  });
}
