import 'dart:convert';
import 'dart:typed_data';

import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/features/note_assist/data/remote/note_remote_datasource.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:dio/dio.dart';
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

DioException _dioException(
  DioExceptionType type, {
  int? statusCode,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/doctor-notes/sync'),
    type: type,
    response: statusCode != null
        ? Response(
            requestOptions: RequestOptions(path: '/api/doctor-notes/sync'),
            statusCode: statusCode,
          )
        : null,
  );
}

void main() {
  late Dio dio;
  late NoteRemoteDatasource datasource;
  late _FakeAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    datasource = NoteRemoteDatasource(dio);
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
  });

  group('syncNote', () {
    test('POSTs the note and succeeds when the backend accepts it', () async {
      adapter.responses.add(
        const _Response(
          statusCode: 200,
          body: {'synced': true, 'noteId': 'n1'},
        ),
      );

      await datasource.syncNote(_note());

      expect(adapter.paths, ['/api/v1/notes/sync']);
      expect(adapter.methods, ['POST']);
      final payload =
          jsonDecode(adapter.bodies.single) as Map<String, dynamic>;
      expect(payload['noteId'], 'n1');
      expect(payload['consultationId'], 'c1');
      expect(payload['status'], 'draft');
    });

    test('throws NetworkException on server failure (500)', () async {
      adapter.errors.add(_dioException(DioExceptionType.badResponse, statusCode: 500));

      await expectLater(
        datasource.syncNote(_note()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException on connection failure', () async {
      adapter.errors.add(_dioException(DioExceptionType.connectionError));

      await expectLater(
        datasource.syncNote(_note()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('fetchNoteForConsultation', () {
    test('parses the note returned by the backend', () async {
      adapter.responses.add(
        _Response(
          statusCode: 200,
          body: {
            'noteId': 'n1',
            'consultationId': 'c1',
            'patientId': 'p1',
            'doctorId': 'd1',
            'rawText': 'content',
            'richTextDelta': '{"ops":[]}',
            'status': 'finalized',
            'extractedFields': {
              'symptoms': ['SOB'],
              'provisionalDiagnosis': 'DM2',
            },
            'patientRecap': 'Known DM2.',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-02T00:00:00.000Z',
          },
        ),
      );

      final note = await datasource.fetchNoteForConsultation('c1');

      expect(note, isNotNull);
      expect(note!.noteId, 'n1');
      expect(note.rawText, 'content');
      expect(note.status, NoteStatus.finalized);
      expect(note.richTextDelta, '{"ops":[]}');
      expect(note.extractedFields?.provisionalDiagnosis, 'DM2');
      expect(note.patientRecap, 'Known DM2.');
      expect(adapter.paths, ['/api/v1/notes/consultation/c1']);
    });

    test('returns null when the note does not exist (404)', () async {
      adapter.responses.add(
        const _Response(statusCode: 404, body: {}),
      );

      final result = await datasource.fetchNoteForConsultation('c1');
      expect(result, isNull);
    });

    test('throws NetworkException for non-404 Dio failures', () async {
      adapter.errors.add(_dioException(DioExceptionType.badResponse, statusCode: 500));

      await expectLater(
        datasource.fetchNoteForConsultation('c1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

class _Response {
  const _Response({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Fake adapter recording requests, with queues for success responses
/// and thrown errors.
class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<String> methods = [];
  final List<String> bodies = [];
  final List<Object> errors = [];
  final List<_Response> responses = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    methods.add(options.method);
    final body =
        requestStream != null ? await utf8.decoder.bind(requestStream).join() : '';
    bodies.add(body);

    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
