import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/observability/metric_registry.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:shared_models/shared_models.dart';

/// Dart Frog middleware that records HTTP request metrics.
///
/// Registers and updates:
///   - `http_requests_total` — counter, labels: method, path, status
///   - `http_request_duration_seconds` — histogram, labels: method, path, status
///
/// The middleware is registered outermost in the chain so it observes every
/// request including those rejected by inner middleware (auth, validation).
Middleware metricsMiddleware(MetricRegistry registry) {
  final requests = registry.counter(
    'http_requests_total',
    help: 'Total number of HTTP requests.',
    labelNames: const ['method', 'path', 'status'],
  );
  final duration = registry.histogram(
    'http_request_duration_seconds',
    help: 'HTTP request latency in seconds.',
    labelNames: const ['method', 'path', 'status'],
  );

  return (handler) {
    return (context) async {
      final stopwatch = Stopwatch()..start();
      final method = context.request.method.value;
      final path = context.request.uri.path;

      Response response;
      try {
        response = await handler(context);
      } catch (error) {
        stopwatch.stop();
        final labels = <String, String>{
          'method': method,
          'path': path,
          'status': '500',
        };
        requests.increment(labels: labels);
        duration.observe(
          stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond,
          labels: labels,
        );
        rethrow;
      }

      stopwatch.stop();
      final labels = <String, String>{
        'method': method,
        'path': path,
        'status': response.statusCode.toString(),
      };
      requests.increment(labels: labels);
      duration.observe(
        stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond,
        labels: labels,
      );
      return response;
    };
  };
}

/// Delegating [LlmPort] that times every inference call into the
/// `llm_inference_duration_seconds` histogram and counts failures in the
/// `llm_inference_errors_total` counter (both labelled by `method`).
///
/// Wrapping the port keeps instrumentation at a single central point — every
/// route and application service resolves the same instrumented instance.
class InstrumentedLlmPort implements LlmPort {
  InstrumentedLlmPort(LlmPort inner, MetricRegistry registry)
      : _inner = inner {
    _duration = registry.histogram(
      'llm_inference_duration_seconds',
      help: 'LLM inference latency in seconds.',
      labelNames: const ['method'],
    );
    _errors = registry.counter(
      'llm_inference_errors_total',
      help: 'Number of failed LLM inference calls.',
      labelNames: const ['method'],
    );
  }

  final LlmPort _inner;
  late final Histogram _duration;
  late final Counter _errors;

  @override
  Future<String> processText(String input, ProcessingMode mode) {
    return _timed('processText', () => _inner.processText(input, mode));
  }

  @override
  Future<StructuredSummary> generateStructuredSummary(String transcriptText) {
    return _timed(
      'generateStructuredSummary',
      () => _inner.generateStructuredSummary(transcriptText),
    );
  }

  @override
  Future<StructuredSummary> generateContextEnrichedSummary(
    String transcriptText,
    String pastContext,
  ) {
    return _timed(
      'generateContextEnrichedSummary',
      () => _inner.generateContextEnrichedSummary(transcriptText, pastContext),
    );
  }

  @override
  Future<String> generateExecutiveSummary(String transcriptText) {
    return _timed(
      'generateExecutiveSummary',
      () => _inner.generateExecutiveSummary(transcriptText),
    );
  }

  @override
  Future<String> generateDoctorNote(String transcriptText) {
    return _timed(
      'generateDoctorNote',
      () => _inner.generateDoctorNote(transcriptText),
    );
  }

  // ============ FIELD-LEVEL GENERATION ============

  @override
  Future<String> generateField(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    return _timed(
      'generateField',
      () => _inner.generateField(fieldName, transcriptText, patientContext: patientContext),
    );
  }

  @override
  Stream<String> generateFieldStream(
    String fieldName,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    // For streaming, we can't easily wrap with timing, so delegate directly
    return _inner.generateFieldStream(fieldName, transcriptText, patientContext: patientContext);
  }

  @override
  Future<Map<String, String>> generateFields(
    List<String> fieldNames,
    String transcriptText, {
    PatientContext? patientContext,
  }) {
    return _timed(
      'generateFields',
      () => _inner.generateFields(fieldNames, transcriptText, patientContext: patientContext),
    );
  }

  Future<T> _timed<T>(String method, Future<T> Function() call) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await call();
      _duration.observe(
        stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond,
        labels: {'method': method},
      );
      return result;
    } catch (error) {
      _errors.increment(labels: {'method': method});
      rethrow;
    }
  }
}
