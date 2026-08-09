import 'dart:async';
import 'dart:io';

import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:doctor_app/features/note_assist/presentation/pages/model_manager_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'golden_helpers.dart';

class _MockCapabilityService extends Mock implements DeviceCapabilityService {}

/// Stand-in for path_provider so simulated downloads can write a file.
class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '/tmp/golden_app_documents';
}

void main() {
  late _MockCapabilityService capability;
  late Directory docsDir;

  setUp(() {
    docsDir = Directory('/tmp/golden_app_documents')
      ..createSync(recursive: true);
    capability = _MockCapabilityService();
    GetIt.I.registerSingleton<DeviceCapabilityService>(capability);
    GetIt.I.registerSingleton<Dio>(Dio());
    PathProviderPlatform.instance = _FakePathProvider();
  });

  tearDown(() async {
    GetIt.I.reset();
    if (docsDir.existsSync()) {
      docsDir.deleteSync(recursive: true);
    }
  });

  GoRouter router() => GoRouter(
        initialLocation: '/model_manager',
        routes: [
          GoRoute(
            path: '/model_manager',
            builder: (context, state) => const ModelManagerPage(),
          ),
          GoRoute(
            path: '/consultations',
            builder: (context, state) => const Scaffold(
              body: Text('consultations'),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Text('settings')),
          ),
        ],
      );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final suffix = brightness == Brightness.dark ? ' dark' : '';
    final nameSuffix = brightness == Brightness.dark ? '_dark' : '';

    testWidgets('ready in cloud mode$suffix', (tester) async {
      when(() => capability.isSimulator).thenAnswer((_) async => true);
      when(() => capability.canRunLocalLlm()).thenAnswer((_) async => false);
      when(() => capability.getRecommendedExecutionMode())
          .thenAnswer((_) async => ExecutionMode.cloud);

      await matchGolden(
        tester,
        const ModelManagerPage(),
        name: 'model_manager_ready',
        brightness: brightness,
        router: router(),
      );
    });

    testWidgets('download in progress$suffix', (tester) async {
      // Never complete the simulator probe so the page stays on the
      // "not installed" view, which owns the Download Model button.
      when(() => capability.isSimulator)
          .thenAnswer((_) => Completer<bool>().future);
      when(() => capability.canRunLocalLlm()).thenAnswer((_) async => false);
      when(() => capability.getRecommendedExecutionMode())
          .thenAnswer((_) async => ExecutionMode.cloud);

      await tester.pumpWidget(goldenApp(
        child: const ModelManagerPage(),
        router: router(),
        brightness: brightness,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download Model'));
      // Simulated download ticks every 400ms; capture at ~40%.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/model_manager_downloading$nameSuffix.png'),
      );
      // Let the remaining simulated steps finish and clear the timers.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
    });

    testWidgets('error state$suffix', (tester) async {
      when(() => capability.isSimulator)
          .thenThrow(Exception('probe failed'));

      await matchGolden(
        tester,
        const ModelManagerPage(),
        name: 'model_manager_error',
        brightness: brightness,
        router: router(),
      );
    });
  }
}
