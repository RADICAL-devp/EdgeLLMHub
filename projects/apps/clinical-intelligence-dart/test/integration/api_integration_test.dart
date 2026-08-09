import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';

import '../helpers/test_keys.dart';

/// End-to-end HTTP integration tests against the real dart_frog server.
///
/// Requirements:
///   - `dart_frog_cli` must be activated globally (`dart pub global activate dart_frog_cli`)
///
/// The suite builds the production server, boots it on a random port with a
/// freshly generated RSA keypair + AES master key, and exercises the real
/// middleware chain: JWT auth, scope enforcement, audit logging, CORS,
/// encryption-at-rest repositories and the stub LLM adapter.

void main() {
  late TestKeys keys;
  late Process server;
  late HttpClient client;
  late int port;
  final serverLog = StringBuffer();

  Future<Process> _spawnServer() async {
    final build = await Process.run(
      'dart',
      ['pub', 'global', 'run', 'dart_frog_cli:dart_frog', 'build'],
      workingDirectory: Directory.current.path,
    );
    if (build.exitCode != 0) {
      fail(
        'dart_frog build failed. Is dart_frog_cli activated globally?\n'
        '${build.stdout}\n${build.stderr}',
      );
    }

    port = 20000 + Random().nextInt(20000);
    return Process.start(
      'dart',
      ['build/bin/server.dart'],
      workingDirectory: Directory.current.path,
      environment: {
        'PORT': '$port',
        'JWT_PRIVATE_KEY': keys.privateKeyPem,
        'JWT_PUBLIC_KEY': keys.publicKeyPem,
        'AES_MASTER_KEY': keys.masterKeyB64,
      },
    );
  }

  Future<void> _waitForServer() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final socket = await Socket.connect('127.0.0.1', port);
        socket.destroy();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    fail('Server did not start within 30s.\n$serverLog');
  }

  Future<(int, Map<String, String>, String)> _request(
    String method,
    String path, {
    String? token,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    headers?.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final headerMap = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) headerMap[name] = values.first;
    });
    return (response.statusCode, headerMap, responseBody);
  }

  setUpAll(() async {
    keys = TestKeys.generate();
    server = await _spawnServer();
    server.stdout.transform(utf8.decoder).listen(serverLog.write);
    server.stderr.transform(utf8.decoder).listen(serverLog.write);
    client = HttpClient();
    await _waitForServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    server.kill();
    await server.exitCode.timeout(const Duration(seconds: 5));
  });

  group('GET / (health)', () {
    test('returns 401 without a token', () async {
      final (status, _, body) = await _request('GET', '/');
      expect(status, 401);
      expect(body, contains('Authorization'));
    });

    test('returns 401 with a tampered token', () async {
      final token = keys.signToken();
      final parts = token.split('.');
      parts[1] = base64Url.encode(
        utf8.encode('{"sub":"intruder","scope":"clinical:write"}'),
      ).replaceAll('=', '');
      final (status, _, _) = await _request('GET', '/', token: parts.join('.'));
      expect(status, 401);
    });

    test('returns 401 with an expired token', () async {
      final token = keys.signToken(expiresIn: const Duration(seconds: -60));
      final (status, _, _) = await _request('GET', '/', token: token);
      expect(status, 401);
    });

    test('returns 200 with service info for a valid token', () async {
      final (status, headers, body) = await _request(
        'GET',
        '/',
        token: keys.signToken(),
        headers: {'x-correlation-id': 'corr-health-1'},
      );
      expect(status, 200);
      expect(body, contains('Clinical Intelligence'));
      expect(body, contains('status'));
      // Audit middleware echoes the correlation id.
      expect(headers['x-correlation-id'], 'corr-health-1');
      // CORS middleware applies to every response.
      expect(headers['access-control-allow-origin'], '*');
    });
  });

  group('POST /api/v1/clinical-processing/process', () {
    test('rejects a token without clinical:write scope (403)', () async {
      final readOnly = keys.signToken(scopes: ['clinical:read']);
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: readOnly,
        body: {
          'inputText': 'Patient is stable.',
          'processingMode': 'VOCAB_ASSIST',
        },
      );
      expect(status, 403);
      expect(body, contains('scope'));
    });

    test('rejects empty input (400)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: keys.signToken(),
        body: {'inputText': '   ', 'processingMode': 'VOCAB_ASSIST'},
      );
      expect(status, 400);
      expect(body, contains('error'));
    });

    test('rejects unknown processing mode (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: keys.signToken(),
        body: {
          'inputText': 'Patient is stable.',
          'processingMode': 'DO_MAGIC',
        },
      );
      expect(status, 400);
    });

    test('processes VOCAB_ASSIST end-to-end (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: keys.signToken(),
        body: {
          'inputText': 'Patient reports SOB and DOE . BP 130 / 85',
          'processingMode': 'VOCAB_ASSIST',
          'consultationId': 'itest-cp-1',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'source': 'integration-test',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['processedText'], isA<String>());
      expect(json['processedText'], isNotEmpty);
      expect(json['processingMode'], 'VOCAB_ASSIST');
      expect(json['metadata'], contains('consultationId'));
    });

    test('processes CLEAN_TRANSCRIPT mode (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: keys.signToken(),
        body: {
          'inputText': '  Doctor: Good   morning.   Patient:   Hi.  ',
          'processingMode': 'CLEAN_TRANSCRIPT',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['processingMode'], 'CLEAN_TRANSCRIPT');
      expect(json['processedText'], isNotEmpty);
    });
  });

  group('POST /api/v1/transcript-summary/generate', () {
    test('rejects empty transcript (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: keys.signToken(),
        body: {
          'consultationId': 'itest-sum-0',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'transcriptText': '',
        },
      );
      expect(status, 400);
    });

    test('generates a full summary bundle (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: keys.signToken(),
        body: {
          'consultationId': 'itest-sum-1',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'transcriptText':
              '56 year old male with SOB and DOE for 2 weeks. Chest pain on exertion.',
          'consultationMode': 'ONLINE',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['consultationId'], 'itest-sum-1');
      expect(json['transcriptId'], isNotEmpty);
      expect(json['structuredMedicalSummary'], isA<Map<String, dynamic>>());
      expect(json['doctorNote'], isA<Map<String, dynamic>>());
      expect(json['consultationMode'], 'ONLINE');
      expect(
        DateTime.tryParse(json['generatedAt'] as String),
        isNotNull,
      );
    });
  });

  group('GET /api/v1/transcript-summary/{consultationId}', () {
    test('returns 404 for an unknown consultation', () async {
      final (status, _, _) = await _request(
        'GET',
        '/api/v1/transcript-summary/itest-missing',
        token: keys.signToken(),
      );
      expect(status, 404);
    });

    test('returns the persisted bundle for a generated summary', () async {
      final (status, _, _) = await _request(
        'GET',
        '/api/v1/transcript-summary/itest-sum-1',
        token: keys.signToken(),
      );
      expect(status, 200);
    });

    test('persisted data roundtrips through encryption', () async {
      // Generate first, then read back and compare the structured summary.
      await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: keys.signToken(),
        body: {
          'consultationId': 'itest-roundtrip',
          'patientId': 'p-2',
          'doctorId': 'dr-smith',
          'transcriptText': 'Patient with DM2 and HTN. HbA1c 7.2.',
        },
      );
      final (status, _, body) = await _request(
        'GET',
        '/api/v1/transcript-summary/itest-roundtrip',
        token: keys.signToken(),
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['consultationId'], 'itest-roundtrip');
      final structured = json['structuredMedicalSummary'] as Map<String, dynamic>;
      expect(structured['complaint'], isNotEmpty);
      final doctorNote = json['doctorNote'] as Map<String, dynamic>;
      expect(doctorNote['rawText'], contains('HbA1c'));
    });
  });

  group('POST /api/v1/transcript-summary/{consultationId}/regenerate', () {
    test('regenerates a summary for an existing consultation (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/itest-roundtrip/regenerate',
        token: keys.signToken(),
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['consultationId'], 'itest-roundtrip');
      expect(json['transcriptId'], isNotEmpty);
    });

    test('returns 400 for an unknown consultation', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/itest-no-such/regenerate',
        token: keys.signToken(),
      );
      expect(status, 400);
    });
  });
}
