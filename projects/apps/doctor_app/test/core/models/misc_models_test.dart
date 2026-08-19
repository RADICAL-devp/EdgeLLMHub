import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/services/speech_service.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/ai_assist_state.dart';
import 'package:doctor_app/features/note_assist/presentation/cubit/note_editor_state.dart';
import 'package:flutter_test/flutter_test.dart';

DoctorNote _note() => DoctorNote(
      noteId: 'n1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: 'content',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );

class _NoopSpeechService extends SpeechService {
  @override
  bool get isListening => false;

  @override
  Future<bool> initialize({
    String locale = 'en_US',
    Duration? silenceTimeout,
    double? listenTimeout,
  }) async =>
      true;

  @override
  Future<void> startListening(Function(String) onResult) async {}

  @override
  Future<void> stopListening() async {}
}

void main() {
  group('SyncQueueEntry', () {
    test('copyWith preserves unset fields and overrides given ones', () {
      final entry = SyncQueueEntry(
        id: 'id1',
        noteId: 'n1',
        consultationId: 'c1',
        operation: 'update',
        note: _note(),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final updated = entry.copyWith(
        retryCount: 3,
        lastError: 'boom',
        nextRetryAt: DateTime.utc(2026, 1, 3),
      );

      expect(updated.id, 'id1');
      expect(updated.retryCount, 3);
      expect(updated.lastError, 'boom');
      expect(updated.nextRetryAt, DateTime.utc(2026, 1, 3));
      expect(updated.operation, 'update');
      expect(updated.isDeadLetter, isFalse);
    });

    test('copyWith with null keeps existing nullable values (documented)', () {
      final entry = SyncQueueEntry(
        id: 'id1',
        noteId: 'n1',
        consultationId: 'c1',
        operation: 'update',
        note: _note(),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        nextRetryAt: DateTime.utc(2026, 1, 3),
        lastError: 'boom',
      );

      final updated = entry.copyWith(retryCount: 1);

      expect(updated.lastError, 'boom');
      expect(updated.nextRetryAt, DateTime.utc(2026, 1, 3));
      expect(updated.retryCount, 1);
    });

    test('round-trips through JSON', () {
      final entry = SyncQueueEntry(
        id: 'id1',
        noteId: 'n1',
        consultationId: 'c1',
        operation: 'create',
        note: _note(),
        retryCount: 2,
        maxRetries: 5,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        nextRetryAt: DateTime.utc(2026, 1, 3),
        lastError: 'network down',
        isDeadLetter: true,
        isConflict: true,
      );

      final restored = SyncQueueEntry.fromJson(entry.toJson());

      expect(restored.id, 'id1');
      expect(restored.operation, 'create');
      expect(restored.note.noteId, 'n1');
      expect(restored.retryCount, 2);
      expect(restored.nextRetryAt, DateTime.utc(2026, 1, 3));
      expect(restored.lastError, 'network down');
      expect(restored.isDeadLetter, isTrue);
      expect(restored.isConflict, isTrue);
    });
  });

  group('AiAssistState', () {
    test('equality distinguishes generating progress', () {
      const a = AiAssistGenerating('Hello', 'cleaning');
      const b = AiAssistGenerating('Hello', 'cleaning');
      const c = AiAssistGenerating('Hello world', 'cleaning');
      expect(a, b);
      expect(a == c, isFalse);
    });

    test('ready and error states expose their payloads', () {
      const ready = AiAssistSuggestionReady('Done', 'replace');
      const error = AiAssistError('boom');
      expect(ready.suggestion, 'Done');
      expect(ready.action, 'replace');
      expect(error.message, 'boom');
      expect(ready, const AiAssistSuggestionReady('Done', 'replace'));
    });
  });

  group('NoteEditorState', () {
    test('loaded copyWith overrides fields', () {
      final loaded = NoteEditorLoaded(note: _note()).copyWith(
        isSaving: true,
        isListening: true,
        lastSavedAt: DateTime.utc(2026, 1, 3),
        error: 'boom',
      );

      expect(loaded.isSaving, isTrue);
      expect(loaded.isListening, isTrue);
      expect(loaded.lastSavedAt, DateTime.utc(2026, 1, 3));
      expect(loaded.error, 'boom');
      expect(loaded.note.noteId, 'n1');
    });

    test('loading and error states compare by value', () {
      final loading = NoteEditorLoading();
      const error = NoteEditorError('boom');
      expect(loading, NoteEditorLoading());
      expect(error, const NoteEditorError('boom'));
      expect(error == const NoteEditorError('other'), isFalse);
    });
  });

  group('AppException hierarchy', () {
    test('toString includes the runtime type and message', () {
      const e = AppException('boom');
      expect(e.toString(), 'AppException: boom');
    });

    test('LlmException carries the provider', () {
      const e = LlmException('inference failed', provider: LlmProvider.mlc);
      expect(e.provider, LlmProvider.mlc);
      expect(e.toString(), contains('inference failed'));
    });

    test('specialized LLM exceptions subclass LlmException', () {
      const init = LlmInitializationException('init', provider: LlmProvider.gemma);
      const parse = LlmParseException('parse');
      expect(init, isA<LlmException>());
      expect(parse.provider, isNull);
    });

    test('network, speech, migration and compliance exceptions are typed',
        () {
      const circuit = CircuitBreakerOpenException();
      const speech = SpeechUnavailableException();
      const migration = DatabaseMigrationException(
        fromVersion: 4,
        toVersion: 5,
      );
      const compliance = ComplianceException('PHI may not leave device');

      expect(circuit, isA<NetworkException>());
      expect(circuit.isTransient, isTrue);
      expect(circuit.message, contains('Circuit breaker'));
      expect(speech, isA<SpeechException>());
      expect(speech.message, contains('not available'));
      expect(migration.message, contains('v4 to v5'));
      expect(migration.fromVersion, 4);
      expect(migration.toVersion, 5);
      expect(compliance.message, contains('PHI'));
    });
  });

  group('SpeechService defaults', () {
    test('default timeout setters are no-ops', () {
      final service = _NoopSpeechService();
      service.setSilenceTimeout(const Duration(seconds: 2));
      service.setListenTimeout(5);
      expect(service.isListening, isFalse);
    });
  });
}
