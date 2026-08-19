import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:doctor_app/core/network/certificate_pinner.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 32 bytes that are NOT the presented digest — the shape of every real pin.
  final otherDigest = base64Encode(List.filled(32, 0xAB));

  group('CertificatePinner.fingerprintMatches', () {
    final digest =
        sha256.convert(utf8.encode('doctor-app-backend-cert')).bytes;
    final base64Pin = base64Encode(digest);
    final hexPin =
        digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final sha256Prefixed = 'sha256/$base64Pin';

    test('matches an identical sha256/-prefixed base64 pin', () {
      expect(
        CertificatePinner.fingerprintMatches(
          presentedSha256Base64: base64Pin,
          pin: sha256Prefixed,
        ),
        isTrue,
      );
    });

    test('matches a raw base64 pin', () {
      expect(
        CertificatePinner.fingerprintMatches(
          presentedSha256Base64: base64Pin,
          pin: base64Pin,
        ),
        isTrue,
      );
    });

    test('matches a hex pin (any case)', () {
      expect(
        CertificatePinner.fingerprintMatches(
          presentedSha256Base64: base64Pin,
          pin: hexPin.toUpperCase(),
        ),
        isTrue,
      );
    });

    test('rejects a mismatched pin', () {
      expect(
        CertificatePinner.fingerprintMatches(
          presentedSha256Base64: base64Pin,
          pin: otherDigest,
        ),
        isFalse,
      );
    });

    test('rejects empty or placeholder pins', () {
      expect(
        CertificatePinner.fingerprintMatches(
          presentedSha256Base64: base64Pin,
          pin: '',
        ),
        isFalse,
      );
    });
  });

  group('CertificatePinner.isConfigured', () {
    test('false for the unconfigured placeholder and empty pin', () {
      expect(CertificatePinner(pinnedSha256: '').isConfigured, isFalse);
    });

    test('true for a real pin', () {
      expect(CertificatePinner(pinnedSha256: 'sha256/$otherDigest').isConfigured,
          isTrue);
    });
  });

  group('CertificatePinner.applyTo', () {
    test('installs the pinning adapter when configured', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());

      CertificatePinner(pinnedSha256: 'sha256/$otherDigest').applyTo(dio);

      expect(dio.httpClientAdapter, isA<PinningHttpClientAdapter>());
    });

    test('leaves the default adapter untouched when no pin is configured', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final adapter = dio.httpClientAdapter;

      CertificatePinner(pinnedSha256: '').applyTo(dio);

      expect(dio.httpClientAdapter, same(adapter));
    });

    test('leaves non-IO (mock) adapters untouched when pinning is enabled',
        () {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final mock = _NullAdapter();
      dio.httpClientAdapter = mock;

      CertificatePinner(pinnedSha256: 'sha256/$otherDigest').applyTo(dio);

      expect(dio.httpClientAdapter, same(mock));
    });

    test('does not pin when enablePinning is false', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final adapter = dio.httpClientAdapter;

      CertificatePinner(
        pinnedSha256: 'sha256/$otherDigest',
        enablePinning: false,
      ).applyTo(dio);

      expect(dio.httpClientAdapter, same(adapter));
    });
  });

  group('end-to-end TLS pinning', () {
    // Exercises the full path: PinningHttpClientAdapter → createHttpClient →
    // HttpClient.badCertificateCallback → verifyCertificate, against a real
    // self-signed HTTPS server.
    late Directory dir;
    late HttpServer server;
    late String pin;
    late int port;

    setUpAll(() async {
      if (await _hasOpenssl() != true) {
        markTestSkipped('openssl not available to generate a test cert');
        return;
      }
      dir = await Directory.systemTemp.createTemp('pin-test');
      final key = '${dir.path}/key.pem';
      final cert = '${dir.path}/cert.pem';
      final der = '${dir.path}/cert.der';
      await _run('openssl', [
        'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', key, '-out', cert,
        '-days', '1', '-nodes', '-subj', '/CN=localhost',
      ]);
      await _run('openssl', ['x509', '-in', cert, '-outform', 'der', '-out', der]);
      pin = base64Encode(sha256.convert(await File(der).readAsBytes()).bytes);

      final context = SecurityContext()
        ..useCertificateChain(cert)
        ..usePrivateKey(key);
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      server.listen((request) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write('{"ok": true}')
          ..close();
      });
      port = server.port;
    });

    tearDownAll(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });

    test('accepts the connection when the presented cert matches the pin',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://127.0.0.1:$port'));
      dio.httpClientAdapter = PinningHttpClientAdapter(
        pinner: CertificatePinner(pinnedSha256: 'sha256/$pin'),
      );

      final response = await dio.get<Map<String, dynamic>>('/');

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
    });

    test('rejects the connection when the pin does not match', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://127.0.0.1:$port'));
      dio.httpClientAdapter = PinningHttpClientAdapter(
        pinner: CertificatePinner(pinnedSha256: 'sha256/$otherDigest'),
      );

      await expectLater(
        dio.get('/'),
        throwsA(isA<DioException>()),
      );
    });
  });
}

Future<bool> _hasOpenssl() async {
  try {
    final result = await Process.run('which', ['openssl']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _run(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  if (result.exitCode != 0) {
    throw StateError(
      '$executable ${args.join(' ')} failed: ${result.stderr}',
    );
  }
}

class _NullAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw UnimplementedError();
  }

  @override
  void close({bool force = false}) {}
}
