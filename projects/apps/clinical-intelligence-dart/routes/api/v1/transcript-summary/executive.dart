import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/executive
///
/// Generate an executive summary from transcript text.
/// Body: {"transcriptText": "..."}
/// Response: {"summary": "..."}
Future<Response> onRequest(RequestContext context) async {
  return requireAuth(
    (ctx) => handleLlmPost(ctx, onJson: (json) async {
      final llm = context.read<LlmPort>();
      final summary = await llm.generateExecutiveSummary(
        json['transcriptText'] as String,
      );
      return Response.json(body: {'summary': summary});
    }),
    scopes: ['clinical:write'],
  )(context);
}
