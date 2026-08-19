import 'package:clinical_intelligence_dart/core/observability/metric_registry.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /metrics
///
/// Exposes the process metric registry in Prometheus text exposition format.
/// Exempt from auth (see `exemptPaths` in routes/_middleware.dart) so scrape
/// targets do not need bearer credentials.
Response onRequest(RequestContext context) {
  final registry = context.read<MetricRegistry>();
  return Response(
    body: registry.exportText(),
    headers: const {
      'Content-Type': 'text/plain; version=0.0.4; charset=utf-8',
    },
  );
}
