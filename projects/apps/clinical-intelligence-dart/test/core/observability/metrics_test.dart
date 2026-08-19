import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/observability/metric_registry.dart';
import 'package:clinical_intelligence_dart/core/observability/metrics_middleware.dart';
import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// Unit tests for the Prometheus-style metric registry and the
/// [InstrumentedLlmPort] wrapper.
void main() {
  group('MetricRegistry counters', () {
    test('increments the same series and differentiates label sets', () {
      final registry = MetricRegistry();
      final counter = registry.counter(
        'http_requests_total',
        labelNames: const ['method', 'path', 'status'],
      );
      _increment(
        counter,
        const {
          'method': 'GET',
          'path': '/health',
          'status': '200',
        },
        times: 2,
      );
      _increment(counter, const {
        'method': 'POST',
        'path': '/process',
        'status': '500',
      });

      expect(
        _counterValue(counter, const {
          'method': 'GET',
          'path': '/health',
          'status': '200',
        }),
        2,
      );
      expect(
        _counterValue(counter, const {
          'method': 'POST',
          'path': '/process',
          'status': '500',
        }),
        1,
      );
      expect(
        _counterValue(counter, const {
          'method': 'GET',
          'path': '/other',
          'status': '200',
        }),
        0,
      );
    });

    test('counter returns the same instance for a repeated name', () {
      final registry = MetricRegistry();
      final first = registry.counter('http_requests_total');
      final second = registry.counter('http_requests_total');
      expect(first, same(second));
    });
  });

  group('MetricRegistry histograms', () {
    test('observations land in the correct cumulative buckets', () {
      final registry = MetricRegistry();
      final histogram = registry.histogram('http_request_duration_seconds');
      _observeAll(histogram, const [0.05, 0.2, 2.0]);

      expect(_histogramCount(histogram, const {}), 3);
      expect(_bucketCount(histogram, const {}, 0.005), 0);
      expect(_bucketCount(histogram, const {}, 0.05), 1);
      expect(_bucketCount(histogram, const {}, 0.25), 2);
      expect(_bucketCount(histogram, const {}, 2.5), 3);
    });

    test('supports label sets with independent buckets', () {
      final registry = MetricRegistry();
      final histogram = registry.histogram(
        'llm_inference_duration_seconds',
        labelNames: const ['method'],
      );
      _observeAll(
        histogram,
        const [
          1.5,
          20,
        ],
        labels: const {'method': 'a'},
      );
      histogram.observe(0.3, labels: {'method': 'b'});

      // 20 exceeds the largest bucket (10) → falls into the +Inf bucket.
      expect(_histogramCount(histogram, const {'method': 'a'}), 2);
      expect(
        _bucketCount(histogram, const {'method': 'a'}, 10),
        1,
        reason: 'only the 1.5s observation falls within <= 10s',
      );
      expect(_histogramCount(histogram, const {'method': 'b'}), 1);
    });

    test('custom buckets are honored', () {
      final registry = MetricRegistry();
      final histogram = registry.histogram(
        'latency',
        buckets: const [0.1, 1, 10],
      );
      _observeAll(histogram, const [0.05, 5]);

      expect(_bucketCount(histogram, const {}, 0.1), 1);
      expect(_bucketCount(histogram, const {}, 1), 1);
      expect(_bucketCount(histogram, const {}, 10), 2);
    });
  });

  group('MetricRegistry gauges', () {
    test('increment, decrement and set', () {
      final registry = MetricRegistry();
      final gauge = registry.gauge('active_consultations');

      _incrementGauge(gauge, const {}, times: 2);
      _decrementGauge(gauge, const {});
      expect(_gaugeValue(gauge, const {}), 1);

      gauge.set(7);
      expect(_gaugeValue(gauge, const {}), 7);

      final labelled = registry.gauge('jobs', labelNames: const ['queue']);
      _incrementGauge(labelled, const {'queue': 'summary'}, times: 2);
      _incrementGauge(labelled, const {'queue': 'note'});
      expect(_gaugeValue(labelled, const {'queue': 'summary'}), 2);
      expect(_gaugeValue(labelled, const {'queue': 'note'}), 1);
    });
  });

  group('MetricRegistry text export', () {
    late MetricRegistry registry;

    setUp(() {
      registry = MetricRegistry();
      _seedRegistry(registry);
    });

    test('emits HELP and TYPE lines', () {
      final text = registry.exportText();
      expect(
        text,
        allOf(
          contains('# HELP http_requests_total Total number of HTTP requests.'),
          contains('# TYPE http_requests_total counter'),
          contains('# TYPE http_request_duration_seconds histogram'),
          contains('# TYPE active_consultations gauge'),
        ),
      );
    });

    test('serializes counter lines with label values', () {
      final text = registry.exportText();
      expect(
        text,
        contains('http_requests_total{method="GET",path="/health",status="200"} 1'),
      );
    });

    test('serializes histogram bucket, sum and count lines', () {
      final text = registry.exportText();
      expect(
        text,
        allOf(
          contains('http_request_duration_seconds_bucket{le="0.005"} 0'),
          contains('http_request_duration_seconds_bucket{le="0.05"} 1'),
          contains('http_request_duration_seconds_bucket{le="0.25"} 2'),
          contains('http_request_duration_seconds_bucket{le="+Inf"} 2'),
          contains('http_request_duration_seconds_sum 0.25'),
          contains('http_request_duration_seconds_count 2'),
        ),
      );
    });

    test('serializes gauge values', () {
      final text = registry.exportText();
      expect(text, contains('active_consultations 3'));
    });

    test('escapes quotes, backslashes and newlines in label values', () {
      final text = registry.exportText();
      expect(text, contains(r'labels_escaped{v="a\"b\\c\nd"} 1'));
    });

    test('sorts metric families and series deterministically', () {
      final before = registry.exportText();
      registry.counter('zzz_late').increment();
      final after = registry.exportText();
      expect(
        after.indexOf('zzz_late'),
        greaterThan(after.indexOf('active_consultations')),
      );
      expect(before, isNot(contains('zzz_late')));
    });
  });

  group('InstrumentedLlmPort', () {
    test('records duration histogram and forwards results', () async {
      final registry = MetricRegistry();
      final inner = _FakeLlmPort(delay: const Duration(milliseconds: 5));
      final port = InstrumentedLlmPort(inner, registry);

      final result = await port.generateStructuredSummary('transcript');

      expect(result, isNotNull);
      expect(inner.calls, 1);
      expect(
        _histogramCount(
          registry.histogram('llm_inference_duration_seconds'),
          const {'method': 'generateStructuredSummary'},
        ),
        1,
      );
    });

    test('records error counter when the inner port throws', () async {
      final registry = MetricRegistry();
      final port = InstrumentedLlmPort(
        _FakeLlmPort(throwOnProcess: true),
        registry,
      );

      await expectLater(
        port.processText('x', ProcessingMode.vocabAssist),
        throwsA(isA<StateError>()),
      );

      final errors = registry.counter('llm_inference_errors_total');
      final histogram = registry.histogram('llm_inference_duration_seconds');
      expect(errors.valueFor({'method': 'processText'}), 1);
      expect(_histogramCount(histogram, const {'method': 'processText'}), 0);
    });

    test('every LlmPort method is timed under its own label', () async {
      final registry = MetricRegistry();
      final port = InstrumentedLlmPort(_FakeLlmPort(), registry);

      await port.processText('x', ProcessingMode.summarize);
      await port.generateExecutiveSummary('t');
      await port.generateDoctorNote('t');

      final histogram = registry.histogram('llm_inference_duration_seconds');
      expect(_histogramCount(histogram, const {'method': 'processText'}), 1);
      expect(
        _histogramCount(histogram, const {'method': 'generateExecutiveSummary'}),
        1,
      );
      expect(_histogramCount(histogram, const {'method': 'generateDoctorNote'}), 1);
      expect(
        _histogramCount(histogram, const {'method': 'generateContextEnrichedSummary'}),
        0,
      );
    });
  });
}

/// Seeds the well-known metrics used by the text-export tests.
void _seedRegistry(MetricRegistry registry) {
  registry
    ..counter(
      'http_requests_total',
      help: 'Total number of HTTP requests.',
      labelNames: const ['method', 'path', 'status'],
    ).increment(labels: {
      'method': 'GET',
      'path': '/health',
      'status': '200',
    },)
    ..histogram(
      'http_request_duration_seconds',
      help: 'HTTP request latency in seconds.',
    ).observe(0.05)    ..histogram('http_request_duration_seconds').observe(0.2)
    ..gauge(
      'active_consultations',
      help: 'Active consultation summaries.',
    ).set(3)
    ..counter('labels_escaped', labelNames: const ['v']).increment(
      labels: {
        'v': 'a"b\\c\nd',
      },
    );
}

void _increment(
  Counter counter,
  Map<String, String> labels, {
  int times = 1,
}) {
  for (var i = 0; i < times; i++) {
    counter.increment(labels: labels);
  }
}

void _incrementGauge(
  Gauge gauge,
  Map<String, String> labels, {
  int times = 1,
}) {
  for (var i = 0; i < times; i++) {
    gauge.increment(labels: labels);
  }
}

void _decrementGauge(Gauge gauge, Map<String, String> labels) {
  gauge.decrement(labels: labels);
}

void _observeAll(
  Histogram histogram,
  List<num> values, {
  Map<String, String> labels = const <String, String>{},
}) {
  for (final value in values) {
    histogram.observe(value, labels: labels);
  }
}

num _counterValue(Counter counter, Map<String, String> labels) =>
    counter.valueFor(labels);

int _histogramCount(Histogram histogram, Map<String, String> labels) =>
    histogram.countFor(labels);

int _bucketCount(
  Histogram histogram,
  Map<String, String> labels,
  double upperBound,
) =>
    histogram.bucketCountFor(labels, upperBound);

num _gaugeValue(Gauge gauge, Map<String, String> labels) =>
    gauge.valueFor(labels);

class _FakeLlmPort implements LlmPort {
  _FakeLlmPort({this.delay = Duration.zero, this.throwOnProcess = false});

  final Duration delay;
  final bool throwOnProcess;
  int calls = 0;

  @override
  Future<String> processText(String input, ProcessingMode mode) async {
    calls += 1;
    await Future<void>.delayed(delay);
    if (throwOnProcess) {
      throw StateError('boom');
    }
    return 'processed';
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(
    String transcriptText,
  ) async {
    calls += 1;
    await Future<void>.delayed(delay);
    return StructuredSummary(
      complaint: 'c',
      pastHistory: 'p',
      vitals: 'v',
      physicalExamination: 'e',
      investigationOrdered: 'i',
      diagnosis: 'd',
      advice: 'a',
    );
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) async {
    calls += 1;
    return generateStructuredSummary(transcriptText);
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) async {
    calls += 1;
    return 'exec';
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) async {
    calls += 1;
    return 'note';
  }

  // ============ FIELD-LEVEL GENERATION (STUB) ============

  @override
  Future<String> generateField(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) async {
    calls += 1;
    return '$fieldName';
  }

  @override
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) async* {
    calls += 1;
    yield '$fieldName';
  }

  @override
  Future<Map<String, String>> generateFields(
    List<String> fieldNames,
    String transcriptText, {
    PatientContext? patientContext,
  }) async {
    calls += 1;
    return {for (final f in fieldNames) f: f};
  }
}
