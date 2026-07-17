import 'package:dio/dio.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Maps [DioException] to typed [NetworkException].
///
/// Centralizes all Dio error mapping so adapters and datasources don't
/// each re-implement the same logic.
class DioErrorHandler {
  DioErrorHandler._();

  /// Convert a [DioException] into a [NetworkException] with transience
  /// and status code metadata.
  static NetworkException handle(DioException e, {String? context}) {
    final statusCode = e.response?.statusCode;
    final prefix = context != null ? '[$context] ' : '';

    return switch (e.type) {
      DioExceptionType.connectionTimeout => NetworkException(
          '${prefix}Connection timed out',
          cause: e,
          statusCode: statusCode,
          isTransient: true,
        ),
      DioExceptionType.sendTimeout => NetworkException(
          '${prefix}Send timed out',
          cause: e,
          statusCode: statusCode,
          isTransient: true,
        ),
      DioExceptionType.receiveTimeout => NetworkException(
          '${prefix}Receive timed out',
          cause: e,
          statusCode: statusCode,
          isTransient: true,
        ),
      DioExceptionType.connectionError => NetworkException(
          '${prefix}Cannot reach server',
          cause: e,
          isTransient: true,
        ),
      DioExceptionType.badCertificate => NetworkException(
          '${prefix}SSL certificate error',
          cause: e,
          isTransient: false,
        ),
      DioExceptionType.badResponse => _handleBadResponse(e, prefix),
      DioExceptionType.cancel => NetworkException(
          '${prefix}Request cancelled',
          cause: e,
          isTransient: false,
        ),
      DioExceptionType.unknown => NetworkException(
          '${prefix}Unknown network error: ${e.message}',
          cause: e,
          isTransient: true,
        ),
      _ => NetworkException(
          '${prefix}Unexpected network error: ${e.message}',
          cause: e,
          isTransient: true,
        ),
    };
  }

  static NetworkException _handleBadResponse(DioException e, String prefix) {
    final statusCode = e.response?.statusCode ?? 0;
    final responseData = e.response?.data;

    // Extract server error message if available
    String serverMessage = '';
    if (responseData is Map<String, dynamic>) {
      serverMessage = responseData['message'] as String? ??
          responseData['error'] as String? ??
          '';
    } else if (responseData is String) {
      serverMessage = responseData;
    }

    final message = serverMessage.isNotEmpty
        ? '${prefix}Server error ($statusCode): $serverMessage'
        : '${prefix}Server returned $statusCode';

    return NetworkException(
      message,
      cause: e,
      statusCode: statusCode,
      // 5xx = server-side, transient; 4xx = client-side, permanent
      isTransient: statusCode >= 500,
    );
  }
}
