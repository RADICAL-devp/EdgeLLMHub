import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Small, non-PHI preferences only. Clinical content never goes here.
class SettingsService extends ChangeNotifier {
  static const _kOnboardingComplete = 'onboarding_complete_v1';
  static const _kConsentAccepted = 'consent_accepted_v1';
  static const _kThinkingMode = 'thinking_mode';
  static const _kLanguageCode = 'language_code';
  static const _kWifiOnly = 'wifi_only_downloads';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _store {
    final store = _prefs;
    if (store == null) {
      throw StateError(
        'SettingsService.init() must run before reading settings',
      );
    }
    return store;
  }

  bool get hasCompletedOnboarding =>
      _store.getBool(_kOnboardingComplete) ?? false;

  bool get hasAcceptedConsent => _store.getBool(_kConsentAccepted) ?? false;

  /// Default is deliberately off: thinking mode is much slower.
  bool get thinkingMode => _store.getBool(_kThinkingMode) ?? false;

  String get languageCode {
    final code =
        _store.getString(_kLanguageCode) ?? AppConfig.defaultLanguageCode;
    return AppConfig.supportedLanguages.containsKey(code)
        ? code
        : AppConfig.defaultLanguageCode;
  }

  bool get wifiOnlyDownloads => _store.getBool(_kWifiOnly) ?? true;

  Future<void> completeOnboarding() async {
    await _store.setBool(_kConsentAccepted, true);
    await _store.setBool(_kOnboardingComplete, true);
    notifyListeners();
  }

  Future<void> setConsentAccepted(bool value) async {
    await _store.setBool(_kConsentAccepted, value);
    notifyListeners();
  }

  Future<void> setThinkingMode(bool value) async {
    await _store.setBool(_kThinkingMode, value);
    notifyListeners();
  }

  Future<void> setLanguageCode(String value) async {
    final safe = AppConfig.supportedLanguages.containsKey(value)
        ? value
        : AppConfig.defaultLanguageCode;
    await _store.setString(_kLanguageCode, safe);
    notifyListeners();
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    await _store.setBool(_kWifiOnly, value);
    notifyListeners();
  }

  /// Debug/testing helper. Also used by "Reset onboarding" in Settings.
  Future<void> resetOnboarding() async {
    await _store.setBool(_kConsentAccepted, false);
    await _store.setBool(_kOnboardingComplete, false);
    notifyListeners();
  }
}
