import 'package:doctor_app/core/services/device_capability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceCapabilityService', () {
    test('canRunLocalLlm returns false on simulators', () async {
      // In the test environment Platform.isIOS/Android are false, so
      // isSimulator is false and canRunLocalLlm returns false for
      // non-iOS/Android hosts.
      final service = DeviceCapabilityService();
      expect(await service.canRunLocalLlm(), isFalse);
    });

    test('canUseSpeechToText mirrors the simulator check', () async {
      final service = DeviceCapabilityService();
      final simulator = await service.isSimulator;
      expect(await service.canUseSpeechToText(), isNot(simulator));
    });

    test('getRecommendedExecutionMode falls back to cloud on desktop',
        () async {
      final service = DeviceCapabilityService();
      final mode = await service.getRecommendedExecutionMode();
      // Host test runner is macOS — not a mobile platform, so cloud.
      expect(mode, ExecutionMode.cloud);
    });

    test('getUnsupportedMessage is user friendly', () {
      expect(
        DeviceCapabilityService().getUnsupportedMessage(),
        contains('cloud-fallback'),
      );
    });
  });
}
