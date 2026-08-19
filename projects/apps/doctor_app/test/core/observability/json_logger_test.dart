import 'dart:convert';

import 'package:doctor_app/core/observability/json_logger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [JsonLogger]: JSON validity, level filtering and correlation id
/// propagation.
void main() {
  group('JsonLogger', () {
    late List<String> lines;
    late JsonLogger logger;

    setUp(() {
      lines = <String>[];
      logger = JsonLogger(sink: lines.add);
    });

    Map<String, dynamic> lastRecord() =>
        jsonDecode(lines.last) as Map<String, dynamic>;

    group('JSON output', () {
      test('emits valid JSON with level, message and timestamp', () {
        logger.info('hello world');

        expect(lines, hasLength(1));
        final record = lastRecord();
        expect(record['level'], 'info');
        expect(record['message'], 'hello world');
        expect(record['logger'], 'app');
        expect(DateTime.tryParse(record['timestamp'] as String), isNotNull);
      });

      test('every level emits a valid JSON record', () {
        logger.debug('d');
        logger.info('i');
        logger.warn('w');
        logger.error('e');

        expect(lines, hasLength(4));
        for (final line in lines) {
          expect(() => jsonDecode(line), returnsNormally);
        }
        expect(lastRecord()['level'], 'error');
      });

      test('includes error and stack trace on warn/error', () {
        final stackTrace = StackTrace.current;
        logger.warn('bad smell', error: StateError('nope'), stackTrace: stackTrace);

        final record = lastRecord();
        expect(record['error'], contains('nope'));
        expect(record['stackTrace'], isNotEmpty);
      });

      test('includes ambient and per-call context, with per-call winning', () {
        final contextual = JsonLogger(
          sink: lines.add,
          context: {'env': 'test', 'shared': 'ambient'},
        );
        contextual.info(
          'ctx',
          context: {'shared': 'call', 'extra': 1},
        );

        final record = lastRecord();
        expect(record['env'], 'test');
        expect(record['shared'], 'call');
        expect(record['extra'], 1);
      });

      test('sanitizes non-JSON context values instead of throwing', () {
        logger.info('sanitize', context: {
          'object': _NotJsonSerializable(),
          'nested': {'list': [_NotJsonSerializable()]},
        });

        final record = lastRecord();
        expect(record['object'], isA<String>());
        final nested = record['nested'] as Map<String, dynamic>;
        expect((nested['list'] as List<dynamic>).first, isA<String>());
      });
    });

    group('level filtering', () {
      test('filters out levels below minLevel', () {
        final filtered = JsonLogger(sink: lines.add, minLevel: LogLevel.warn);

        filtered.debug('d');
        filtered.info('i');
        filtered.warn('w');
        filtered.error('e');

        expect(lines, hasLength(2));
        expect(jsonDecode(lines[0])['level'], 'warn');
        expect(jsonDecode(lines[1])['level'], 'error');
      });

      test('debug level emits everything', () {
        final verbose = JsonLogger(sink: lines.add, minLevel: LogLevel.debug);
        verbose.debug('d');
        verbose.info('i');
        expect(lines, hasLength(2));
      });
    });

    group('correlation id propagation', () {
      test('is included in every line once set', () {
        logger.setCorrelationId('corr-123');
        logger.info('a');
        logger.warn('b');

        expect(lines, hasLength(2));
        for (final line in lines) {
          expect(jsonDecode(line)['correlationId'], 'corr-123');
        }
      });

      test('is omitted when not set', () {
        logger.info('no corr');
        expect(lastRecord().containsKey('correlationId'), isFalse);
      });

      test('clearCorrelationId stops propagation', () {
        logger.setCorrelationId('corr-123');
        logger.info('a');
        logger.clearCorrelationId();
        logger.info('b');

        expect(lastRecord().containsKey('correlationId'), isFalse);
      });

      test('per-call correlation id overrides the logger-level one', () {
        logger.setCorrelationId('logger-level');
        logger.info('override', correlationId: 'per-call');
        expect(lastRecord()['correlationId'], 'per-call');
      });

      test('is propagated through error records', () {
        logger.setCorrelationId('corr-err');
        logger.error('boom', error: Exception('x'));
        expect(lastRecord()['correlationId'], 'corr-err');
      });
    });
  });
}

class _NotJsonSerializable {
  @override
  String toString() => 'not-json-safe';
}
