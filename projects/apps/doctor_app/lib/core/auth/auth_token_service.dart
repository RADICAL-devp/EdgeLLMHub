import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:doctor_app/core/auth/token_storage.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/network/dio_error_handler.dart';

/// Fetches and caches a bearer token from the backend.
///
/// Against the development backend this hits the dev token mint endpoint
/// (`POST /api/v1/auth/token`). A real identity provider can replace this
/// implementation without touching callers.
///
/// Security (Workstream 8): the token is persisted ONLY through the
/// injectable [TokenStorage] — [SecureTokenStorage] (Keychain/Keystore) in
/// production, [InMemoryTokenStorage] in tests. It is never written to
/// SharedPreferences. Persistence failures are logged and never block the
/// request path.
class AuthTokenService {
  AuthTokenService(this._dio, {TokenStorage? storage})
      : _storage = storage ?? InMemoryTokenStorage();

  final Dio _dio;
  final TokenStorage _storage;

  static const tokenPath = '/api/v1/auth/token';

  /// Grace period before expiry during which the token is re-minted.
  static const _expirySkew = Duration(minutes: 5);

  String? _token;
  DateTime? _expiresAt;

  bool get hasToken => _token != null;

  /// Returns a valid token, minting or refreshing it if needed.
  Future<String> getToken() async {
    final cached = _token;
    final expiresAt = _expiresAt;
    if (_isUsable(cached, expiresAt)) return cached!;

    // Hydrate from the persistent store before minting, so a token persisted
    // by a previous app run is reused rather than re-minted.
    final stored = await _storage.read();
    if (stored != null && _isUsable(stored.token, stored.expiresAt)) {
      _token = stored.token;
      _expiresAt = stored.expiresAt;
      return stored.token;
    }

    final Map<String, dynamic> data;
    try {
      final response = await _dio.post<Map<String, dynamic>>(tokenPath);
      data = response.data ?? const {};
    } on DioException catch (e) {
      throw DioErrorHandler.handle(e, context: 'auth token');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        'Failed to acquire auth token: $e',
        cause: e,
        isTransient: true,
      );
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const NetworkException(
        'Auth token endpoint returned an invalid response',
        isTransient: false,
      );
    }

    _token = token;
    _expiresAt = DateTime.tryParse(data['expiresAt'] as String? ?? '');
    await _writePersisted();
    return token;
  }

  /// Drop the cached token so the next request re-mints it.
  ///
  /// Also clears the persisted copy (best-effort; storage failures are
  /// logged and do not throw).
  Future<void> invalidate() async {
    _token = null;
    _expiresAt = null;
    try {
      await _storage.clear();
    } catch (e) {
      developer.log(
        'Failed to clear persisted auth token: $e',
        name: 'AuthTokenService',
        error: e,
      );
    }
  }

  bool _isUsable(String? token, DateTime? expiresAt) {
    return token != null &&
        expiresAt != null &&
        DateTime.now().toUtc().isBefore(expiresAt.subtract(_expirySkew));
  }

  Future<void> _writePersisted() async {
    try {
      await _storage.write(StoredAuthToken(token: _token!, expiresAt: _expiresAt));
    } catch (e) {
      // Persisting is best-effort: the in-memory token remains valid for
      // this process even if the secure store is unavailable.
      developer.log(
        'Failed to persist auth token: $e',
        name: 'AuthTokenService',
        error: e,
      );
    }
  }
}
