class AppConfig {
  /// The base URL for the clinical intelligence backend API.
  /// 
  /// This is configured via Dart define at compile time:
  /// `flutter run --dart-define=API_URL=http://192.168.1.100:8080`
  /// 
  /// Defaults to null, in which case the environment-aware logic
  /// (e.g., 10.0.2.2 for Android emulator) takes over.
  static const String? apiUrl = String.fromEnvironment('API_URL') != '' 
      ? String.fromEnvironment('API_URL') 
      : null;
}
