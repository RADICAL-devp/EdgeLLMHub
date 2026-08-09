import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/context-enriched
///
/// Generate a structured summary using past consultation context.
/// Body: {"transcriptText": "...", "pastContext": "..."}
/// Response: structured summary object.
Future<Response> onRequest(RequestContext context) async {
  return requireAuth(
    (ctx) => handleLlmPost(
      ctx,
      requiredFields: ['transcriptText', 'pastContext'],
      onJson: (json) async {
        final llm = context.read<LlmPort>();
        final summary = await llm.generateContextEnrichedSummary(
          json['transcriptText'] as String,
          json['pastContext'] as String,
        );
        return Response.json(body: summary.toJson());
      },
    ),
    scopes: ['clinical:write'],
  )(context);
}
