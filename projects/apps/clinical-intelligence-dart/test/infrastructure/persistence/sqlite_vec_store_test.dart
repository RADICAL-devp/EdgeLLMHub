import 'dart:io';

import 'package:clinical_intelligence_dart/infrastructure/persistence/sqlite_vec_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SqliteVecStore vec extension resolution', () {
    test('resolves the bundled vec0 extension when present', () {
      final resolved = SqliteVecStore.resolveVecExtensionPath();

      if (resolved == null || !File(resolved).existsSync()) {
        markTestSkipped(
          'vec0 extension not built for this host; '
          'run scripts/build_sqlite_vec.sh',
        );
        return;
      }

      expect(
        p.basename(resolved),
        Platform.isMacOS ? 'vec0.dylib' : 'vec0.so',
      );
      expect(File(resolved).lengthSync(), greaterThan(0));
    });
  });
}
