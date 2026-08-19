import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Shared handler for POST-only JSON endpoints (LLM-backed routes).
///
/// Validates method, body presence, required fields, and JSON shape before
/// delegating to [onJson], mapping failures to proper HTTP responses.
Future<Response> handleLlmPost(
  RequestContext context, {
  required Future<Response> Function(Map<String, dynamic> json) onJson,
  List<String> requiredFields = const ['transcriptText'],
}) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final Map<String, dynamic> json;
  try {
    final body = await context.request.body();
    if (body.isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Request body is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    json = jsonDecode(body) as Map<String, dynamic>;
  } on FormatException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': 'Invalid JSON: ${e.message}'}),
      headers: {'Content-Type': 'application/json'},
    );
  } on TypeError {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': 'Request body must be a JSON object.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  for (final field in requiredFields) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Field "$field" is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  try {
    return await onJson(json);
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({'error': 'Internal server error: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
