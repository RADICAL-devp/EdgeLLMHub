/// Dependency-light Prometheus-style metric registry.
///
/// Provides counters, histograms and gauges with label support and
/// self-serialized Prometheus text format output (no external package).
/// Dart Frog handlers on a single isolate execute serially between awaits,
/// so no locking is required for the writes performed here.
library;

import 'package:meta/meta.dart';
class MetricRegistry {
  final Map<String, Counter> _counters = <String, Counter>{};
  final Map<String, Histogram> _histograms = <String, Histogram>{};
  final Map<String, Gauge> _gauges = <String, Gauge>{};

  /// Returns the existing counter named [name] or creates one.
  Counter counter(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
  }) {
    return _counters.putIfAbsent(
      name,
      () => Counter(name, help: help, labelNames: labelNames),
    );
  }

  /// Returns the existing histogram named [name] or creates one.
  Histogram histogram(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
    List<double>? buckets,
  }) {
    return _histograms.putIfAbsent(
      name,
      () => Histogram(
        name,
        help: help,
        labelNames: labelNames,
        buckets: buckets,
      ),
    );
  }

  /// Returns the existing gauge named [name] or creates one.
  Gauge gauge(
    String name, {
    String help = '',
    List<String> labelNames = const <String>[],
  }) {
    return _gauges.putIfAbsent(
      name,
      () => Gauge(name, help: help, labelNames: labelNames),
    );
  }

  /// Serializes every registered metric in Prometheus text exposition format
  /// (https://prometheus.io/docs/instrumenting/exposition_formats/).
  String exportText() {
    final buffer = StringBuffer();
    final all = <String, _Metric>{
      ..._counters,
      ..._histograms,
      ..._gauges,
    };
    final names = all.keys.toList()..sort();
    for (final name in names) {
      all[name]!.writeText(buffer);
    }
    return buffer.toString();
  }
}

/// Shared shape for every metric family.
abstract class _Metric {
  String get name;

  String get help;

  List<String> get labelNames;

  void writeText(StringBuffer buffer);
}

/// Value-equal key for a set of label values (plain `List` keys in a map
/// use identity semantics, so equal label sets would miss each other).
@immutable
class _LabelKey {
  const _LabelKey(this.values);

  final List<String> values;

  @override
  bool operator ==(Object other) {
    if (other is! _LabelKey) return false;
    if (other.values.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] != values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);
}

/// A monotonically increasing counter.
class Counter implements _Metric {
  Counter(
    this.name, {
    this.help = '',
    List<String> labelNames = const <String>[],
  }) : labelNames = List<String>.unmodifiable(labelNames);

  @override
  final String name;

  @override
  final String help;

  @override
  final List<String> labelNames;

  final Map<_LabelKey, num> _values = <_LabelKey, num>{};

  /// Increments the series identified by [labels] by one.
  void increment({Map<String, String> labels = const <String, String>{}}) {
    add(1, labels: labels);
  }

  /// Adds [value] to the series identified by [labels].
  void add(num value, {Map<String, String> labels = const <String, String>{}}) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) + value;
  }

  /// Returns the current value for [labels] (0 when never incremented).
  num valueFor(Map<String, String> labels) => _values[_labelKey(labels)] ?? 0;

  @override
  void writeText(StringBuffer buffer) {
    buffer
      ..writeln('# HELP $name ${help.isEmpty ? name : help}')
      ..writeln('# TYPE $name counter');
    _writeSeries(buffer, name, labelNames, _values);
  }

  _LabelKey _labelKey(Map<String, String> labels) =>
      _LabelKey(labelNames.map((name) => labels[name] ?? '').toList());
}

/// A histogram with cumulative buckets. Bucket counts are cumulative (le)
/// across the configured boundaries plus an implicit +Inf bucket, alongside
/// `_sum` and `_count`.
class Histogram implements _Metric {
  Histogram(
    this.name, {
    this.help = '',
    List<String> labelNames = const <String>[],
    List<double>? buckets,
  })  : labelNames = List<String>.unmodifiable(labelNames),
        buckets = List<double>.unmodifiable(buckets ?? defaultBuckets);

  static const List<double> defaultBuckets = <double>[
    0.005,
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2.5,
    5,
    10,
  ];

  @override
  final String name;

  @override
  final String help;

  @override
  final List<String> labelNames;

  final List<double> buckets;

  final Map<_LabelKey, List<int>> _bucketCounts = <_LabelKey, List<int>>{};
  final Map<_LabelKey, num> _sums = <_LabelKey, num>{};
  final Map<_LabelKey, int> _counts = <_LabelKey, int>{};

  /// Observes [value] against the series identified by [labels].
  void observe(
    num value, {
    Map<String, String> labels = const <String, String>{},
  }) {
    final key = _labelKey(labels);
    final counts = _bucketCounts.putIfAbsent(
      key,
      () => List<int>.filled(buckets.length + 1, 0),
    );
    final upperBound = _upperBoundIndex(value);
    for (var i = upperBound; i < counts.length; i++) {
      counts[i] += 1;
    }
    _sums[key] = (_sums[key] ?? 0) + value;
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  /// Returns the count of observations for [labels].
  int countFor(Map<String, String> labels) => _counts[_labelKey(labels)] ?? 0;

  /// Returns the cumulative count of observations <= [upperBound] for [labels].
  int bucketCountFor(Map<String, String> labels, double upperBound) {
    final counts = _bucketCounts[_labelKey(labels)];
    if (counts == null) return 0;
    final index = _upperBoundIndex(upperBound);
    return index < counts.length ? counts[index] : counts.last;
  }

  /// Index of the first bucket whose upper bound is >= [value]. Values above
  /// the largest bucket fall into the implicit +Inf bucket (last index).
  int _upperBoundIndex(num value) {
    for (var i = 0; i < buckets.length; i++) {
      if (value <= buckets[i]) return i;
    }
    return buckets.length;
  }

  @override
  void writeText(StringBuffer buffer) {
    buffer
      ..writeln('# HELP $name ${help.isEmpty ? name : help}')
      ..writeln('# TYPE $name histogram');
    final keys = _counts.keys.toList()..sort(_compareLabelKeys);
    for (final key in keys) {
      final counts = _bucketCounts[key]!;
      for (var i = 0; i < buckets.length; i++) {
        buffer.writeln(
          '${name}_bucket${_bucketLabels(key.values, _formatNumber(buckets[i]))} '
          '${counts[i]}',
        );
      }
      buffer
        ..writeln(
          '${name}_bucket${_bucketLabels(key.values, '+Inf')} '
          '${counts[buckets.length]}',
        )
        ..writeln(
          '${name}_sum${_formatLabels(labelNames, key.values)} '
          '${_formatNumber(_sums[key] ?? 0)}',
        )
        ..writeln('${name}_count${_formatLabels(labelNames, key.values)} ${_counts[key]}');
    }
  }

  /// Label text for a bucket line: the cumulative `le` bound plus the
  /// series' own labels, e.g. `{le="0.25",method="x"}`.
  String _bucketLabels(List<String> values, String bound) {
    final parts = <String>['le="$bound"', ..._labelPairs(labelNames, values)];
    return '{${parts.join(',')}}';
  }

  _LabelKey _labelKey(Map<String, String> labels) =>
      _LabelKey(labelNames.map((name) => labels[name] ?? '').toList());
}

/// A gauge that can be incremented, decremented or set directly.
class Gauge implements _Metric {
  Gauge(
    this.name, {
    this.help = '',
    List<String> labelNames = const <String>[],
  }) : labelNames = List<String>.unmodifiable(labelNames);

  @override
  final String name;

  @override
  final String help;

  @override
  final List<String> labelNames;

  final Map<_LabelKey, num> _values = <_LabelKey, num>{};

  /// Increments the series identified by [labels] by one.
  void increment({Map<String, String> labels = const <String, String>{}}) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) + 1;
  }

  /// Decrements the series identified by [labels] by one.
  void decrement({Map<String, String> labels = const <String, String>{}}) {
    final key = _labelKey(labels);
    _values[key] = (_values[key] ?? 0) - 1;
  }

  /// Sets the series identified by [labels] to [value].
  void set(num value, {Map<String, String> labels = const <String, String>{}}) {
    _values[_labelKey(labels)] = value;
  }

  /// Returns the current value for [labels] (0 when never touched).
  num valueFor(Map<String, String> labels) => _values[_labelKey(labels)] ?? 0;

  @override
  void writeText(StringBuffer buffer) {
    buffer
      ..writeln('# HELP $name ${help.isEmpty ? name : help}')
      ..writeln('# TYPE $name gauge');
    _writeSeries(buffer, name, labelNames, _values);
  }

  _LabelKey _labelKey(Map<String, String> labels) =>
      _LabelKey(labelNames.map((name) => labels[name] ?? '').toList());
}

void _writeSeries(
  StringBuffer buffer,
  String metricName,
  List<String> labelNames,
  Map<_LabelKey, num> values,
) {
  final entries = values.entries.toList()
    ..sort((a, b) => _compareLabelKeys(a.key, b.key));
  for (final entry in entries) {
    final labelText = labelNames.isEmpty
        ? ''
        : _formatLabels(labelNames, entry.key.values);
    buffer.writeln('$metricName$labelText ${_formatNumber(entry.value)}');
  }
}

int _compareLabelKeys(_LabelKey a, _LabelKey b) {
  final aValues = a.values;
  final bValues = b.values;
  final length = aValues.length < bValues.length ? aValues.length : bValues.length;
  for (var i = 0; i < length; i++) {
    final comparison = aValues[i].compareTo(bValues[i]);
    if (comparison != 0) return comparison;
  }
  return aValues.length.compareTo(bValues.length);
}

String _formatLabels(List<String> names, List<String> values) {
  final parts = _labelPairs(names, values);
  return parts.isEmpty ? '' : '{${parts.join(',')}}';
}

List<String> _labelPairs(List<String> names, List<String> values) {
  final parts = <String>[];
  for (var i = 0; i < names.length; i++) {
    parts.add('${names[i]}="${_escapeLabelValue(values[i])}"');
  }
  return parts;
}

String _escapeLabelValue(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
}

String _formatNumber(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
