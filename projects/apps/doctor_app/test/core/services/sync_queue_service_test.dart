import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/local_database.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncRepository extends Mock implements NoteSyncRepository {}

void main() {
  late LocalDatabase db;
  late SyncQueueService service;
  late _MockSyncRepository syncRepository;

  setUp(() {
    db = LocalDatabase.connect(NativeDatabase.memory());
    syncRepository = _MockSyncRepository();
    service = SyncQueueService(
      syncRepository: syncRepository,
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  DoctorNote note({
    required String noteId,
    required String consultationId,
    required DateTime updatedAt,
    String rawText = 'content',
  }) {
    return DoctorNote(
      noteId: noteId,
      consultationId: consultationId,
      patientId: 'p1',
      doctorId: 'd1',
      rawText: rawText,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  group('SyncQueueService conflict detection', () {
    test('enqueue adds a pending entry', () async {
      final n = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
      );
      await service.enqueueNote(n);

      final entry = await service.getEntryForConsultation('c1');
      expect(entry, isNotNull);
      expect(entry!.isConflict, isFalse);
      expect(await service.getPendingCount(), 1);
    });

    test('newer note replaces the queued version (LWW)', () async {
      final older = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
        rawText: 'old',
      );
      final newer = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 2),
        rawText: 'new',
      );

      await service.enqueueNote(older);
      await service.enqueueNote(newer);

      final entry = await service.getEntryForConsultation('c1');
      expect(entry!.note.rawText, 'new');
      expect(entry.isConflict, isFalse);
      expect(await service.getPendingCount(), 1);
    });

    test('older note is ignored', () async {
      final newer = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 2),
        rawText: 'new',
      );
      final older = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
        rawText: 'old',
      );

      await service.enqueueNote(newer);
      await service.enqueueNote(older);

      final entry = await service.getEntryForConsultation('c1');
      expect(entry!.note.rawText, 'new');
    });

    test('same timestamp flags the entry as a conflict', () async {
      final first = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
        rawText: 'first edit',
      );
      final second = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
        rawText: 'second edit',
      );

      await service.enqueueNote(first);
      await service.enqueueNote(second);

      final entry = await service.getEntryForConsultation('c1');
      expect(entry, isNotNull);
      expect(entry!.isConflict, isTrue);
      expect(entry.note.rawText, 'first edit');
    });

  test('resolveConflict keeps the chosen note and clears the flag',
      () async {
    // Sync stays failing (transient) so the entry remains in the queue.
    when(() => syncRepository.syncNoteToBackend(any())).thenThrow(
      NetworkException(
        'backend unreachable',
        cause: Exception('offline'),
        isTransient: true,
      ),
    );

    final first = note(
      noteId: 'n1',
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
      rawText: 'first edit',
    );
    await service.enqueueNote(first);
    final second = note(
      noteId: 'n1',
      consultationId: 'c1',
      updatedAt: DateTime(2026, 1, 1),
      rawText: 'second edit',
    );
    await service.enqueueNote(second);

    final conflict = await service.getEntryForConsultation('c1');
    expect(conflict!.isConflict, isTrue);

    await service.resolveConflict(conflict.id, second);

    final resolved = await service.getEntryForConsultation('c1');
    expect(resolved!.isConflict, isFalse);
    expect(resolved.note.rawText, 'second edit');
  });

    test('discardQueuedVersion removes the entry', () async {
      final n = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
      );
      await service.enqueueNote(n);

      final entry = await service.getEntryForConsultation('c1');
      await service.discardQueuedVersion(entry!.id);

      expect(await service.getEntryForConsultation('c1'), isNull);
      expect(await service.getPendingCount(), 0);
    });

    test('watchEntries emits queue changes', () async {
      final n = note(
        noteId: 'n1',
        consultationId: 'c1',
        updatedAt: DateTime(2026, 1, 1),
      );

      final emissions = <int>[];
      final sub = service.watchEntries().listen((entries) {
        emissions.add(entries.length);
      });

      await service.enqueueNote(n);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await sub.cancel();
      expect(emissions, contains(1));
    });
  });
}
