import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/api/dto/transcript_summary_request.dart';
import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/generate
///
/// Generate a full transcript summary bundle (Milestone 2).
Future<Response> onRequest(RequestContext context) async {
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
