import 'package:dio/dio.dart';
import 'package:doctor_app/core/auth/auth_token_service.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Attaches `Authorization: Bearer <token>` to every request and refreshes
/// the token once on 401.
///
/// The token mint endpoint itself is skipped to avoid recursion.
/// Requests that fail 401 twice are passed through unchanged so downstream
/// handlers can map them to typed [NetworkException]s.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokenService);

  final Dio _dio;
  final AuthTokenService _tokenService;

  final Set<RequestOptions> _retried = {};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains(AuthTokenService.tokenPath)) {
      return handler.next(options);
    }

    try {
      final token = await _tokenService.getToken();
      options.headers['Authorization'] = 'Bearer $token';
      return handler.next(options);
    } on AppException catch (e) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          error: e,
          message: e.message,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isTokenPath = options.path.contains(AuthTokenService.tokenPath);
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = _retried.contains(options);

    if (!isTokenPath && isUnauthorized && !alreadyRetried) {
      _retried.add(options);
      _tokenService.invalidate();
      try {
        final token = await _tokenService.getToken();
        options.headers['Authorization'] = 'Bearer $token';
        final response = await _dio.fetch<dynamic>(options);
        return handler.resolve(response);
      } catch (_) {
        // Fall through to the original 401.
      }
    }

    return handler.next(err);
  }
}
