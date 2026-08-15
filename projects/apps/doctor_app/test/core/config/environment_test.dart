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

    test('model download configuration defaults to empty', () {
      expect(EnvironmentConfig.modelDownloadUrl, isEmpty);
      expect(EnvironmentConfig.modelChecksumSha256, isEmpty);
      expect(
        EnvironmentConfig.modelFileName,
        'smolLM-360M-Instruct-q4f16_1-MLC.zip',
      );
      expect(
        EnvironmentConfig.modelBundleDirName,
        'SmolLM-360M-Instruct-q4f16_1-MLC',
      );
    });

    test('supported model tier list contains the SmolLM MLC bundle', () {
      expect(
        EnvironmentConfig.supportedModels,
        contains('SmolLM-360M-Instruct-q4f16_1-MLC'),
      );
    });
  });
}
