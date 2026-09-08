import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:shared_models/shared_models.dart';

/// POST /api/v1/ehr/stream-field
///
/// Stream a single EHR field suggestion from transcript text.
/// Body: {"transcriptText": "...", "fieldName": "complaint", "patientContext": {...}}
/// Response: Server-Sent Events stream with partial results, final event has "done": true.
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.ehrStreamField)(
    requireAuth(
      (ctx) async {
        if (ctx.request.method != HttpMethod.post) {
          return Response(
            statusCode: HttpStatus.methodNotAllowed,
            body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final Map<String, dynamic> json;
        try {
          final body = await ctx.request.body();
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
        }

        final transcriptText = json['transcriptText'] as String;
        final fieldName = json['fieldName'] as String;
        final patientContext = json['patientContext'] != null
            ? PatientContext.fromJson(json['patientContext'] as Map<String, dynamic>)
            : null;

        final llm = ctx.read<LlmPort>();
        final stream = llm.generateFieldStream(
          fieldName,
          transcriptText,
          patientContext: patientContext,
        );

        // Convert string stream to SSE byte stream
        final byteStream = stream.map((chunk) {
          final data = jsonEncode({'fieldName': fieldName, 'value': chunk, 'done': false});
          return 'data: $data\n\n'.codeUnits;
        });

        return Response.stream(
          statusCode: HttpStatus.ok,
          body: byteStream,
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        );
      },
      scopes: ['clinical:write'],
    ),
  )(context);
}