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
      final token = await keys.signToken();
      final parts = token.split('.');
      parts[1] = base64Url.encode(
        utf8.encode('{"sub":"intruder","scope":"clinical:write"}'),
      ).replaceAll('=', '');
      final (status, _, _) = await _request('GET', '/', token: parts.join('.'));
      expect(status, 401);
    });

    test('returns 401 with an expired token', () async {
      final token = await keys.signToken(expiresIn: const Duration(seconds: -60));
      final (status, _, _) = await _request('GET', '/', token: token);
      expect(status, 401);
    });

    test('returns 200 with service info for a valid token', () async {
      final (status, headers, body) = await _request(
        'GET',
        '/',
        token: await keys.signToken(),
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
      final readOnly = await keys.signToken(scopes: ['clinical:read']);
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
        token: await keys.signToken(),
        body: {'inputText': '   ', 'processingMode': 'VOCAB_ASSIST'},
      );
      expect(status, 400);
      expect(body, contains('error'));
    });

    test('rejects unknown processing mode (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
      );
      expect(status, 404);
    });

    test('returns the persisted bundle for a generated summary', () async {
      final (status, _, _) = await _request(
        'GET',
        '/api/v1/transcript-summary/itest-sum-1',
        token: await keys.signToken(),
      );
      expect(status, 200);
    });

    test('persisted data roundtrips through encryption', () async {
      // Generate first, then read back and compare the structured summary.
      await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
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
        token: await keys.signToken(),
      );
      expect(status, 400);
    });
  });

  group('POST /api/v1/auth/token', () {
    test('mints a token without auth (200)', () async {
      final (status, _, body) = await _request('POST', '/api/v1/auth/token');
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['token'], isA<String>());
      expect(json['tokenType'], 'Bearer');
      expect(json['scopes'], containsAll(['clinical:read', 'clinical:write']));
      expect(DateTime.tryParse(json['expiresAt'] as String), isNotNull);
    });

    test('minted token passes auth on a real endpoint', () async {
      final (_, _, body) = await _request('POST', '/api/v1/auth/token');
      final token = (jsonDecode(body) as Map<String, dynamic>)['token'] as String;
      final (status, _, responseBody) = await _request(
        'POST',
        '/api/v1/clinical-processing/process',
        token: token,
        body: {
          'inputText': 'Patient stable.',
          'processingMode': 'VOCAB_ASSIST',
        },
      );
      expect(status, 200);
      expect(responseBody, contains('processedText'));
    });

    test('rejects GET (405)', () async {
      final (status, _, _) = await _request('GET', '/api/v1/auth/token');
      expect(status, 405);
    });
  });

  group('POST /api/v1/transcript-summary/structured', () {
    test('generates a 7-field structured summary (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/structured',
        token: await keys.signToken(),
        body: {
          'transcriptText': '56 year old male with SOB and DOE for 2 weeks.',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['complaint'], isA<String>());
      expect(json['pastHistory'], isA<String>());
      expect(json['vitals'], isA<String>());
      expect(json['physicalExamination'], isA<String>());
      expect(json['investigationOrdered'], isA<String>());
      expect(json['diagnosis'], isA<String>());
      expect(json['advice'], isA<String>());
    });

    test('rejects empty transcriptText (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/structured',
        token: await keys.signToken(),
        body: {'transcriptText': '   '},
      );
      expect(status, 400);
    });

    test('rejects read-only scope (403)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/structured',
        token: await keys.signToken(scopes: ['clinical:read']),
        body: {'transcriptText': 'Patient stable.'},
      );
      expect(status, 403);
    });

    test('rejects missing body (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/structured',
        token: await keys.signToken(),
      );
      expect(status, 400);
    });
  });

  group('POST /api/v1/transcript-summary/context-enriched', () {
    test('generates a structured summary with past context (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/context-enriched',
        token: await keys.signToken(),
        body: {
          'transcriptText': 'Patient reports headaches.',
          'pastContext': 'Known migraine history.',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['complaint'], isNotEmpty);
    });

    test('auto-retrieves past context from the vector store when omitted '
        '(200)', () async {
      // Seed the vector store through the orchestrator path, then call the
      // route without pastContext — retrieval must succeed and produce a
      // summary (vector search degrades gracefully when the sqlite-vec
      // extension is unavailable).
      await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: await keys.signToken(),
        body: {
          'transcriptText':
              'Patient with chronic headaches for 3 months. MRI normal.',
          'consultationId': 'itest-vec-seed',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'consultationMode': 'IN_PERSON',
        },
      );
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/context-enriched',
        token: await keys.signToken(),
        body: {'transcriptText': 'Patient still reports headaches.'},
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['complaint'], isNotEmpty);
    });

    test('uses explicit pastContext when provided (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/context-enriched',
        token: await keys.signToken(),
        body: {
          'transcriptText': 'Reports shortness of breath.',
          'pastContext': 'Patient had a mild asthma episode last year.',
        },
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['complaint'], isNotEmpty);
    });
  });

  group('POST /api/v1/transcript-summary/executive', () {
    test('generates an executive summary (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/executive',
        token: await keys.signToken(),
        body: {'transcriptText': '56 year old male with SOB for 2 weeks.'},
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['summary'], isA<String>());
      expect(json['summary'], isNotEmpty);
    });
  });

  group('POST /api/v1/transcript-summary/doctor-note', () {
    test('generates a doctor note (200)', () async {
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/transcript-summary/doctor-note',
        token: await keys.signToken(),
        body: {'transcriptText': '56 year old male with SOB for 2 weeks.'},
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['note'], isA<String>());
      expect(json['note'], isNotEmpty);
    });
  });

  group('POST /api/v1/notes/sync + GET /api/v1/notes/consultation/{id}', () {
    test('roundtrips a synced note including rich text and fields', () async {
      final payload = {
        'noteId': 'itest-note-1',
        'consultationId': 'itest-note-consult-1',
        'patientId': 'p-1',
        'doctorId': 'dr-smith',
        'rawText': 'Patient stable. HbA1c 7.2.',
        'richTextDelta': '{"ops":[{"insert":"Patient stable"}]}',
        'status': 'finalized',
        'extractedFields': {
          'symptoms': ['SOB'],
          'duration': '2 weeks',
          'medications': ['metformin'],
          'allergies': [],
          'testsRecommended': ['HbA1c'],
          'followUpActions': ['review in 3 months'],
          'provisionalDiagnosis': 'DM2',
        },
        'patientRecap': 'Known DM2.',
        'createdAt': '2026-08-01T10:00:00.000Z',
        'updatedAt': '2026-08-01T10:00:00.000Z',
      };

      final (syncStatus, _, syncBody) = await _request(
        'POST',
        '/api/v1/notes/sync',
        token: await keys.signToken(),
        body: payload,
      );
      expect(syncStatus, 200);
      expect(syncBody, contains('synced'));

      final (status, _, body) = await _request(
        'GET',
        '/api/v1/notes/consultation/itest-note-consult-1',
        token: await keys.signToken(),
      );
      expect(status, 200);
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['noteId'], 'itest-note-1');
      expect(json['rawText'], 'Patient stable. HbA1c 7.2.');
      expect(json['richTextDelta'], contains('Patient stable'));
      expect(json['status'], 'finalized');
      expect(json['patientRecap'], 'Known DM2.');
      final fields = json['extractedFields'] as Map<String, dynamic>;
      expect(fields['symptoms'], contains('SOB'));
      expect(fields['provisionalDiagnosis'], 'DM2');
    });

    test('upserts by noteId (last-write-wins)', () async {
      await _request(
        'POST',
        '/api/v1/notes/sync',
        token: await keys.signToken(),
        body: {
          'noteId': 'itest-note-upd',
          'consultationId': 'itest-note-consult-upd',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'rawText': 'v1',
          'status': 'draft',
          'createdAt': '2026-08-01T10:00:00.000Z',
          'updatedAt': '2026-08-01T10:00:00.000Z',
        },
      );
      final (status, _, body) = await _request(
        'POST',
        '/api/v1/notes/sync',
        token: await keys.signToken(),
        body: {
          'noteId': 'itest-note-upd',
          'consultationId': 'itest-note-consult-upd',
          'patientId': 'p-1',
          'doctorId': 'dr-smith',
          'rawText': 'v2',
          'status': 'finalized',
          'createdAt': '2026-08-01T10:00:00.000Z',
          'updatedAt': '2026-08-02T10:00:00.000Z',
        },
      );
      expect(status, 200);

      final (getStatus, _, getBody) = await _request(
        'GET',
        '/api/v1/notes/consultation/itest-note-consult-upd',
        token: await keys.signToken(),
      );
      expect(getStatus, 200);
      final json = jsonDecode(getBody) as Map<String, dynamic>;
      expect(json['rawText'], 'v2');
    });

    test('returns 404 for an unknown consultation', () async {
      final (status, _, _) = await _request(
        'GET',
        '/api/v1/notes/consultation/itest-note-missing',
        token: await keys.signToken(),
      );
      expect(status, 404);
    });

    test('rejects a sync payload without noteId (400)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/notes/sync',
        token: await keys.signToken(),
        body: {
          'consultationId': 'itest-note-bad',
          'rawText': 'text',
        },
      );
      expect(status, 400);
    });

    test('rejects read-only scope on sync (403)', () async {
      final (status, _, _) = await _request(
        'POST',
        '/api/v1/notes/sync',
        token: await keys.signToken(scopes: ['clinical:read']),
        body: {
          'noteId': 'itest-note-scope',
          'consultationId': 'itest-note-consult-scope',
          'rawText': 'text',
          'createdAt': '2026-08-01T10:00:00.000Z',
          'updatedAt': '2026-08-01T10:00:00.000Z',
        },
      );
      expect(status, 403);
    });
  });

  group('GET /metrics', () {
    test('is exempt from auth and serves Prometheus text format', () async {
      final (status, headers, body) = await _request('GET', '/metrics');
      expect(status, 200);
      expect(headers['content-type'], contains('text/plain'));
      expect(body, contains('# TYPE http_requests_total counter'));
      expect(body, contains('# TYPE http_request_duration_seconds histogram'));
      expect(body, contains('# TYPE llm_inference_duration_seconds histogram'));
      expect(body, contains('# TYPE active_consultations gauge'));
    });

    test('records requests with method/path/status labels', () async {
      final (status, _, body) = await _request('GET', '/metrics');
      expect(status, 200);
      expect(body, contains('http_requests_total{method="GET",path="/metrics"'));
      expect(
        body,
        contains('http_request_duration_seconds_bucket{le="+Inf",method="GET",'),
      );
    });

    test('tracks active_consultations on generate and regenerate', () async {
      final (_, _, beforeBody) = await _request('GET', '/metrics');
      final before = _gaugeValue(beforeBody);

      // Generate a summary — the gauge increments.
      final (genStatus, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/generate',
        token: await keys.signToken(),
        body: {
          'consultationId': 'itest-metrics-consult',
          'patientId': 'p-metrics',
          'doctorId': 'dr-smith',
          'transcriptText': 'Patient reports chest pain for 1 day.',
        },
      );
      expect(genStatus, 200);

      final (_, _, afterGen) = await _request('GET', '/metrics');
      expect(
        _gaugeValue(afterGen),
        before + 1,
        reason: 'generating a summary increments the gauge',
      );

      // Regenerate — the gauge decrements back.
      final (regStatus, _, _) = await _request(
        'POST',
        '/api/v1/transcript-summary/itest-metrics-consult/regenerate',
        token: await keys.signToken(),
      );
      expect(regStatus, 200);

      final (_, _, afterRegen) = await _request('GET', '/metrics');
      expect(
        _gaugeValue(afterRegen),
        before,
        reason: 'regenerating a summary decrements the gauge',
      );
    });

    test('records llm_inference_duration_seconds with method labels', () async {
      final (_, _, body) = await _request('GET', '/metrics');
      expect(
        body,
        contains('llm_inference_duration_seconds_bucket{le="+Inf",method="'),
      );
      expect(body, contains('llm_inference_duration_seconds_count{method="'));
    });
  });
}

/// Parses the `active_consultations <n>` gauge line from a metrics scrape.
int _gaugeValue(String metricsBody) {
  final match = RegExp(r'^active_consultations (\d+)$', multiLine: true)
      .firstMatch(metricsBody);
  if (match == null) return 0;
  return int.parse(match.group(1)!);
}
