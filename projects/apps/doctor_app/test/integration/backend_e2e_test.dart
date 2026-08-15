import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:doctor_app/core/auth/auth_token_service.dart';
import 'package:doctor_app/core/llm/cloud_llm_adapter.dart';
import 'package:doctor_app/core/models/processing_mode.dart';
import 'package:doctor_app/core/network/auth_interceptor.dart';
import 'package:doctor_app/features/note_assist/data/remote/note_remote_datasource.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end test booting the REAL clinical-intelligence backend and
/// driving it through the app's own production classes
/// (AuthTokenService + AuthInterceptor + CloudLlmAdapter + NoteRemoteDatasource).
///
/// Requirements:
///   - `dart_frog_cli` activated globally (`dart pub global activate dart_frog_cli`)
///
/// The server is built once if needed and started on a random port with the
/// backend's embedded development keys (dev token mint endpoint enabled).
void main() {
  late Process server;
  late Dio dio;
  late int port;
  final serverLog = StringBuffer();

  final backendDir = Directory(
    '${Directory.current.parent.path}/clinical-intelligence-dart',
  );

  Future<void> waitForServer() async {
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

  setUpAll(() async {
    final buildDir = Directory('${backendDir.path}/build/bin');
    final serverBin = File('${buildDir.path}/server.dart');
    final newestSource = backendDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.statSync().modified)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (!serverBin.existsSync() ||
        serverBin.statSync().modified.isBefore(newestSource)) {
      final build = await Process.run(
        'dart',
        ['pub', 'global', 'run', 'dart_frog_cli:dart_frog', 'build'],
        workingDirectory: backendDir.path,
      );
      if (build.exitCode != 0) {
        fail(
          'dart_frog build failed. Is dart_frog_cli activated globally?\n'
          '${build.stdout}\n${build.stderr}',
        );
      }
    }

    port = 20000 + Random().nextInt(20000);
    server = await Process.start(
      'dart',
      ['build/bin/server.dart'],
      workingDirectory: backendDir.path,
      environment: {'PORT': '$port'},
    );
    server.stdout.transform(utf8.decoder).listen(serverLog.write);
    server.stderr.transform(utf8.decoder).listen(serverLog.write);

    await waitForServer();

    dio = Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:$port',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(AuthInterceptor(dio, AuthTokenService(dio)));
  });

  tearDownAll(() async {
    dio.close(force: true);
    server.kill();
    await server.exitCode.timeout(const Duration(seconds: 5));
    final sqlite = File('${backendDir.path}/clinical_intelligence.sqlite');
    if (sqlite.existsSync()) sqlite.deleteSync();
  });

  test('auth token is minted automatically and processText succeeds', () async {
    final llm = CloudLlmAdapter(dio);

    final result = await llm.processText(
      'Patient reports SOB and DOE . BP 130 / 85',
      ProcessingMode.vocabAssist,
    );

    expect(result, isNotEmpty);
  });

  test('structured summary roundtrips through the real backend', () async {
    final llm = CloudLlmAdapter(dio);

    final summary = await llm.generateStructuredSummary(
      '56 year old male with SOB and DOE for 2 weeks.',
    );

    expect(summary.complaint, isNotEmpty);
    expect(summary.diagnosis, isNotEmpty);
    expect(summary.advice, isNotEmpty);
  });

  test('executive summary and doctor note return text', () async {
    final llm = CloudLlmAdapter(dio);
    const transcript = '56 year old male with SOB for 2 weeks.';

    final executive = await llm.generateExecutiveSummary(transcript);
    final note = await llm.generateDoctorNote(transcript);

    expect(executive, isNotEmpty);
    expect(note, isNotEmpty);
  });

  test('note sync roundtrips through the real backend', () async {
    final datasource = NoteRemoteDatasource(dio);
    final note = DoctorNote(
      noteId: 'e2e-note-1',
      consultationId: 'e2e-consult-1',
      patientId: 'p-1',
      doctorId: 'dr-smith',
      rawText: 'Patient stable. HbA1c 7.2.',
      richTextDelta: '{"ops":[{"insert":"Patient stable"}]}',
      status: NoteStatus.finalized,
      extractedFields: const ExtractedFields(
        symptoms: ['SOB'],
        medications: ['metformin'],
        provisionalDiagnosis: 'DM2',
      ),
      patientRecap: 'Known DM2.',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1, 10),
    );

    await datasource.syncNote(note);
    final fetched = await datasource.fetchNoteForConsultation('e2e-consult-1');

    expect(fetched, isNotNull);
    expect(fetched!.noteId, 'e2e-note-1');
    expect(fetched.rawText, 'Patient stable. HbA1c 7.2.');
    expect(fetched.richTextDelta, contains('Patient stable'));
    expect(fetched.status, NoteStatus.finalized);
    expect(fetched.extractedFields?.provisionalDiagnosis, 'DM2');
    expect(fetched.patientRecap, 'Known DM2.');
  });
}
