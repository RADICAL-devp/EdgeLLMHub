import 'package:flutter/widgets.dart';
import '../../features/note_assist/data/local/local_database.dart';

class DatabaseService with WidgetsBindingObserver {
  final LocalDatabase db;

  DatabaseService(this.db) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      db.close();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    db.close();
  }
}
