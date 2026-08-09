import 'dart:convert';
import 'dart:typed_data';

import 'package:doctor_app/core/auth/auth_token_service.dart';
import 'package:doctor_app/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late AuthTokenService tokenService;
  late _FakeAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    tokenService = AuthTokenService(dio);
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio, tokenService));
  });

  Map<String, dynamic> tokenBody({String token = 'minted.token'}) => {
        'token': token,
        'tokenType': 'Bearer',
        'expiresAt': '2030-01-01T00:00:00.000Z',
      };

  test('attaches the Bearer token to requests', () async {
    adapter.responses.add(tokenBody());
    adapter.responses.add(const {'ok': true});

    await dio.get('/api/v1/clinical-processing/process');

    expect(adapter.paths, contains('/api/v1/clinical-processing/process'));
    expect(adapter.authHeaders.whereType<String>(), ['Bearer minted.token']);
  });

  test('skips the token endpoint itself (no recursion)', () async {
    adapter.responses.add(tokenBody());

    await dio.post<Map<String, dynamic>>(AuthTokenService.tokenPath);

    expect(adapter.paths, [AuthTokenService.tokenPath]);
    expect(adapter.authHeaders, [isNull]);
  });

  test('refreshes once and retries on 401', () async {
    adapter.responses.add(tokenBody(token: 'expired.token'));
    adapter.responses.add(_StatusResponse(401, {'error': 'Token expired'}));
    adapter.responses.add(tokenBody(token: 'fresh.token'));
    adapter.responses.add(const {'ok': true});

    final response = await dio.get<Map<String, dynamic>>('/api/v1/notes/sync');

    expect(response.data, {'ok': true});
    expect(
      adapter.authHeaders.whereType<String>(),
      ['Bearer expired.token', 'Bearer fresh.token'],
    );
    expect(adapter.paths.length, 4); // mint + GET + re-mint + retried GET
  });

  test('passes through after a second 401 (no infinite retry)', () async {
    adapter.responses.add(tokenBody());
    adapter.responses.add(_StatusResponse(401, const {'error': 'nope'}));
    adapter.responses.add(_StatusResponse(401, const {'error': 'nope'}));

    await expectLater(
      dio.get('/api/v1/notes/sync'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(adapter.paths.length, 3); // mint + GET + failed re-mint
  });

  test('rejects the request when no token can be minted', () async {
    adapter.errors.add(
      DioException(
        requestOptions: RequestOptions(path: AuthTokenService.tokenPath),
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      dio.get('/api/v1/clinical-processing/process'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.paths, [AuthTokenService.tokenPath]);
  });
}

class _StatusResponse {
  const _StatusResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<Object> errors = [];
  final List<Object> responses = [];
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    authHeaders.add(options.headers['Authorization'] as String?);

    if (errors.isNotEmpty) {
      throw errors.removeAt(0);
    }
    final next = responses.removeAt(0);
    if (next is Map<String, dynamic>) {
      return ResponseBody.fromString(
        jsonEncode(next),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final failure = next as _StatusResponse;
    return ResponseBody.fromString(
      jsonEncode(failure.body),
      failure.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
