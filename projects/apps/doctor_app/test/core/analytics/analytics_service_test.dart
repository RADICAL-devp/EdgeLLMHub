import 'dart:async';
import 'dart:convert';

import 'package:doctor_app/core/analytics/analytics_service.dart';
import 'package:doctor_app/core/observability/json_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for [AnalyticsService] consent gating: events are recorded when
/// consent is granted and never when it is revoked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService', () {
    late List<String> lines;
    late bool consentGranted;

    AnalyticsService buildService({ConsentProvider? consentProvider}) {
      return AnalyticsService(
        logger: JsonLogger(sink: lines.add),
        consentProvider: consentProvider ?? () async => consentGranted,
      );
    }

    List<Map<String, dynamic>> records() =>
        lines.map((line) => jsonDecode(line) as Map<String, dynamic>).toList();

    setUp(() {
      lines = <String>[];
      consentGranted = true;
    });

    group('when consent is granted', () {
      test('records screen views with event type and screen', () async {
        final service = buildService();
        await service.trackScreenView('settings');

        expect(lines, hasLength(1));
        final record = records().single;
        expect(record['level'], 'info');
        expect(record['event'], 'screen_view');
        expect(record['screen'], 'settings');
      });

      test('records AI assist usage with the action', () async {
        final service = buildService();
        await service.trackAiAssist('suggest', properties: {'mode': 'vocab'});

        expect(lines, hasLength(1));
        final record = records().single;
        expect(record['event'], 'ai_assist');
        expect(record['action'], 'suggest');
        expect(record['mode'], 'vocab');
      });

      test('records errors with errorType and message', () async {
        final service = buildService();
        await service.trackError('llm_inference', 'engine timed out',
            error: TimeoutException('t'));

        expect(lines, hasLength(1));
        final record = records().single;
        expect(record['level'], 'error');
        expect(record['event'], 'error');
        expect(record['errorType'], 'llm_inference');
        expect(record['message'], 'engine timed out');
        expect(record['error'], contains('TimeoutException'));
      });

      test('includes per-event properties', () async {
        final service = buildService();
        await service.trackScreenView('note_editor', properties: {
          'consultationId': 'c-1',
          'durationMs': 42,
        });

        final record = records().single;
        expect(record['consultationId'], 'c-1');
        expect(record['durationMs'], 42);
      });
    });

    group('when consent is revoked', () {
      test('records nothing for screen views, AI assist or errors', () async {
        consentGranted = false;
        final service = buildService();

        await service.trackScreenView('settings');
        await service.trackAiAssist('suggest');
        await service.trackError('sync', 'boom', error: Exception('x'));

        expect(lines, isEmpty);
      });
    });

    group('consent gate reflects the settings flag', () {
      test('default provider reads the phi_consent_granted preference', () async {
        SharedPreferences.setMockInitialValues({analyticsConsentPrefKey: true});
        final granted = AnalyticsService(logger: JsonLogger(sink: lines.add));
        expect(await granted.consentGranted, isTrue);
        await granted.trackScreenView('settings');
        expect(lines, hasLength(1));
      });

      test('revoking the flag stops recording through the same key', () async {
        SharedPreferences.setMockInitialValues({analyticsConsentPrefKey: false});
        final revoked = AnalyticsService(logger: JsonLogger(sink: lines.add));
        expect(await revoked.consentGranted, isFalse);
        await revoked.trackScreenView('settings');
        expect(lines, isEmpty);
      });
    });
  });
}
