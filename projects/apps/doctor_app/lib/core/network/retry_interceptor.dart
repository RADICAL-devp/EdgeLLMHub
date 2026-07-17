import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';

/// Dio interceptor that retries transient failures with exponential backoff.
///
/// Rules:
///   - Only retries on connection timeouts, receive timeouts, and
///     connection errors (transient failures).
///   - Does NOT retry POST requests by default (non-idempotent).
///   - Maximum 3 retries with exponential backoff: 1s, 2s, 4s.
///   - Adds jitter to prevent thundering herd.
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  /// HTTP methods considered safe to retry (idempotent).
  static const _retryableMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount = _getRetryCount(err.requestOptions);
    if (retryCount >= maxRetries) {
      developer.log(
        'Max retries ($maxRetries) exceeded for ${err.requestOptions.path}',
        name: 'RetryInterceptor',
      );
      return handler.next(err);
    }

    // Exponential backoff with jitter
    final delay = _calculateDelay(retryCount);
    developer.log(
      'Retry ${retryCount + 1}/$maxRetries for ${err.requestOptions.path} '
      'after ${delay.inMilliseconds}ms (${err.type})',
      name: 'RetryInterceptor',
    );

    await Future<void>.delayed(delay);

    // Clone the request with incremented retry count
    final options = err.requestOptions;
    options.extra['_retryCount'] = retryCount + 1;

    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    // Only retry transient error types
    final isTransientType = switch (err.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse =>
        (err.response?.statusCode ?? 0) >= 500, // 5xx server errors
      _ => false,
    };

    if (!isTransientType) return false;

    // Only retry idempotent methods (never retry POST)
    final method = err.requestOptions.method.toUpperCase();
    final isIdempotent = _retryableMethods.contains(method);

    // Allow explicit opt-in for POST via extra flag
    final forceRetry = err.requestOptions.extra['_retryable'] == true;

    return isIdempotent || forceRetry;
  }

  int _getRetryCount(RequestOptions options) {
    return options.extra['_retryCount'] as int? ?? 0;
  }

  Duration _calculateDelay(int retryCount) {
    // Exponential backoff: baseDelay * 2^retryCount
    final exponentialMs = baseDelay.inMilliseconds * pow(2, retryCount);
    // Add jitter: ±25%
    final jitter = (Random().nextDouble() * 0.5 - 0.25) * exponentialMs;
    return Duration(milliseconds: (exponentialMs + jitter).round());
  }
}
