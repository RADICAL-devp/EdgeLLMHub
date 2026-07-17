import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/network/circuit_breaker.dart';
import 'package:doctor_app/core/exceptions/app_exceptions.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        failureThreshold: 3,
        cooldownDuration: const Duration(milliseconds: 100),
      );
    });

    test('starts in closed state', () {
      expect(breaker.state, 'closed');
      expect(breaker.isAllowing, isTrue);
    });

    test('allows calls when closed', () async {
      final result = await breaker.call(() async => 'success');
      expect(result, 'success');
    });

    test('stays closed on isolated failures', () async {
      // Fail once, then succeed
      try {
        await breaker.call(() async => throw Exception('fail'));
      } catch (_) {}

      final result = await breaker.call(() async => 'ok');
      expect(result, 'ok');
      expect(breaker.state, 'closed');
    });

    test('opens after threshold consecutive failures', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail $i'));
        } catch (_) {}
      }

      expect(breaker.state, 'open');
      expect(breaker.isAllowing, isFalse);
    });

    test('throws CircuitBreakerOpenException when open', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(
        () async => await breaker.call(() async => 'should not run'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('transitions to half-open after cooldown', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail'));
        } catch (_) {}
      }

      // Wait for cooldown
      await Future.delayed(const Duration(milliseconds: 150));

      // Next call should be allowed (half-open probe)
      final result = await breaker.call(() async => 'probe success');
      expect(result, 'probe success');
      expect(breaker.state, 'closed');
    });

    test('re-opens from half-open if probe fails', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail'));
        } catch (_) {}
      }

      // Wait for cooldown
      await Future.delayed(const Duration(milliseconds: 150));

      // Probe fails → re-open
      try {
        await breaker.call(() async => throw Exception('probe fail'));
      } catch (_) {}

      expect(breaker.state, 'open');
    });

    test('reset returns to closed state', () async {
      // Trip the breaker
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.call(() async => throw Exception('fail'));
        } catch (_) {}
      }
      expect(breaker.state, 'open');

      breaker.reset();
      expect(breaker.state, 'closed');
      expect(breaker.isAllowing, isTrue);
    });
  });
}
