import 'package:doctor_app/core/observability/json_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key backing the PHI consent gate.
///
/// Legacy: the settings page no longer exposes a consent toggle because
/// cloud processing is disabled by design (PHI never leaves the device),
/// so this key is never written and analytics tracking stays off.
const String analyticsConsentPrefKey = 'phi_consent_granted';

/// Resolves whether analytics tracking is currently permitted.
typedef ConsentProvider = Future<bool> Function();

/// Consent-gated, offline-first analytics tracking.
///
/// Tracks screen views, AI assist usage and errors by emitting JSON log
/// records through [JsonLogger] — nothing is ever sent over the network.
/// Every event is gated on the PHI consent flag: when consent is revoked,
/// no event is recorded at all.
class AnalyticsService {
  AnalyticsService({JsonLogger? logger, ConsentProvider? consentProvider})
      : _logger = logger ?? JsonLogger(name: 'analytics'),
        _consentProvider = consentProvider ?? _prefsConsentProvider;

  final JsonLogger _logger;
  final ConsentProvider _consentProvider;

  /// Whether tracking is currently permitted, per the consent flag.
  Future<bool> get consentGranted => _consentProvider();

  /// Reads the consent flag from the same SharedPreferences key the
  /// settings page writes (`phi_consent_granted`).
  static Future<bool> _prefsConsentProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(analyticsConsentPrefKey) ?? false;
  }

  /// Records a screen view (e.g. 'settings', 'note_editor').
  Future<void> trackScreenView(
    String screenName, {
    Map<String, Object?>? properties,
  }) {
    return _track('screen_view', {
      'screen': screenName,
      ...?properties,
    });
  }

  /// Records an AI assist interaction (e.g. 'suggest', 'complete',
  /// 'success', 'failure').
  Future<void> trackAiAssist(
    String action, {
    Map<String, Object?>? properties,
  }) {
    return _track('ai_assist', {
      'action': action,
      ...?properties,
    });
  }

  /// Records an error (e.g. 'llm_inference', 'sync', 'ui').
  Future<void> trackError(
    String errorType,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) async {
    if (!await _consentProvider()) return;
    _logger.error(
      message,
      error: error,
      stackTrace: stackTrace,
      context: {
        'event': 'error',
        'errorType': errorType,
        ...?properties,
      },
    );
  }

  /// Gated event emission — no-op when consent has been revoked.
  Future<void> _track(String event, Map<String, Object?> properties) async {
    if (!await _consentProvider()) return;
    _logger.info('analytics_event', context: {
      'event': event,
      ...properties,
    });
  }
}
