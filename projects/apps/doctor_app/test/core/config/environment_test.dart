import 'package:doctor_app/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvironmentConfig', () {
    test('apiBaseUrl resolves per environment defaults', () {
      expect(
        EnvironmentConfig.apiBaseUrl,
        switch (EnvironmentConfig.environment) {
          AppEnvironment.dev => 'http://127.0.0.1:8080',
          AppEnvironment.staging => 'https://staging-api.doctorapp.example.com',
          AppEnvironment.prod => 'https://api.doctorapp.example.com',
        },
      );
    });

    test('androidEmulatorApiUrl uses host loopback by default', () {
      expect(EnvironmentConfig.androidEmulatorApiUrl, 'http://10.0.2.2:8080');
    });

    test('isDebug tracks the dev environment', () {
      expect(
        EnvironmentConfig.isDebug,
        EnvironmentConfig.environment == AppEnvironment.dev,
      );
      expect(EnvironmentConfig.enableNetworkLogging, EnvironmentConfig.isDebug);
    });

    test('model download configuration defaults to hosted Qwen bundle', () {
      // Xcode runs receive no --dart-define, so baked defaults must be real
      // (verified HF Hub upload of the true Qwen3 MLC bundle).
      expect(EnvironmentConfig.modelDownloadUrl,
          'https://huggingface.co/Devanshparashar02/doctorapp-qwen3-0.6b-mlc/resolve/main/qwen3-0.6b-Q4_K_M.zip');
      expect(EnvironmentConfig.modelChecksumSha256,
          '447145d7dbb9ee2fc9047e3cfa64ef4a324397e8208580c7348e5c4002ed8c83');
      expect(
        EnvironmentConfig.modelFileName,
        'qwen3-0.6b-Q4_K_M.zip',
      );
      expect(
        EnvironmentConfig.modelBundleDirName,
        'Qwen3-0.6B-Q4_K_M-MLC',
      );
    });

    test('supported model tier list contains the Qwen3 MLC bundle', () {
      expect(
        EnvironmentConfig.supportedModels,
        contains('Qwen3-0.6B-Q4_K_M-MLC'),
      );
    });
  });
}
