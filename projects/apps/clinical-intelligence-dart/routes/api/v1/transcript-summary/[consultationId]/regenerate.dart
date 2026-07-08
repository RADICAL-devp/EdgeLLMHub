import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/[consultationId]/regenerate
///
/// Regenerate a summary for an existing transcript (Milestone 2).
Future<Response> onRequest(
  RequestContext context,
  String consultationId,
) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final orchestrator = context.read<SummaryOrchestrator>();
    final response = await orchestrator.regenerateSummary(consultationId);

    return Response.json(body: response.toJson());
  } on ValidationException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': e.message}),
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
