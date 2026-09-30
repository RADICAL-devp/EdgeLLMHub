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
        version: '2.0.0',
        minimumCompatibleVersion: '1.0.0',
        releaseDate: DateTime.utc(2026, 9, 30),
        changelog: 'Qwen 3 0.6B via flutter_gemma litertlm with Wi-Fi-gated download UI and clinical validation',
      );

  /// Supported model tiers for on-device inference.
  static const List<String> supportedModels = [
    'Qwen3-0.6B-dynamic-wi4b32-afp32',
  ];

  /// URL the Qwen 3 0.6B model file is downloaded from.
  ///
  /// Override via `--dart-define=MODEL_DOWNLOAD_URL=...`.
  /// Baked default is the public litert-community `.litertlm` build
  /// (329M); Xcode runs don't receive `--dart-define`, so the default
  /// must be real (no simulation on device). Post-install only — the
  /// model is never bundled with the store download.
  static String get modelDownloadUrl {
    const explicit = String.fromEnvironment('MODEL_DOWNLOAD_URL');
    if (explicit.isNotEmpty) return explicit;

    return switch (environment) {
      AppEnvironment.dev =>
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
      AppEnvironment.staging =>
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
      AppEnvironment.prod =>
        'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    };
  }

  /// Expected SHA-256 of the Qwen 3 0.6B model file (hex), used to verify downloads.
  ///
  /// Override via `--dart-define=MODEL_CHECKSUM_SHA256=...`.
  /// Baked default matches the hosted `.litertlm` above (verified byte-identical).
  static String get modelChecksumSha256 {
    const explicit = String.fromEnvironment('MODEL_CHECKSUM_SHA256');
    if (explicit.isNotEmpty) return explicit;

    return switch (environment) {
      AppEnvironment.dev =>
        '03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856',
      AppEnvironment.staging =>
        '03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856',
      AppEnvironment.prod =>
        '03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856',
    };
  }

  /// File name of the Qwen 3 0.6B on-device model artifact.
  static const String modelFileName =
      'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

  /// Legacy MLC bundle directory name. Unused by the flutter_gemma flow
  /// (single `.litertlm` file, no extraction); kept so older call sites
  /// referencing it keep compiling during the migration.
  static const String modelBundleDirName = 'Qwen3-0.6B-Q4_K_M-MLC';

  /// Minimum free disk space required for the model download (bytes).
  /// 329M file + headroom for the temp copy during SHA verification.
  static const int minFreeDiskSpaceBytes = 800 * 1024 * 1024;
}
