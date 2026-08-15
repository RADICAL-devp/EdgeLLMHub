import 'dart:async';
import 'dart:developer' as developer;

/// Metrics collector for structured application metrics.
///
/// Supports counters, gauges, histograms, and timers.
/// Emits metrics as structured JSON logs for ingestion by observability backends.
class MetricsCollector {
  MetricsCollector._();

  static final MetricsCollector _instance = MetricsCollector._();
  static MetricsCollector get instance => _instance;

  final Map<String, int> _counters = {};
  final Map<String, double> _gauges = {};
  final Map<String, List<double>> _histograms = {};
  final Map<String, List<int>> _timers = {};

  /// Increment a counter metric.
  void incrementCounter(String name, {int value = 1, Map<String, String>? labels}) {
    final key = _makeKey(name, labels);
    _counters[key] = (_counters[key] ?? 0) + value;
    _emitMetric('counter', name, _counters[key]!, labels);
  }

  /// Set a gauge metric to a specific value.
  void setGauge(String name, double value, {Map<String, String>? labels}) {
    final key = _makeKey(name, labels);
    _gauges[key] = value;
    _emitMetric('gauge', name, value, labels);
  }

  /// Record a histogram value.
  void recordHistogram(String name, double value, {Map<String, String>? labels}) {
    final key = _makeKey(name, labels);
    _histograms[key] = (_histograms[key] ?? [])..add(value);
    _emitMetric('histogram', name, value, labels);
  }

  /// Start a timer and return a stopwatch that records on stop.
  TimerHandle startTimer(String name, {Map<String, String>? labels}) {
    final sw = Stopwatch()..start();
    return TimerHandle(name, labels, sw, this);
  }

  /// Record a timer duration in milliseconds.
  void recordTimer(String name, int durationMs, {Map<String, String>? labels}) {
    final key = _makeKey(name, labels);
    _timers[key] = (_timers[key] ?? [])..add(durationMs);
    _emitMetric('timer', name, durationMs, labels);
  }

  /// Get current counter value.
  int getCounter(String name, {Map<String, String>? labels}) {
    return _counters[_makeKey(name, labels)] ?? 0;
  }

  /// Get current gauge value.
  double? getGauge(String name, {Map<String, String>? labels}) {
    return _gauges[_makeKey(name, labels)];
  }

  /// Get histogram statistics.
  HistogramStats? getHistogramStats(String name, {Map<String, String>? labels}) {
    final values = _histograms[_makeKey(name, labels)];
    if (values == null || values.isEmpty) return null;
    return HistogramStats.fromValues(values);
  }

  String _makeKey(String name, Map<String, String>? labels) {
    if (labels == null || labels.isEmpty) return name;
    final sortedLabels = labels.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final labelStr = sortedLabels.map((e) => '${e.key}=${e.value}').join(',');
    return '$name{$labelStr}';
  }

  void _emitMetric(String type, String name, Object value, Map<String, String>? labels) {
    final record = {
      'type': type,
      'name': name,
      'value': value,
      'labels': labels ?? {},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    developer.log(record.toString(), name: 'metrics');
  }
}

/// Handle for a timer that records duration when disposed.
class TimerHandle {
  final String name;
  final Map<String, String>? labels;
  final Stopwatch stopwatch;
  final MetricsCollector collector;
  bool _disposed = false;

  TimerHandle(this.name, this.labels, this.stopwatch, this.collector);

  void stop() {
    if (_disposed) return;
    stopwatch.stop();
    collector.recordTimer(name, stopwatch.elapsedMilliseconds, labels: labels);
    _disposed = true;
  }

  @override
  String toString() => 'TimerHandle($name, ${stopwatch.elapsedMilliseconds}ms)';
}

/// Statistics for a histogram.
class HistogramStats {
  final int count;
  final double min;
  final double max;
  final double mean;
  final double p50;
  final double p95;
  final double p99;

  HistogramStats({
    required this.count,
    required this.min,
    required this.max,
    required this.mean,
    required this.p50,
    required this.p95,
    required this.p99,
  });

  factory HistogramStats.fromValues(List<double> values) {
    final sorted = [...values]..sort();
    final count = sorted.length;
    final min = sorted.first;
    final max = sorted.last;
    final mean = sorted.reduce((a, b) => a + b) / count;

    double percentile(double p) {
      final idx = (p / 100 * (count - 1)).round();
      return sorted[idx];
    }

    return HistogramStats(
      count: count,
      min: min,
      max: max,
      mean: mean,
      p50: percentile(50),
      p95: percentile(95),
      p99: percentile(99),
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'min': min,
        'max': max,
        'mean': mean,
        'p50': p50,
        'p95': p95,
        'p99': p99,
      };
}

/// Predefined metric names for consistency.
class MetricNames {
  // LLM metrics
  static const llmInferenceDuration = 'llm.inference.duration_ms';
  static const llmInferenceTokens = 'llm.inference.tokens';
  static const llmInferenceErrors = 'llm.inference.errors';
  static const llmModelLoadDuration = 'llm.model.load.duration_ms';
  static const llmModelLoadErrors = 'llm.model.load.errors';
  static const llmFallbackTier = 'llm.fallback.tier';

  // Speech metrics
  static const speechRecognitionDuration = 'speech.recognition.duration_ms';
  static const speechRecognitionErrors = 'speech.recognition.errors';
  static const speechPartialResults = 'speech.recognition.partial_results';

  // Sync metrics
  static const syncDuration = 'sync.duration_ms';
  static const syncErrors = 'sync.errors';
  static const syncConflicts = 'sync.conflicts';
  static const syncQueueSize = 'sync.queue.size';

  // Database metrics
  static const dbQueryDuration = 'db.query.duration_ms';
  static const dbErrors = 'db.errors';
  static const dbSize = 'db.size_bytes';

  // Network metrics
  static const networkRequestDuration = 'network.request.duration_ms';
  static const networkRequestErrors = 'network.request.errors';
  static const networkRetryCount = 'network.retry.count';

  // App lifecycle
  static const appStartDuration = 'app.start.duration_ms';
  static const appCrashes = 'app.crashes';
  static const appMemoryUsage = 'app.memory_usage_bytes';
}

/// Convenience functions for common metrics.
extension MetricsExtension on MetricsCollector {
  void recordLlmInference(int durationMs, {String? model, String? tier, int? tokens, bool success = true}) {
    final labels = <String, String>{};
    if (model != null) labels['model'] = model;
    if (tier != null) labels['tier'] = tier;
    recordHistogram(MetricNames.llmInferenceDuration, durationMs.toDouble(), labels: labels);
    if (tokens != null) {
      recordHistogram(MetricNames.llmInferenceTokens, tokens.toDouble(), labels: labels);
    }
    if (!success) {
      incrementCounter(MetricNames.llmInferenceErrors, labels: labels);
    }
  }

  void recordSpeechRecognition(int durationMs, {String? locale, bool success = true}) {
    final labels = <String, String>{};
    if (locale != null) labels['locale'] = locale;
    recordHistogram(MetricNames.speechRecognitionDuration, durationMs.toDouble(), labels: labels);
    if (!success) {
      incrementCounter(MetricNames.speechRecognitionErrors, labels: labels);
    }
  }

  void recordSync(int durationMs, {bool success = true, int? conflicts}) {
    recordHistogram(MetricNames.syncDuration, durationMs.toDouble());
    if (!success) {
      incrementCounter(MetricNames.syncErrors);
    }
    if (conflicts != null && conflicts > 0) {
      incrementCounter(MetricNames.syncConflicts, value: conflicts);
    }
  }

  void recordDbQuery(int durationMs, {String? operation, bool success = true}) {
    final labels = <String, String>{};
    if (operation != null) labels['operation'] = operation;
    recordHistogram(MetricNames.dbQueryDuration, durationMs.toDouble(), labels: labels);
    if (!success) {
      incrementCounter(MetricNames.dbErrors, labels: labels);
    }
  }

  void recordNetworkRequest(int durationMs, {String? endpoint, int? statusCode, bool success = true}) {
    final labels = <String, String>{};
    if (endpoint != null) labels['endpoint'] = endpoint;
    if (statusCode != null) labels['status'] = statusCode.toString();
    recordHistogram(MetricNames.networkRequestDuration, durationMs.toDouble(), labels: labels);
    if (!success) {
      incrementCounter(MetricNames.networkRequestErrors, labels: labels);
    }
  }
}