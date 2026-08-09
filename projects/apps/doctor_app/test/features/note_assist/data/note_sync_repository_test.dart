import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/features/note_assist/data/local/note_local_repository.dart';
import 'package:doctor_app/features/note_assist/data/remote/note_remote_datasource.dart';
import 'package:doctor_app/features/note_assist/data/repositories/note_sync_repository.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalRepository extends Mock implements NoteLocalRepository {}

class _MockRemoteDatasource extends Mock implements NoteRemoteDatasource {}

void main() {
  late _MockLocalRepository localRepository;
  late _MockRemoteDatasource remoteDatasource;
  late NoteSyncRepository repository;

  setUp(() {
    localRepository = _MockLocalRepository();
    remoteDatasource = _MockRemoteDatasource();
    repository = NoteSyncRepository(localRepository, remoteDatasource);
    registerFallbackValue(DoctorNote(
      noteId: 'n1',
      consultationId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      rawText: 'content',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
  });

  group('syncNoteToBackend', () {
    test('pushes the latest local note and completes', () async {
      final note = DoctorNote(
        noteId: 'n1',
        consultationId: 'c1',
        patientId: 'p1',
        doctorId: 'd1',
        rawText: 'content',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localRepository.getNoteByConsultationId('c1'))
          .thenAnswer((_) async => note);
      when(() => remoteDatasource.syncNote(any())).thenAnswer((_) async {});

      await repository.syncNoteToBackend('c1');

      verify(() => remoteDatasource.syncNote(note)).called(1);
    });

    test('skips when no local note exists', () async {
      when(() => localRepository.getNoteByConsultationId('c1'))
          .thenAnswer((_) async => null);

      await repository.syncNoteToBackend('c1');

      verifyNever(() => remoteDatasource.syncNote(any()));
    });

    test('wraps local read failures in DatabaseException', () async {
      when(() => localRepository.getNoteByConsultationId('c1'))
          .thenThrow(StateError('db locked'));

      await expectLater(
        repository.syncNoteToBackend('c1'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('rethrows NetworkException from the remote', () async {
      when(() => localRepository.getNoteByConsultationId('c1'))
          .thenAnswer((_) async => DoctorNote(
                noteId: 'n1',
                consultationId: 'c1',
                patientId: 'p1',
                doctorId: 'd1',
                rawText: 'x',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ));
      when(() => remoteDatasource.syncNote(any())).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );

      await expectLater(
        repository.syncNoteToBackend('c1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('wraps unexpected remote errors as transient NetworkException',
        () async {
      when(() => localRepository.getNoteByConsultationId('c1'))
          .thenAnswer((_) async => DoctorNote(
                noteId: 'n1',
                consultationId: 'c1',
                patientId: 'p1',
                doctorId: 'd1',
                rawText: 'x',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ));
      when(() => remoteDatasource.syncNote(any()))
          .thenThrow(StateError('boom'));

      await expectLater(
        repository.syncNoteToBackend('c1'),
        throwsA(isA<NetworkException>()
            .having((e) => e.isTransient, 'isTransient', isTrue)),
      );
    });
  });

  group('syncAllPending', () {
    test('collects per-item results without aborting', () async {
      when(() => localRepository.getNoteByConsultationId(any()))
          .thenAnswer((_) async => DoctorNote(
                noteId: 'n',
                consultationId: 'c',
                patientId: 'p',
                doctorId: 'd',
                rawText: 'x',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ));
      when(() => remoteDatasource.syncNote(any())).thenThrow(
        const NetworkException('Cannot reach server', isTransient: true),
      );

      final result = await repository.syncAllPending(['c1', 'c2']);

      expect(result.succeeded, 0);
      expect(result.failed, 2);
      expect(result.errors, hasLength(2));
      expect(result.hasErrors, isTrue);
    });

    test('reports mixed success and failure counts', () async {
      when(() => localRepository.getNoteByConsultationId(any()))
          .thenAnswer((_) async => DoctorNote(
                noteId: 'n',
                consultationId: 'c',
                patientId: 'p',
                doctorId: 'd',
                rawText: 'x',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ));
      var call = 0;
      when(() => remoteDatasource.syncNote(any())).thenAnswer((_) async {
        call++;
        if (call > 1) {
          throw const NetworkException('Cannot reach server');
        }
      });

      final result = await repository.syncAllPending(['c1', 'c2', 'c3']);

      expect(result.succeeded, 1);
      expect(result.failed, 2);
    });
  });
}
