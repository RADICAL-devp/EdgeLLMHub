import 'dart:convert';
import 'dart:developer' as developer;

/// Log severity levels, ordered by increasing importance.
enum LogLevel {
  debug(10, 'debug'),
  info(20, 'info'),
  warn(30, 'warn'),
  error(40, 'error');

  const LogLevel(this.priority, this.label);

  /// Numeric priority used for level filtering.
  final int priority;

  /// Machine-readable label emitted in log lines.
  final String label;
}

/// Receives a fully-formatted single-line JSON log record.
///
/// The default sink forwards to `dart:developer`'s [developer.log] so logs
/// reach the system log in production (and DevTools in development).
typedef LogSink = void Function(String line);

/// Structured, JSON-formatted logger for production use.
///
/// Every emitted line is a JSON object with a stable shape:
/// `timestamp`, `level`, `logger`, optional `correlationId`, `message`,
/// optional `error`/`stackTrace`, plus any ambient [context] entries merged
/// in. A correlation id can be set per-request/operation and is propagated
/// into every line until cleared or overridden.
class JsonLogger {
  JsonLogger({
    LogLevel minLevel = LogLevel.debug,
    String name = 'app',
    LogSink? sink,
    Map<String, Object?>? context,
  })  : _minLevel = minLevel,
        _name = name,
        _sink = sink ?? _developerLogSink,
        _context = Map<String, Object?>.unmodifiable(context ?? const {});

  static void _developerLogSink(String line) {
    developer.log(line, name: 'json');
  }

  final LogLevel _minLevel;
  final String _name;
  final LogSink _sink;
  final Map<String, Object?> _context;

  String? _correlationId;

  /// The correlation id applied to every subsequent log line, or null.
  String? get correlationId => _correlationId;

  /// Sets the correlation id propagated into all subsequent log lines.
  ///
  /// Use for a request/operation scope; call [clearCorrelationId] when the
  /// scope ends.
  void setCorrelationId(String? correlationId) {
    _correlationId = correlationId;
  }

  /// Clears the active correlation id.
  void clearCorrelationId() {
    _correlationId = null;
  }

  /// Emits a [LogLevel.debug] line.
  void debug(
    String message, {
    Map<String, Object?>? context,
    String? correlationId,
  }) {
    log(LogLevel.debug, message, context: context, correlationId: correlationId);
  }

  /// Emits a [LogLevel.info] line.
  void info(
    String message, {
    Map<String, Object?>? context,
    String? correlationId,
  }) {
    log(LogLevel.info, message, context: context, correlationId: correlationId);
  }

  /// Emits a [LogLevel.warn] line.
  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
    String? correlationId,
  }) {
    log(
      LogLevel.warn,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      correlationId: correlationId,
    );
  }

  /// Emits a [LogLevel.error] line.
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
    String? correlationId,
  }) {
    log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      correlationId: correlationId,
    );
  }

  /// Emits a single JSON log line when [level] is at or above [minLevel].
  ///
  /// The effective correlation id is the per-call [correlationId] when given,
  /// otherwise the logger-level value set via [setCorrelationId]. Per-call
  /// [context] entries override ambient logger [context] entries of the same
  /// key.
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
    String? correlationId,
  }) {
    if (level.priority < _minLevel.priority) return;

    final effectiveCorrelationId = correlationId ?? _correlationId;
    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level.label,
      'logger': _name,
      if (effectiveCorrelationId != null) 'correlationId': effectiveCorrelationId,
      'message': message,
      if (error != null) 'error': _stringify(error),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      ..._context,
      ...?context,
    };
    _sink(jsonEncode(_sanitizeValue(record)));
  }

  /// Converts arbitrary objects into stable string representations.
  static String _stringify(Object value) {
    final string = value.toString();
    return string.length > 2000 ? '${string.substring(0, 2000)}…' : string;
  }

  /// Recursively coerces values into JSON-safe types; anything unknown is
  /// stringified so `jsonEncode` never throws on a log line.
  static Object? _sanitizeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), _sanitizeValue(entry)),
      );
    }
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList();
    }
    return _stringify(value);
  }
}
