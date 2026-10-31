import 'dart:async';

/// A small, testable debouncer.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
