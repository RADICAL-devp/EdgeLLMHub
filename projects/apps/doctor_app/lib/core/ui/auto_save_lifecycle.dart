import 'package:flutter/material.dart';

/// Saves the open note when the app is backgrounded or the screen is locked.
///
/// Pages opt in by mixing this in and implementing [onAutoSaveRequested].
mixin AutoSaveOnPause<T extends StatefulWidget> on State<T> {
  Future<void> onAutoSaveRequested();

  late final AppLifecycleListener _lifecycleListener = AppLifecycleListener(
    onPause: () => onAutoSaveRequested(),
    onInactive: () => onAutoSaveRequested(),
    onDetach: () => onAutoSaveRequested(),
  );

  @override
  void initState() {
    super.initState();
    // Force creation of the listener, which registers with the engine.
    _lifecycleListener;
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }
}
