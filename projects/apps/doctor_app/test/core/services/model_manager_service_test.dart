import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/models/model_install_progress.dart';
import 'package:doctor_app/core/services/model_manager_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('ModelManagerService', () {
    late FakeSettings settings;
    late FakeEdgeModelInstaller installer;

    setUp(() {
      settings = FakeSettings();
      installer = FakeEdgeModelInstaller();
    });

    test('reports the current model status and storage use', () async {
      installer
        ..llmReady = true
        ..sttReady = true
        ..storage = 500 * 1024 * 1024;
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );

      final status = await service.getStatus();
      expect(status.allReady, isTrue);
      expect(status.storageMb, 500);
    });

    test('installs both models and reports progress to completion', () async {
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );
      final progress = <ModelInstallProgress>[];

      await service.installAll(onProgress: progress.add);

      expect(installer.llmReady, isTrue);
      expect(installer.sttReady, isTrue);
      expect(installer.installCalls, 2);
      expect(progress.first.phase, ModelInstallPhase.checkingNetwork);
      expect(
        progress.any((p) => p.phase == ModelInstallPhase.downloadingLlm),
        isTrue,
      );
      expect(
        progress.any((p) => p.phase == ModelInstallPhase.downloadingSttModel),
        isTrue,
      );
      expect(progress.last.phase, ModelInstallPhase.completed);
      expect(progress.last.overall, 1);
    });

    test('skips installation when both models are already ready', () async {
      installer
        ..llmReady = true
        ..sttReady = true;
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: false, wifi: false),
      );
      final progress = <ModelInstallProgress>[];

      await service.installAll(onProgress: progress.add);

      expect(installer.installCalls, 0);
      expect(progress.single.phase, ModelInstallPhase.completed);
    });

    test('requires a network connection for the first download', () async {
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: false, wifi: true),
      );

      expect(
        () => service.installAll(onProgress: (_) {}),
        throwsA(isA<NoNetworkException>()),
      );
      expect(installer.installCalls, 0);
    });

    test('honors the Wi-Fi-only preference unless overridden', () async {
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: false),
      );

      await expectLater(
        service.installAll(onProgress: (_) {}),
        throwsA(isA<WifiRequiredException>()),
      );

      settings.wifiOnly = false;
      await service.installAll(onProgress: (_) {});
      expect(installer.llmReady, isTrue);
    });

    test('surfaces cancellation and leaves the models uninstalled', () async {
      installer.cancelLlm = true;
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );
      final progress = <ModelInstallProgress>[];

      await expectLater(
        service.installAll(onProgress: progress.add),
        throwsA(isA<DownloadCancelledException>()),
      );
      expect(installer.llmReady, isFalse);
      expect(
        progress.any((p) => p.phase == ModelInstallPhase.cancelled),
        isTrue,
      );
      expect(service.isDownloading, isFalse);
    });

    test('wraps installer failures in a user-facing model error', () async {
      installer.failLlm = true;
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );
      final progress = <ModelInstallProgress>[];

      await expectLater(
        service.installAll(onProgress: progress.add),
        throwsA(isA<ModelInstallException>()),
      );
      expect(progress.any((p) => p.phase == ModelInstallPhase.error), isTrue);
    });

    test('deletes models through the installer', () async {
      installer
        ..llmReady = true
        ..sttReady = true;
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );

      await service.deleteModels();

      expect(installer.uninstallCalls, 1);
      expect(installer.llmReady, isFalse);
      expect(installer.sttReady, isFalse);
    });

    test('a second install does not duplicate a download', () async {
      final service = ModelManagerService(
        settings: settings,
        installer: installer,
        networkChecker: FakeNetworkChecker(online: true, wifi: true),
      );
      final first = service.installAll(onProgress: (_) {});
      // The fake completes on a later microtask; the second call sees the
      // in-flight token and returns without starting another install.
      final second = service.installAll(onProgress: (_) {});

      await Future.wait([first, second]);
      expect(installer.installCalls, lessThanOrEqualTo(2));
      expect(service.isDownloading, isFalse);
    });
  });
}
