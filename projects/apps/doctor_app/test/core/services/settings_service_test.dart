import 'package:doctor_app/core/config/app_config.dart';
import 'package:doctor_app/core/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('has safe defaults for a first launch', () async {
    final settings = SettingsService();
    await settings.init();

    expect(settings.hasCompletedOnboarding, isFalse);
    expect(settings.hasAcceptedConsent, isFalse);
    expect(settings.thinkingMode, isFalse);
    expect(settings.languageCode, AppConfig.defaultLanguageCode);
    expect(settings.wifiOnlyDownloads, isTrue);
  });

  test(
    'persists onboarding, consent, language, thinking and Wi-Fi choices',
    () async {
      final settings = SettingsService();
      await settings.init();

      await settings.completeOnboarding();
      await settings.setThinkingMode(true);
      await settings.setLanguageCode('hi');
      await settings.setWifiOnlyDownloads(false);

      final reloaded = SettingsService();
      await reloaded.init();
      expect(reloaded.hasCompletedOnboarding, isTrue);
      expect(reloaded.hasAcceptedConsent, isTrue);
      expect(reloaded.thinkingMode, isTrue);
      expect(reloaded.languageCode, 'hi');
      expect(reloaded.wifiOnlyDownloads, isFalse);
    },
  );

  test('invalid language codes fall back to English', () async {
    final settings = SettingsService();
    await settings.init();

    await settings.setLanguageCode('fr');
    expect(settings.languageCode, AppConfig.defaultLanguageCode);

    await settings.setLanguageCode('hi');
    expect(settings.languageCode, 'hi');
  });

  test('resetOnboarding clears consent but keeps other preferences', () async {
    final settings = SettingsService();
    await settings.init();
    await settings.completeOnboarding();
    await settings.setThinkingMode(true);

    await settings.resetOnboarding();

    expect(settings.hasCompletedOnboarding, isFalse);
    expect(settings.hasAcceptedConsent, isFalse);
    expect(settings.thinkingMode, isTrue);
  });
}
