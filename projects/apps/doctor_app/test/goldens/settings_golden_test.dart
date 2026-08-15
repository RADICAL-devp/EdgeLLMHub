import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/core/services/sync_queue_service.dart';
import 'package:doctor_app/features/note_assist/domain/services/diagnostics_exporter.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_helpers.dart';

class _MockDeviceCapabilityService extends Mock
    implements DeviceCapabilityService {}

class _MockSyncQueueService extends Mock implements SyncQueueService {}

class _StubExporter extends DiagnosticsExporter {
  _StubExporter() : super(documentsDirectory: () async => throw UnimplementedError());

  @override
  Future<String> exportLog(String contents) async => 'stub';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GetIt.I.registerSingleton<DeviceCapabilityService>(
        _MockDeviceCapabilityService());
    GetIt.I.registerSingleton<SyncQueueService>(_MockSyncQueueService());
    GetIt.I.registerSingleton<DiagnosticsExporter>(_StubExporter());
    when(() => GetIt.I<DeviceCapabilityService>().getRecommendedExecutionMode())
        .thenAnswer((_) async => ExecutionMode.cloud);
    when(() => GetIt.I<SyncQueueService>().getPendingCount())
        .thenAnswer((_) async => 2);
    when(() => GetIt.I<SyncQueueService>().getDeadLetterEntries())
        .thenAnswer((_) async => []);
  });

  tearDown(() => GetIt.I.reset());

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('settings page${
        brightness == Brightness.dark ? ' dark' : ''}',
        (tester) async {
      await matchGolden(
        tester,
        const SettingsPage(),
        name: 'settings_loaded',
        brightness: brightness,
      );
    });
  }

  testWidgets('settings page at 2x text scale does not overflow',
      (tester) async {
    usePhoneViewport(tester, textScale: 2.0);
    await tester.pumpWidget(goldenApp(child: const SettingsPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings_a11y.png'),
    );
  });
}