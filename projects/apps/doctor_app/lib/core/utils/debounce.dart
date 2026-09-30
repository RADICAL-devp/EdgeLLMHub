import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Run [action] immediately, dropping any pending debounced call.
  /// Used to flush the latest value when a stream ends.
  void flush(void Function() action) {
    _timer?.cancel();
    action();
  }

  void dispose() {
    _timer?.cancel();
  }
}

extension DebounceExtension on Stream<String> {
  Stream<String> debounce(Duration duration) {
    final debouncer = Debouncer(delay: duration);
    final controller = StreamController<String>();

    final subscription = listen(
      (data) {
        debouncer.run(() {
          controller.add(data);
        });
      },
      onError: controller.addError,
      onDone: controller.close,
    );

    controller.onCancel = () {
      debouncer.dispose();
      subscription.cancel();
    };

    return controller.stream;
  }
}
