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

    test('model download configuration defaults to hosted Qwen litertlm', () {
      // Xcode runs receive no --dart-define, so baked defaults must be real
      // (verified litert-community .litertlm download, post-install only).
      expect(EnvironmentConfig.modelDownloadUrl,
          'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm');
      expect(EnvironmentConfig.modelChecksumSha256,
          '03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856');
      expect(
        EnvironmentConfig.modelFileName,
        'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
      );
      expect(
        EnvironmentConfig.modelBundleDirName,
        'Qwen3-0.6B-Q4_K_M-MLC',
      );
    });

    test('supported model tier list contains the Qwen3 litertlm bundle', () {
      expect(
        EnvironmentConfig.supportedModels,
        contains('Qwen3-0.6B-dynamic-wi4b32-afp32'),
      );
    });
  });
}
