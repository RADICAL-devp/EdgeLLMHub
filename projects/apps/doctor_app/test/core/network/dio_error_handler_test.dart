import 'package:doctor_app/core/exceptions/app_exceptions.dart';
import 'package:doctor_app/core/network/dio_error_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _exception(DioExceptionType type, {int? status, Object? data}) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/test'),
    type: type,
    message: 'boom',
    response: status != null
        ? Response(
            requestOptions: RequestOptions(path: '/api/test'),
            statusCode: status,
            data: data,
          )
        : null,
  );
}

void main() {
  group('DioErrorHandler.handle', () {
    test('maps timeouts to transient NetworkExceptions', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final result = DioErrorHandler.handle(_exception(type));
        expect(result, isA<NetworkException>());
        expect(result.isTransient, isTrue);
      }
    });

    test('maps connection errors to transient failures', () {
      final result = DioErrorHandler.handle(
        _exception(DioExceptionType.connectionError),
      );
      expect(result.message, contains('Cannot reach server'));
      expect(result.isTransient, isTrue);
    });

    test('maps bad certificates to non-transient failures', () {
      final result = DioErrorHandler.handle(
        _exception(DioExceptionType.badCertificate),
      );
      expect(result.message, contains('SSL certificate'));
      expect(result.isTransient, isFalse);
    });

    test('maps cancellations to non-transient failures', () {
      final result = DioErrorHandler.handle(_exception(DioExceptionType.cancel));
      expect(result.message, contains('cancelled'));
      expect(result.isTransient, isFalse);
    });

    test('maps unknown errors as transient with the raw message', () {
      final result = DioErrorHandler.handle(_exception(DioExceptionType.unknown));
      expect(result.message, contains('boom'));
      expect(result.isTransient, isTrue);
    });

    test('bad response surfaces server message and status code', () {
      final result = DioErrorHandler.handle(
        _exception(
          DioExceptionType.badResponse,
          status: 422,
          data: {'message': 'Invalid consultation'},
        ),
      );
      expect(result.message, contains('422'));
      expect(result.message, contains('Invalid consultation'));
    });

    test('bad response falls back to a generic message when data is empty',
        () {
      final result = DioErrorHandler.handle(
        _exception(DioExceptionType.badResponse, status: 500),
      );
      expect(result.message, contains('500'));
    });

    test('prepends the context when provided', () {
      final result = DioErrorHandler.handle(
        _exception(DioExceptionType.connectionTimeout),
        context: 'sync',
      );
      expect(result.message, startsWith('[sync] '));
    });
  });
}
