import 'dart:io';

import 'package:doctor_app/features/note_assist/domain/services/diagnostics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory(
      '${Directory.systemTemp.path}/diagnostics_exporter_'
      '${DateTime.now().microsecondsSinceEpoch}',
    )..createSync();
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('exportLog writes contents to a timestamped log file', () async {
    final exporter = DiagnosticsExporter(
      documentsDirectory: () async => dir,
    );

    final path = await exporter.exportLog(
      'Doctor App Diagnostics Log\nGenerated: 2026-01-01T00:00:00Z',
    );

    expect(path, startsWith(dir.path));
    expect(path, endsWith('.log'));
    expect(path, contains('diagnostics-'));
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('Doctor App Diagnostics Log'));
    expect(file.readAsStringSync(), contains('Generated:'));
  });

  test('exportLog creates uniquely named files on consecutive calls',
      () async {
    final exporter = DiagnosticsExporter(
      documentsDirectory: () async => dir,
    );

    final first = await exporter.exportLog('first');
    final second = await exporter.exportLog('second');

    expect(first, isNot(second));
    expect(File(first).readAsStringSync(), 'first');
    expect(File(second).readAsStringSync(), 'second');
  });
}