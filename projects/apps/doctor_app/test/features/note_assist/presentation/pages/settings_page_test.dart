import 'dart:async';
import 'dart:io';

import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/data/local/sync_queue_entry.dart';
import 'package:doctor_app/features/note_assist/domain/models/doctor_note.dart';
import 'package:doctor_app/features/note_assist/domain/services/diagnostics_exporter.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockDeviceCapabilityService extends Mock
    implements DeviceCapabilityService {}

class _MockSyncQueueService extends Mock implements SyncQueueService {}

class _FakePathProvider extends PathProviderPlatform {
  final Directory dir;

  _FakePathProvider(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

class _FakeExporter extends DiagnosticsExporter {
  String? lastContents;

  _FakeExporter() : super(documentsDirectory: () async => Directory.systemTemp);

  @override
  Future<String> exportLog(String contents) async {
    lastContents = contents;
    return 'fake/path/diagnostics-1.log';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDeviceCapabilityService deviceService;
  late _MockSyncQueueService syncQueue;
  late _FakeExporter exporter;
  late Directory docsDir;

  // NOTE: registrations must happen inside each test body — the GetIt
  // container state does not survive across testWidgets bodies.
  Future<void> registerMocks() async {
    await GetIt.instance.reset();
    deviceService = _MockDeviceCapabilityService();
    syncQueue = _MockSyncQueueService();
    exporter = _FakeExporter();
    GetIt.instance
      ..registerSingleton<DeviceCapabilityService>(deviceService)
      ..registerSingleton<SyncQueueService>(syncQueue)
      ..registerSingleton<DiagnosticsExporter>(exporter);
    when(() => deviceService.getRecommendedExecutionMode())
        .thenAnswer((_) async => ExecutionMode.cloud);
    when(() => deviceService.isSimulator).thenAnswer((_) async => false);
    when(() => syncQueue.getPendingCount()).thenAnswer((_) async => 2);
    when(() => syncQueue.getDeadLetterEntries()).thenAnswer((_) async => []);
    when(() => syncQueue.getPendingEntries()).thenAnswer((_) async => [
      SyncQueueEntry(
        id: 'e1',
        noteId: 'n1',
        consultationId: 'c1',
        operation: 'create',
        note: DoctorNote(
          noteId: 'n1',
          consultationId: 'c1',
          patientId: 'p1',
          doctorId: 'd1',
          rawText: 'content',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        retryCount: 2,
        maxRetries: 5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        lastError: 'boom',
      ),
    ]);
    when(() => syncQueue.getDeadLetterEntries()).thenAnswer((_) async => [
      SyncQueueEntry(
        id: 'e2',
        noteId: 'n2',
        consultationId: 'c2',
        operation: 'update',
        note: DoctorNote(
          noteId: 'n2',
          consultationId: 'c2',
          patientId: 'p2',
          doctorId: 'd2',
          rawText: 'content',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        lastError: 'permanent',
        isDeadLetter: true,
      ),
    ]);
    when(() => syncQueue.syncNow()).thenAnswer((_) async {});

    docsDir = Directory(
      '${Directory.systemTemp.path}/settings_test_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync();
    PathProviderPlatform.instance = _FakePathProvider(docsDir);
  }

  tearDown(() async {
    if (docsDir.existsSync()) {
      await docsDir.delete(recursive: true);
    }
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('renders all settings sections after loading', (tester) async {
    await registerMocks();
    await pumpSettings(tester);

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('On-device processing only'), findsOneWidget);
    expect(find.text('Recommended execution mode'), findsOneWidget);
    expect(find.text('CLOUD'), findsOneWidget);
    expect(find.text('Pending syncs'), findsOneWidget);
    expect(find.text('2 items waiting'), findsOneWidget);
    expect(find.text('Dead letter queue'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
  });

  testWidgets('no cloud or consent toggles are exposed', (tester) async {
    await registerMocks();
    await pumpSettings(tester);

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Allow cloud processing'), findsNothing);
    expect(find.text('PHI consent granted'), findsNothing);
  });

  testWidgets('spinner is shown while settings load', (tester) async {
    await registerMocks();
    final gate = Completer<void>();
    when(() => deviceService.getRecommendedExecutionMode())
        .thenAnswer((_) => gate.future.then((_) => ExecutionMode.cloud));
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('layout survives 2.0x text scale (dynamic type)', (tester) async {
    await registerMocks();
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On-device processing only'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Export diagnostics log'), 100);
    await tester.pump();

    expect(find.text('Export diagnostics log'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync now flushes the queue and reports completion',
      (tester) async {
    await registerMocks();
    final gate = Completer<void>();
    when(() => syncQueue.syncNow()).thenAnswer((_) => gate.future);
    await pumpSettings(tester);

    await tester.tap(find.text('Sync now'));
    await tester.pump();

    expect(find.text('Syncing…'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sync complete.'), findsOneWidget);
    verify(() => syncQueue.syncNow()).called(1);
  });

  testWidgets('export diagnostics shares the log', (tester) async {
    await registerMocks();
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });
    await pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Export diagnostics log'), 100);
    await tester.tap(find.text('Export diagnostics log'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Diagnostics exported to'), findsOneWidget);
    expect(exporter.lastContents, isNotNull);
    expect(exporter.lastContents, contains('Doctor App Diagnostics Log'));
    expect(exporter.lastContents, contains('Cloud LLM enabled (config): false'));
    expect(exporter.lastContents, contains('Pending: n1 op=create retry=2/5 error=boom'));
    expect(exporter.lastContents, contains('DEAD: c2 op=update error=permanent'));
  });

  testWidgets('export falls back gracefully when share is unavailable',
      (tester) async {
    await registerMocks();
    await pumpSettings(tester);

    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      throw MissingPluginException('share sheet not available');
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });
    await pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Export diagnostics log'), 100);
    await tester.tap(find.text('Export diagnostics log'));
    await tester.pumpAndSettle();

    expect(find.textContaining('share unavailable'), findsOneWidget);
    expect(exporter.lastContents, contains('Doctor App Diagnostics Log'));
  });
}
