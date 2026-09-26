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

/// Model version information for upgrade/downgrade detection.
class ModelVersion {
  ModelVersion({
    required this.version,
    required this.minimumCompatibleVersion,
    required this.releaseDate,
    required this.changelog,
  });

  final String version; // e.g., "1.0.0"
  final String minimumCompatibleVersion; // e.g., "1.0.0"
  final DateTime releaseDate;
  final String changelog;

  bool isCompatibleWith(String otherVersion) {
    return _compareVersions(otherVersion, minimumCompatibleVersion) >= 0;
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'minimumCompatibleVersion': minimumCompatibleVersion,
        'releaseDate': releaseDate.toIso8601String(),
        'changelog': changelog,
      };

  static ModelVersion fromJson(Map<String, dynamic> json) => ModelVersion(
        version: json['version'] as String,
        minimumCompatibleVersion: json['minimumCompatibleVersion'] as String,
        releaseDate: DateTime.parse(json['releaseDate'] as String),
        changelog: json['changelog'] as String,
      );
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
  /// Configurable via `--dart-define=CLOUD_LLM_ENABLED=true`.
  /// Default: false — PHI must NOT leave the device.
  /// On-device inference only (native MLC → stub fallback).
  static bool get cloudLlmEnabled {
    const explicit = String.fromEnvironment('CLOUD_LLM_ENABLED');
    return explicit.isNotEmpty && explicit.toLowerCase() == 'true';
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

  /// Current model version embedded in the app bundle.
  static ModelVersion get bundledModelVersion => ModelVersion(
        version: '1.2.0',
        minimumCompatibleVersion: '1.0.0',
        releaseDate: DateTime.utc(2026, 9, 8),
        changelog: 'Qwen 3 0.6B medical LLM with specialty prompts, download UI, and clinical validation',
      );

  /// Supported model tiers for on-device inference.
  static const List<String> supportedModels = [
    'Qwen3-0.6B-Q4_K_M-MLC',
  ];

  /// URL the Qwen 3 0.6B model binary is downloaded from.
  ///
  /// Override via `--dart-define=MODEL_DOWNLOAD_URL=...`.
  /// In production, this should point to a signed GCP/AWS bucket URL.
  static String get modelDownloadUrl {
    const explicit = String.fromEnvironment('MODEL_DOWNLOAD_URL');
    if (explicit.isNotEmpty) return explicit;

    return switch (environment) {
      AppEnvironment.dev => '',
      AppEnvironment.staging => 'https://storage.googleapis.com/doctorapp-staging/models/qwen3-0.6b-Q4_K_M.zip',
      AppEnvironment.prod => 'https://storage.googleapis.com/doctorapp-prod/models/qwen3-0.6b-Q4_K_M.zip',
    };
  }

  /// Expected SHA-256 of the Qwen 3 0.6B model binary (hex), used to verify downloads.
  ///
  /// Override via `--dart-define=MODEL_CHECKSUM_SHA256=...`.
  static String get modelChecksumSha256 {
    const explicit = String.fromEnvironment('MODEL_CHECKSUM_SHA256');
    if (explicit.isNotEmpty) return explicit;

    final checksum = switch (environment) {
      AppEnvironment.dev => '',
      AppEnvironment.staging => 'STAGING_QWEN3_CHECKSUM_PLACEHOLDER_REPLACE_IN_CI',
      AppEnvironment.prod => 'PROD_QWEN3_CHECKSUM_PLACEHOLDER_REPLACE_IN_CI',
    };

    if (environment != AppEnvironment.dev && checksum.contains('PLACEHOLDER_REPLACE_IN_CI')) {
      throw StateError('Invalid model checksum for $environment environment: placeholders must be replaced by CI/CD');
    }

    return checksum;
  }

  /// File name of the Qwen 3 0.6B on-device model artifact.
  static const String modelFileName = 'qwen3-0.6b-Q4_K_M.zip';

  /// Directory name the downloaded Qwen 3 model archive is extracted into.
  static const String modelBundleDirName = 'Qwen3-0.6B-Q4_K_M-MLC';

  /// Minimum free disk space required for model download + extraction (bytes).
  static const int minFreeDiskSpaceBytes = 500 * 1024 * 1024; // 500 MB (was 2GB for SmolLM)
}
