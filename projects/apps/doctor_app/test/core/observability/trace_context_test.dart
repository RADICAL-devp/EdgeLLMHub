import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/observability.dart';

void main() {
  group('newTraceId', () {
    test('returns a non-empty hex string of the requested length', () {
      final id = newTraceId();
      expect(id.length, 6);
      expect(RegExp(r'^[0-9A-F]{6}$').hasMatch(id), isTrue);
    });

    test('generates distinct ids across calls', () {
      final ids = {for (var i = 0; i < 50; i++) newTraceId()};
      expect(ids.length, greaterThan(1));
    });
  });

  group('TraceContext', () {
    test('current is null outside a trace', () {
      expect(TraceContext.current, isNull);
    });

    test('propagates the id into the traced zone', () {
      String? seen;
      final result = TraceContext.trace('ABC123', () {
        seen = TraceContext.current;
        return 'done';
      });
      expect(result, 'done');
      expect(seen, 'ABC123');
      expect(TraceContext.current, isNull);
    });

    test('remains visible across await boundaries', () async {
      String? inside;
      await TraceContext.trace('XYZ789', () async {
        await Future<void>.delayed(Duration.zero);
        inside = TraceContext.current;
      });
      expect(inside, 'XYZ789');
    });

    test('nesting keeps the innermost id visible', () {
      String? outer;
      String? inner;
      TraceContext.trace('OUTER', () {
        outer = TraceContext.current;
        TraceContext.trace('INNER', () {
          inner = TraceContext.current;
        });
      });
      expect(outer, 'OUTER');
      expect(inner, 'INNER');
    });
  });

  group('JsonLogger + TraceContext', () {
    test('log lines pick up the zone trace as correlationId', () async {
      final lines = <String>[];
      final logger = JsonLogger(name: 'test', sink: lines.add);

      await TraceContext.trace('F00D1E', () async {
        logger.info('hello');
      });

      expect(lines, hasLength(1));
      expect(lines.single, contains('"correlationId":"F00D1E"'));
      expect(lines.single, contains('"message":"hello"'));
    });

    test('explicit per-call correlationId overrides the zone trace', () async {
      final lines = <String>[];
      final logger = JsonLogger(name: 'test', sink: lines.add);

      TraceContext.trace('F00D1E', () {
        logger.info('hello', correlationId: 'MANUAL');
      });

      expect(lines.single, contains('"correlationId":"MANUAL"'));
      expect(lines.single, isNot(contains('F00D1E')));
    });
  });
}
