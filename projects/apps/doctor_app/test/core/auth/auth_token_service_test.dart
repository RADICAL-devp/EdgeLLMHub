import 'dart:convert';
import 'dart:typed_data';

import 'package:doctor_app/core/auth/auth_token_service.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late AuthTokenService service;
  late _FakeAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    service = AuthTokenService(dio);
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
  });

  Map<String, dynamic> _tokenBody({
    String token = 'abc.token.123',
    String? expiresAt = '2026-08-11T00:00:00.000Z',
  }) =>
      {
        'token': token,
        'tokenType': 'Bearer',
        'expiresAt': expiresAt,
        'scopes': ['clinical:read', 'clinical:write'],
      };

  test('fetches a token from the mint endpoint', () async {
    adapter.responses.add(_tokenBody());

    final token = await service.getToken();

    expect(token, 'abc.token.123');
    expect(adapter.paths, ['/api/v1/auth/token']);
    expect(adapter.methods, ['POST']);
  });

  test('caches the token and does not re-request within validity', () async {
    adapter.responses.add(_tokenBody(expiresAt: '2030-01-01T00:00:00.000Z'));

    await service.getToken();
    await service.getToken();

    expect(adapter.paths.length, 1);
  });

  test('re-requests when the cached token is near expiry', () async {
    final nearExpiry = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String();
    adapter.responses.add(_tokenBody(expiresAt: nearExpiry));
    adapter.responses.add(_tokenBody(token: 'second.token'));

    await service.getToken();
    await service.getToken();

    expect(adapter.paths.length, 2);
  });

  test('invalidate forces a fresh request', () async {
    adapter.responses.add(_tokenBody(expiresAt: '2030-01-01T00:00:00.000Z'));
    adapter.responses.add(_tokenBody(token: 'fresh.token'));

    await service.getToken();
    service.invalidate();
    final token = await service.getToken();

    expect(token, 'fresh.token');
    expect(adapter.paths.length, 2);
  });

  test('throws NetworkException when the mint endpoint fails', () async {
    adapter.errors.add(
      DioException(
        requestOptions: RequestOptions(path: AuthTokenService.tokenPath),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: AuthTokenService.tokenPath),
          statusCode: 500,
        ),
      ),
    );

    await expectLater(
      service.getToken(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('throws NetworkException for an invalid token payload', () async {
    adapter.responses.add(const {'token': 42});

    await expectLater(
      service.getToken(),
      throwsA(isA<NetworkException>()),
    );
  });
}

class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<String> methods = [];
  final List<Object> errors = [];
  final List<Map<String, dynamic>> responses = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    methods.add(options.method);

    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
