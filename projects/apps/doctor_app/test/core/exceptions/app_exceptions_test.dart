import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

void main() {
  group('AppException', () {
    test('toString includes runtime type and message', () {
      const e = AppException('test error');
      expect(e.toString(), contains('AppException'));
      expect(e.toString(), contains('test error'));
    });

    test('stores cause', () {
      final cause = Exception('root cause');
      final e = AppException('wrapper', cause: cause);
      expect(e.cause, equals(cause));
    });
  });

  group('LlmException', () {
    test('extends AppException', () {
      const e = LlmException('llm failed');
      expect(e, isA<AppException>());
    });

    test('stores provider', () {
      const e = LlmException('fail', provider: LlmProvider.mlc);
      expect(e.provider, LlmProvider.mlc);
    });
  });

  group('LlmInitializationException', () {
    test('extends LlmException', () {
      const e = LlmInitializationException('init failed');
      expect(e, isA<LlmException>());
      expect(e, isA<AppException>());
    });
  });

  group('NetworkException', () {
    test('extends AppException', () {
      const e = NetworkException('network fail');
      expect(e, isA<AppException>());
    });

    test('defaults to non-transient', () {
      const e = NetworkException('fail');
      expect(e.isTransient, isFalse);
    });

    test('stores status code', () {
      const e = NetworkException('fail', statusCode: 503, isTransient: true);
      expect(e.statusCode, 503);
      expect(e.isTransient, isTrue);
    });
  });

  group('CircuitBreakerOpenException', () {
    test('extends NetworkException', () {
      const e = CircuitBreakerOpenException();
      expect(e, isA<NetworkException>());
      expect(e.isTransient, isTrue);
    });
  });

  group('SpeechException', () {
    test('extends AppException', () {
      const e = SpeechException('speech fail');
      expect(e, isA<AppException>());
    });
  });

  group('SpeechUnavailableException', () {
    test('extends SpeechException', () {
      const e = SpeechUnavailableException();
      expect(e, isA<SpeechException>());
    });
  });

  group('DatabaseException', () {
    test('extends AppException', () {
      const e = DatabaseException('db fail');
      expect(e, isA<AppException>());
    });
  });

  group('DatabaseMigrationException', () {
    test('extends DatabaseException', () {
      const e = DatabaseMigrationException(fromVersion: 1, toVersion: 2);
      expect(e, isA<DatabaseException>());
      expect(e.message, contains('v1'));
      expect(e.message, contains('v2'));
    });
  });

  group('ValidationException', () {
    test('extends AppException', () {
      const e = ValidationException(
        'too long',
        reason: ValidationFailureReason.tooLong,
      );
      expect(e, isA<AppException>());
      expect(e.reason, ValidationFailureReason.tooLong);
    });
  });

  group('UnsupportedPlatformException', () {
    test('extends AppException', () {
      const e = UnsupportedPlatformException('not supported');
      expect(e, isA<AppException>());
    });
  });

  group('ComplianceException', () {
    test('extends AppException', () {
      const e = ComplianceException('PHI blocked');
      expect(e, isA<AppException>());
    });
  });
}
