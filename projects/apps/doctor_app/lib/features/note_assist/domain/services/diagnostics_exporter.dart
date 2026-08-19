import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DiagnosticsExporter {
  DiagnosticsExporter({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  /// Writes [contents] to a timestamped diagnostics log file and returns the
  /// absolute path of the created file.
  Future<String> exportLog(String contents) async {
    final dir = await _documentsDirectory();
    var file = File(
      '${dir.path}/diagnostics-'
      '${DateTime.now().microsecondsSinceEpoch}.log',
    );
    var suffix = 1;
    while (file.existsSync()) {
      file = File(
        '${dir.path}/diagnostics-'
        '${DateTime.now().microsecondsSinceEpoch}-$suffix.log',
      );
      suffix++;
    }
    await file.writeAsString(contents);
    return file.path;
  }
}