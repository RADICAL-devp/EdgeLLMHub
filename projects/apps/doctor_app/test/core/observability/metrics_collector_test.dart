import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_app/core/observability/metrics_collector.dart';

void main() {
  group('MetricsCollector', () {
    late MetricsCollector collector;

    setUp(() {
      collector = MetricsCollector.instance;
      // Note: MetricsCollector is a singleton, so state persists between tests
      // In production, you'd want a way to reset for testing
    });

    group('Counters', () {
      test('increments counter', () {
        collector.incrementCounter('test.counter');
        collector.incrementCounter('test.counter', value: 5);

        expect(collector.getCounter('test.counter'), 6);
      });

      test('handles labels', () {
        collector.incrementCounter('test.labeled', labels: {'env': 'test'});
        collector.incrementCounter('test.labeled', labels: {'env': 'prod'});

        expect(collector.getCounter('test.labeled', labels: {'env': 'test'}), 1);
        expect(collector.getCounter('test.labeled', labels: {'env': 'prod'}), 1);
      });
    });

    group('Gauges', () {
      test('sets gauge value', () {
        collector.setGauge('test.gauge', 42.5);
        expect(collector.getGauge('test.gauge'), 42.5);

        collector.setGauge('test.gauge', 100.0);
        expect(collector.getGauge('test.gauge'), 100.0);
      });

      test('handles labels', () {
        collector.setGauge('test.labeled_gauge', 10.0, labels: {'region': 'us'});
        collector.setGauge('test.labeled_gauge', 20.0, labels: {'region': 'eu'});

        expect(collector.getGauge('test.labeled_gauge', labels: {'region': 'us'}), 10.0);
        expect(collector.getGauge('test.labeled_gauge', labels: {'region': 'eu'}), 20.0);
      });
    });

    group('Histograms', () {
      test('records values', () {
        collector.recordHistogram('test.histogram', 100.0);
        collector.recordHistogram('test.histogram', 200.0);
        collector.recordHistogram('test.histogram', 300.0);

        final stats = collector.getHistogramStats('test.histogram');
        expect(stats, isNotNull);
        expect(stats!.count, 3);
        expect(stats.min, 100.0);
        expect(stats.max, 300.0);
        expect(stats.mean, 200.0);
      });

      test('calculates percentiles', () {
        for (var i = 1; i <= 100; i++) {
          collector.recordHistogram('test.percentiles', i.toDouble());
        }

        final stats = collector.getHistogramStats('test.percentiles');
        expect(stats, isNotNull);
        expect(stats!.count, 100);
        expect(stats.p50, closeTo(50, 2));
        expect(stats.p95, closeTo(95, 2));
        expect(stats.p99, closeTo(99, 2));
      });

      test('returns null for empty histogram', () {
        final stats = collector.getHistogramStats('test.empty');
        expect(stats, isNull);
      });
    });

    group('Timers', () {
      test('records timer duration', () {
        final handle = collector.startTimer('test.timer');
        handle.stop();

        final stats = collector.getHistogramStats('test.timer');
        expect(stats, isNotNull);
        expect(stats!.count, 1);
        expect(stats.min, greaterThanOrEqualTo(0));
      });

      test('records multiple timer durations', () {
        for (var i = 0; i < 10; i++) {
          final handle = collector.startTimer('test.multi_timer');
          // Simulate some work
          handle.stop();
        }

        final stats = collector.getHistogramStats('test.multi_timer');
        expect(stats, isNotNull);
        expect(stats!.count, 10);
      });
    });

    group('Extension methods', () {
      test('recordLlmInference records duration and tokens', () {
        collector.recordLlmInference(
          1500,
          model: 'SmolLM-360M',
          tier: 'local',
          tokens: 256,
          success: true,
        );

        final durationStats = collector.getHistogramStats('llm.inference.duration_ms');
        expect(durationStats, isNotNull);
        expect(durationStats!.count, 1);
        expect(durationStats.mean, 1500);

        final tokenStats = collector.getHistogramStats('llm.inference.tokens');
        expect(tokenStats, isNotNull);
        expect(tokenStats!.mean, 256);
      });

      test('recordLlmInference records errors on failure', () {
        collector.recordLlmInference(
          1000,
          model: 'SmolLM-360M',
          tier: 'local',
          success: false,
        );

        expect(collector.getCounter('llm.inference.errors'), 1);
      });

      test('recordSpeechRecognition records metrics', () {
        collector.recordSpeechRecognition(500, locale: 'en-US', success: true);
        collector.recordSpeechRecognition(300, locale: 'en-US', success: false);

        final durationStats = collector.getHistogramStats('speech.recognition.duration_ms');
        expect(durationStats, isNotNull);
        expect(durationStats!.count, 2);

        expect(collector.getCounter('speech.recognition.errors'), 1);
      });

      test('recordSync records metrics', () {
        collector.recordSync(2000, success: true, conflicts: 2);
        collector.recordSync(1500, success: false);

        final durationStats = collector.getHistogramStats('sync.duration_ms');
        expect(durationStats, isNotNull);
        expect(durationStats!.count, 2);

        expect(collector.getCounter('sync.errors'), 1);
        expect(collector.getCounter('sync.conflicts'), 2);
      });

      test('recordDbQuery records metrics', () {
        collector.recordDbQuery(50, operation: 'select', success: true);
        collector.recordDbQuery(200, operation: 'insert', success: false);

        final durationStats = collector.getHistogramStats('db.query.duration_ms');
        expect(durationStats, isNotNull);
        expect(durationStats!.count, 2);

        expect(collector.getCounter('db.errors'), 1);
      });

      test('recordNetworkRequest records metrics', () {
        collector.recordNetworkRequest(100, endpoint: '/api/notes', statusCode: 200, success: true);
        collector.recordNetworkRequest(5000, endpoint: '/api/notes', statusCode: 500, success: false);

        final durationStats = collector.getHistogramStats('network.request.duration_ms');
        expect(durationStats, isNotNull);
        expect(durationStats!.count, 2);

        expect(collector.getCounter('network.request.errors'), 1);
      });
    });
  });
}