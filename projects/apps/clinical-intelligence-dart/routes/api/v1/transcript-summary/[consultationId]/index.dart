import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/observability/metric_registry.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:shared_models/shared_models.dart';

/// GET /api/v1/transcript-summary/[consultationId]
///   - Retrieve a previously generated summary.
///
/// POST /api/v1/transcript-summary/generate
///   - Handle Dart Frog route matching fallback: if consultationId is "generate",
///     we treat this as a POST request to generate a summary bundle.
Future<Response> onRequest(
  RequestContext context,
  String consultationId,
) async {
  if (consultationId == 'generate') {
    return jsonSchemaValidation(RequestSchemas.summaryBundle)(
      requireAuth(_handleGenerate, scopes: ['clinical:write']),
    )(context);
  }

  return requireAuth(
    (ctx) => _handleGetSummary(ctx, consultationId),
    scopes: ['clinical:read'],
  )(context);
}

/// POST /api/v1/transcript-summary/generate
Future<Response> _handleGenerate(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final body = await context.request.body();
    if (body.isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Request body is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final request = TranscriptSummaryRequest.fromJson(json);

    final orchestrator = context.read<SummaryOrchestrator>();
    final response = await orchestrator.generateSummary(request);

    // A new consultation summary became active.
    context
        .read<MetricRegistry>()
        .gauge('active_consultations', help: 'Active consultation summaries.')
        .increment();

    return Response.json(body: response.toJson());
  } on ValidationException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': e.message}),
      headers: {'Content-Type': 'application/json'},
    );
  } on FormatException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': 'Invalid JSON: ${e.message}'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({'error': 'Internal server error: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// GET /api/v1/transcript-summary/[consultationId]
Future<Response> _handleGetSummary(
  RequestContext context,
  String consultationId,
) async {
  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use GET.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final orchestrator = context.read<SummaryOrchestrator>();
    final response = await orchestrator.getSummary(consultationId);

    if (response == null) {
      return Response(
        statusCode: HttpStatus.notFound,
        body: jsonEncode({
          'error': 'No summary found for consultation: $consultationId',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.json(body: response.toJson());
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({'error': 'Internal server error: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
