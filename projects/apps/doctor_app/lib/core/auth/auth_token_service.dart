import 'package:dio/dio.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/network/dio_error_handler.dart';

/// Fetches and caches a bearer token from the backend.
///
/// Against the development backend this hits the dev token mint endpoint
/// (`POST /api/v1/auth/token`). A real identity provider can replace this
/// implementation without touching callers.
class AuthTokenService {
  AuthTokenService(this._dio);

  final Dio _dio;

  static const tokenPath = '/api/v1/auth/token';

  String? _token;
  DateTime? _expiresAt;

  bool get hasToken => _token != null;

  /// Returns a valid token, minting or refreshing it if needed.
  Future<String> getToken() async {
    final cached = _token;
    final expiresAt = _expiresAt;
    final valid = cached != null &&
        expiresAt != null &&
        DateTime.now()
            .toUtc()
            .isBefore(expiresAt.subtract(const Duration(minutes: 5)));
    if (valid) return cached;

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
    return token;
  }

  /// Drop the cached token so the next request re-mints it.
  void invalidate() {
    _token = null;
    _expiresAt = null;
  }
}
