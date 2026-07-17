import 'dart:developer' as developer;

import 'package:doctor_app/core/exceptions/app_exceptions.dart';

/// Circuit breaker for external service calls.
///
/// States:
///   - **Closed**: Normal operation, requests pass through.
///   - **Open**: After [failureThreshold] consecutive failures, all calls
///     fail fast with [CircuitBreakerOpenException] until cooldown elapses.
///   - **Half-open**: After cooldown, one probe request is allowed through.
///     If it succeeds, the breaker closes. If it fails, it re-opens.
class CircuitBreaker {
  final int failureThreshold;
  final Duration cooldownDuration;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  _CircuitState _state = _CircuitState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.cooldownDuration = const Duration(minutes: 1),
  });

  /// Current state of the circuit breaker.
  String get state => _state.name;

  /// Whether the circuit is currently allowing requests.
  bool get isAllowing =>
      _state == _CircuitState.closed || _state == _CircuitState.halfOpen;

  /// Execute [action] through the circuit breaker.
  ///
  /// Throws [CircuitBreakerOpenException] if the breaker is open.
  Future<T> call<T>(Future<T> Function() action) async {
    // Check if we should transition from open → half-open
    if (_state == _CircuitState.open) {
      if (_cooldownElapsed()) {
        _state = _CircuitState.halfOpen;
        developer.log(
          'Circuit breaker transitioning to half-open (probe allowed)',
          name: 'CircuitBreaker',
        );
      } else {
        throw const CircuitBreakerOpenException();
      }
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// Record a successful call.
  void _onSuccess() {
    if (_state == _CircuitState.halfOpen) {
      developer.log(
        'Circuit breaker closing (probe succeeded)',
        name: 'CircuitBreaker',
      );
    }
    _consecutiveFailures = 0;
    _state = _CircuitState.closed;
    _openedAt = null;
  }

  /// Record a failed call.
  void _onFailure() {
    _consecutiveFailures++;

    if (_consecutiveFailures >= failureThreshold) {
      _state = _CircuitState.open;
      _openedAt = DateTime.now();
      developer.log(
        'Circuit breaker OPENED after $_consecutiveFailures consecutive failures. '
        'Cooldown: ${cooldownDuration.inSeconds}s',
        name: 'CircuitBreaker',
      );
    }
  }

  bool _cooldownElapsed() {
    if (_openedAt == null) return true;
    return DateTime.now().difference(_openedAt!) >= cooldownDuration;
  }

  /// Manually reset the circuit breaker to closed state.
  void reset() {
    _consecutiveFailures = 0;
    _state = _CircuitState.closed;
    _openedAt = null;
  }
}

enum _CircuitState { closed, open, halfOpen }
