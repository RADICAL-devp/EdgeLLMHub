import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:dart_frog/dart_frog.dart';
import 'generate.dart' as generate;

/// GET /api/v1/transcript-summary/[consultationId]
///
/// Retrieve a previously generated transcript summary (Milestone 2).
Future<Response> onRequest(
  RequestContext context,
  String consultationId,
) async {
  // Handle Dart Frog route conflict: if ID is "generate", route to generate request
  if (consultationId == 'generate') {
    return generate.onRequest(context);
  }

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
