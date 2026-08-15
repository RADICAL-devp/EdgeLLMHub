import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Placeholder pin, replaced at deployment time. The real pin is injected at
/// build time: `flutter build --dart-define=BACKEND_CERT_PIN=sha256/<base64>`.
const String _unconfiguredPin = 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

/// Compile-time SHA-256 pin of the backend server certificate, set via
/// `--dart-define=BACKEND_CERT_PIN=sha256/<base64-of-SHA256(cert.der)>`
/// (raw base64 or 64-char hex also accepted).
const String kBackendCertPin = String.fromEnvironment('BACKEND_CERT_PIN');

/// Applies SHA-256 certificate pinning to a [Dio] instance.
///
/// How it works:
///   * Hooks [IOHttpClientAdapter.createHttpClient] so every [HttpClient]
///     created for this Dio verifies the presented server certificate against
///     the pinned fingerprint inside an `HttpClientBadCertificateCallback`.
///   * The connection is only allowed when the presented certificate's
///     SHA-256 matches the pin; on mismatch the callback returns `false`,
///     the TLS handshake fails, and the mismatch is logged.
///   * Scope is the Dio instance only — `dart:io` HttpOverrides are NOT used.
///     (dart:io does not exist on web; this app is mobile/desktop.)
///
/// Pinning is opt-in safe: when no pin is configured (placeholder), the
/// pinner logs a loud warning and leaves the default adapter untouched so
/// development against localhost/cleartext keeps working. A production build
/// MUST set `BACKEND_CERT_PIN`; deployments without it are intentionally
/// detectable in logs.
class CertificatePinner {
  CertificatePinner({bool? enablePinning, String? pinnedSha256})
      : enablePinning = enablePinning ?? true,
        pinnedSha256 = pinnedSha256 ?? kBackendCertPin;

  /// Master switch. Defaults to `true`; set to `false` in tests or when the
  /// deployment intentionally relies on system trust anchors only.
  final bool enablePinning;

  /// Expected SHA-256 pin: `sha256/<base64>`, raw base64, or 64 hex chars.
  final String pinnedSha256;

  /// True when a real pin (not the placeholder) is configured.
  bool get isConfigured {
    final pin = pinnedSha256.trim();
    return pin.isNotEmpty && pin != _unconfiguredPin;
  }

  /// Wires the pin check into [dio] by installing a pinning I/O adapter.
  ///
  /// No-op (with logging) when pinning is disabled, no pin is configured, or
  /// the dio already uses a non-default adapter (e.g. mock adapters in tests).
  void applyTo(Dio dio) {
    if (!enablePinning) {
      developer.log(
        'Certificate pinning disabled via enablePinning=false.',
        name: 'CertificatePinner',
      );
      return;
    }
    if (!isConfigured) {
      developer.log(
        'Certificate pinning NOT ACTIVE: no BACKEND_CERT_PIN configured. '
        'Set --dart-define=BACKEND_CERT_PIN=sha256/<pin> for production.',
        name: 'CertificatePinner',
      );
      return;
    }

    final existing = dio.httpClientAdapter;
    if (existing is PinningHttpClientAdapter) {
      return; // Already pinned.
    }
    if (existing.runtimeType != IOHttpClientAdapter) {
      developer.log(
        'Certificate pinning skipped: dio uses a custom adapter '
        '(${existing.runtimeType}).',
        name: 'CertificatePinner',
      );
      return;
    }

    dio.httpClientAdapter = PinningHttpClientAdapter(pinner: this);
    developer.log(
      'Certificate pinning active (pin=${_normalizedPin(pinnedSha256)})',
      name: 'CertificatePinner',
    );
  }

  /// Verifies a presented server certificate against the configured pin.
  ///
  /// Returns `true` only when the certificate's SHA-256 matches; mismatches
  /// are logged (with both digests) and reject the connection.
  @visibleForTesting
  bool verifyCertificate(X509Certificate cert, String host, int port) {
    final presented = base64Encode(sha256.convert(cert.der).bytes);
    final matches = fingerprintMatches(
      presentedSha256Base64: presented,
      pin: pinnedSha256,
    );
    if (!matches) {
      developer.log(
        'Certificate pin MISMATCH for $host:$port — presented '
        '$presented, expected ${_normalizedPin(pinnedSha256)}. '
        'Connection rejected.',
        name: 'CertificatePinner',
      );
    }
    return matches;
  }

  /// True when the presented SHA-256 fingerprint matches [pin].
  ///
  /// [pin] may be `sha256/<base64>`, raw base64, or 64 hex chars (compared
  /// case-insensitively).
  @visibleForTesting
  static bool fingerprintMatches({
    required String presentedSha256Base64,
    required String pin,
  }) {
    final normalized = _normalizedPin(pin);
    if (normalized.isEmpty) return false;
    return presentedSha256Base64.toLowerCase() == normalized.toLowerCase();
  }

  /// Normalizes a pin to base64; hex pins are converted to their raw bytes.
  static String _normalizedPin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.isEmpty) return '';
    final raw = trimmed.startsWith('sha256/') ? trimmed.substring(7) : trimmed;

    // 64 hex chars → raw SHA-256 bytes → base64.
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(raw)) {
      return base64Encode(_hexToBytes(raw));
    }
    return raw;
  }

  static List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}

/// [IOHttpClientAdapter] whose `HttpClient`s reject any certificate that does
/// not match the pin, via `HttpClient.badCertificateCallback`.
class PinningHttpClientAdapter extends IOHttpClientAdapter {
  PinningHttpClientAdapter({required CertificatePinner pinner})
      : super(
          createHttpClient: () {
            final client = HttpClient()
              ..idleTimeout = const Duration(seconds: 3);
            client.badCertificateCallback =
                pinner.verifyCertificate; // (cert, host, port)
            return client;
          },
        );
}
