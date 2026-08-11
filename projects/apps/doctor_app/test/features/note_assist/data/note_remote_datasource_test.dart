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

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    datasource = NoteRemoteDatasource(dio);
  });

  group('syncNote', () {
    test('succeeds when the backend accepts the note', () async {
      // The scaffold does not dispatch a real request yet; it always
      // pretends success. Ensure it completes without error.
      await datasource.syncNote(_note());
    });
  });

  group('fetchNoteForConsultation', () {
    test('returns null when the note does not exist (404)', () async {
      dio.httpClientAdapter = _ThrowingAdapter(
        _dioException(DioExceptionType.badResponse, statusCode: 404),
      );

      final result = await datasource.fetchNoteForConsultation('c1');
      expect(result, isNull);
    });

    test('throws NetworkException for non-404 Dio failures', () async {
      dio.httpClientAdapter = _ThrowingAdapter(
        _dioException(DioExceptionType.badResponse, statusCode: 500),
      );

      await expectLater(
        datasource.fetchNoteForConsultation('c1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  final Object error;

  _ThrowingAdapter(this.error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (error is DioException) throw error;
    throw error;
  }

  @override
  void close({bool force = false}) {}
}
