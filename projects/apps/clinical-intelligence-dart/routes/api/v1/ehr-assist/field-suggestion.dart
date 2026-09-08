import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:shared_models/shared_models.dart';

/// POST /api/v1/ehr/field-suggestion
///
/// Generate a single EHR field suggestion from transcript text.
/// Body: {"transcriptText": "...", "fieldName": "complaint", "patientContext": {...}}
/// Response: {"fieldName": "complaint", "value": "..."}
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.ehrFieldSuggestion)(
    requireAuth(
      (ctx) => handleLlmPost(ctx, onJson: (json) async {
        final llm = context.read<LlmPort>();
        final transcriptText = json['transcriptText'] as String;
        final fieldName = json['fieldName'] as String;
        final patientContext = json['patientContext'] != null
            ? PatientContext.fromJson(json['patientContext'] as Map<String, dynamic>)
            : null;

        final value = await llm.generateField(
          fieldName,
          transcriptText,
          patientContext: patientContext,
        );

        return Response.json(body: {'fieldName': fieldName, 'value': value});
      }),
      scopes: ['clinical:write'],
    ),
  )(context);
}