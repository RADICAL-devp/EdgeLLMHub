/// Application environment configuration.
///
/// The environment is selected at compile time via `--dart-define=ENV=dev`.
/// Backend URLs and feature flags vary per environment.
enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment get current {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    return AppEnvironment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => AppEnvironment.dev,
    );
  }
}

/// Centralized configuration resolved from compile-time defines and
/// environment defaults.
class EnvironmentConfig {
  EnvironmentConfig._();

  /// The current environment.
  static AppEnvironment get environment => AppEnvironment.current;

  /// Base URL for the clinical intelligence backend API.
  ///
  /// Priority:
  /// 1. Explicit `--dart-define=API_URL=...` (highest)
  /// 2. Environment-specific default
  static String get apiBaseUrl {
    const explicit = String.fromEnvironment('API_URL');
    if (explicit.isNotEmpty) return explicit;

    return switch (environment) {
      AppEnvironment.dev => 'http://127.0.0.1:8080',
      AppEnvironment.staging => 'https://staging-api.doctorapp.example.com',
      AppEnvironment.prod => 'https://api.doctorapp.example.com',
    };
  }

  /// Android emulator-specific base URL (uses 10.0.2.2 to reach host).
  static String get androidEmulatorApiUrl {
    const explicit = String.fromEnvironment('API_URL');
    if (explicit.isNotEmpty) return explicit;
    return 'http://10.0.2.2:8080';
  }

  /// Whether cloud LLM fallback is enabled.
  ///
  /// Defaults to false — PHI must NOT leave the device unless compliance
  /// has explicitly approved cloud processing.
  static bool get cloudLlmEnabled {
    const value = String.fromEnvironment('CLOUD_LLM_ENABLED');
    return value.toLowerCase() == 'true';
  }

  /// Whether the app is in debug/development mode.
  static bool get isDebug => environment == AppEnvironment.dev;

  /// Whether to enable verbose network logging.
  static bool get enableNetworkLogging => isDebug;

  /// OAuth client ID for cloud authentication.
  static const String oauthClientId = String.fromEnvironment(
    'OAUTH_CLIENT_ID',
    defaultValue: '',
  );

  /// Supported model tiers for on-device inference.
  static const List<String> supportedModels = [
    'Llama-3.2-3B-Instruct-q4f16_1-MLC',
    'Llama-3.2-1B-Instruct-q4f16_1-MLC',
  ];
}
