import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/api/dto/clinical_processing_request.dart';
import 'package:clinical_intelligence_dart/application/services/clinical_processing_orchestrator.dart';
import 'package:clinical_intelligence_dart/application/services/validation_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/clinical-processing/process
///
/// Generic clinical text processing endpoint.
/// Supports the voice-notes workflow:
///   doctor dictates → app STT → raw text → this endpoint → processed text
///
/// Processing modes:
///   - VOCAB_ASSIST: conservative terminology improvement
///   - CLEAN_TRANSCRIPT: transcript cleanup
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({
        'error': 'Method not allowed. Use POST.',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final body = await context.request.body();
    if (body.isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({
          'error': 'Request body is required.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final request = ClinicalProcessingRequest.fromJson(json);

    final orchestrator = context.read<ClinicalProcessingOrchestrator>();
    final response = await orchestrator.process(request);

    return Response.json(body: response.toJson());
  } on ValidationException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({
        'error': e.message,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } on FormatException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({
        'error': 'Invalid JSON: ${e.message}',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({
        'error': 'Internal server error: $e',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
