import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/structured
///
/// Generate a 7-field structured clinical summary from transcript text.
/// Body: {"transcriptText": "..."}
/// Response: structured summary object.
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.structuredSummary)(
    requireAuth(
      (ctx) => handleLlmPost(ctx, onJson: (json) async {
        final llm = context.read<LlmPort>();
        final summary = await llm.generateStructuredSummary(
          json['transcriptText'] as String,
        );
        return Response.json(body: summary.toJson());
      }),
      scopes: ['clinical:write'],
    ),
  )(context);
}
