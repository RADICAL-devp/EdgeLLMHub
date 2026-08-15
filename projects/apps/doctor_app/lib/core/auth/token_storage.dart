import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A cached auth token and its expiry, as persisted by [TokenStorage].
class StoredAuthToken {
  const StoredAuthToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime? expiresAt;
}

/// Abstraction over where auth tokens are persisted.
///
/// This is the "platform interface" for token persistence: the production
/// app uses [SecureTokenStorage] (Keychain/Keystore via flutter_secure_storage)
/// while tests inject [InMemoryTokenStorage]. Callers must never touch
/// SharedPreferences for credentials — it is not encrypted.
abstract class TokenStorage {
  /// Reads the cached token, or `null` when nothing is persisted.
  Future<StoredAuthToken?> read();

  /// Persists a freshly minted token.
  Future<void> write(StoredAuthToken token);

  /// Removes any persisted token (e.g. on invalidation).
  Future<void> clear();
}

/// In-memory [TokenStorage] used by default and in tests.
///
/// NOTE (Workstream 8): the auth token is intentionally held in memory here —
/// the previous implementation never persisted it at all (no SharedPreferences
/// usage). Any FUTURE persistence of credentials must go through
/// [TokenStorage] (i.e. [SecureTokenStorage]), never SharedPreferences.
class InMemoryTokenStorage implements TokenStorage {
  StoredAuthToken? _token;

  @override
  Future<StoredAuthToken?> read() async => _token;

  @override
  Future<void> write(StoredAuthToken token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

/// [TokenStorage] backed by the OS secure enclave:
/// Keychain on iOS/macOS, Keystore-backed encryption on Android.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_token_expires_at';

  /// Keychain items must survive background work (workmanager sync) while
  /// the device is unlocked after its first unlock.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<StoredAuthToken?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;
      final expiresAtRaw = await _storage.read(key: _expiresAtKey);
      final expiresAt = DateTime.tryParse(expiresAtRaw ?? '');
      return StoredAuthToken(token: token, expiresAt: expiresAt);
    } catch (e) {
      // A secure-storage failure must never block the request path — the
      // caller falls back to minting a fresh token.
      developer.log(
        'SecureTokenStorage.read failed: $e',
        name: 'SecureTokenStorage',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<void> write(StoredAuthToken token) async {
    try {
      await _storage.write(
        key: _tokenKey,
        value: token.token,
        iOptions: _iosOptions,
      );
      if (token.expiresAt != null) {
        await _storage.write(
          key: _expiresAtKey,
          value: token.expiresAt!.toUtc().toIso8601String(),
          iOptions: _iosOptions,
        );
      }
    } catch (e) {
      developer.log(
        'SecureTokenStorage.write failed: $e',
        name: 'SecureTokenStorage',
        error: e,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey, iOptions: _iosOptions);
      await _storage.delete(key: _expiresAtKey, iOptions: _iosOptions);
    } catch (e) {
      developer.log(
        'SecureTokenStorage.clear failed: $e',
        name: 'SecureTokenStorage',
        error: e,
      );
    }
  }
}
