import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/application/services/summary_orchestrator.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/transcript-summary/context-enriched
///
/// Generate a structured summary using past consultation context.
/// Body: {"transcriptText": "...", "pastContext": "..."} — when
/// `pastContext` is omitted or empty, similar past consultations are
/// retrieved automatically from the vector store.
/// Response: structured summary object.
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.contextEnriched)(
    requireAuth(
      (ctx) => handleLlmPost(
        ctx,
        requiredFields: ['transcriptText'],
        onJson: (json) async {
          final llm = context.read<LlmPort>();
          var pastContext = json['pastContext'] as String? ?? '';
          if (pastContext.trim().isEmpty) {
            final orchestrator = context.read<SummaryOrchestrator>();
            pastContext = await orchestrator.buildPastContext(
              json['transcriptText'] as String,
            );
          }
          final summary = await llm.generateContextEnrichedSummary(
            json['transcriptText'] as String,
            pastContext,
          );
          return Response.json(body: summary.toJson());
        },
      ),
      scopes: ['clinical:write'],
    ),
  )(context);
}
