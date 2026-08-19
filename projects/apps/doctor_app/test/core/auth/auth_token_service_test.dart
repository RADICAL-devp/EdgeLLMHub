import 'dart:convert';
import 'dart:typed_data';

import 'package:doctor_app/core/auth/auth_token_service.dart';
import 'package:doctor_app/core/auth/token_storage.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late AuthTokenService service;
  late InMemoryTokenStorage storage;
  late _FakeAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    storage = InMemoryTokenStorage();
    service = AuthTokenService(dio, storage: storage);
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
  });

  Map<String, dynamic> tokenBody({
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
    adapter.responses.add(tokenBody());

    final token = await service.getToken();

    expect(token, 'abc.token.123');
    expect(adapter.paths, ['/api/v1/auth/token']);
    expect(adapter.methods, ['POST']);
  });

  test('caches the token and does not re-request within validity', () async {
    adapter.responses.add(tokenBody(expiresAt: '2030-01-01T00:00:00.000Z'));

    await service.getToken();
    await service.getToken();

    expect(adapter.paths.length, 1);
  });

  test('re-requests when the cached token is near expiry', () async {
    final nearExpiry = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String();
    adapter.responses.add(tokenBody(expiresAt: nearExpiry));
    adapter.responses.add(tokenBody(token: 'second.token'));

    await service.getToken();
    await service.getToken();

    expect(adapter.paths.length, 2);
  });

  test('invalidate forces a fresh request', () async {
    adapter.responses.add(tokenBody(expiresAt: '2030-01-01T00:00:00.000Z'));
    adapter.responses.add(tokenBody(token: 'fresh.token'));

    await service.getToken();
    await service.invalidate();
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

  group('token storage', () {
    test('persists the minted token to the injected storage', () async {
      adapter.responses.add(tokenBody(expiresAt: '2030-01-01T00:00:00.000Z'));

      await service.getToken();

      final stored = await storage.read();
      expect(stored, isNotNull);
      expect(stored!.token, 'abc.token.123');
      expect(stored.expiresAt, DateTime.parse('2030-01-01T00:00:00.000Z'));
    });

    test('hydrates a valid token from storage without re-minting', () async {
      await storage.write(StoredAuthToken(
        token: 'persisted.token',
        expiresAt: _future(),
      ));

      final token = await service.getToken();

      expect(token, 'persisted.token');
      expect(adapter.paths, isEmpty, reason: 'no mint request expected');
    });

    test('ignores an expired persisted token and mints a new one', () async {
      await storage.write(StoredAuthToken(
        token: 'stale.token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      ));
      adapter.responses.add(tokenBody(token: 'fresh.token'));

      final token = await service.getToken();

      expect(token, 'fresh.token');
      expect(adapter.paths, ['/api/v1/auth/token']);
    });

    test('invalidate clears the persisted token', () async {
      adapter.responses.add(tokenBody());
      await service.getToken();
      expect(await storage.read(), isNotNull);

      await service.invalidate();

      expect(await storage.read(), isNull);
      expect(service.hasToken, isFalse);
    });

    test('still works when storage is unavailable (write failure)',
        () async {
      final failing = _FailingStorage();
      final svc = AuthTokenService(dio, storage: failing);
      adapter.responses.add(tokenBody());

      final token = await svc.getToken();

      expect(token, 'abc.token.123');
    });
  });
}

DateTime _future() =>
    DateTime.now().toUtc().add(const Duration(days: 30));

/// Storage whose writes throw, simulating an unavailable Keychain.
class _FailingStorage extends InMemoryTokenStorage {
  @override
  Future<void> write(StoredAuthToken token) async {
    throw Exception('keychain unavailable');
  }
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
