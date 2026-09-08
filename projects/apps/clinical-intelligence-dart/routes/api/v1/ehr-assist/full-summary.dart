import 'package:clinical_intelligence_dart/api/llm_route_handler.dart';
import 'package:clinical_intelligence_dart/application/ports/llm_port.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:shared_models/shared_models.dart';

/// POST /api/v1/ehr/full-summary
///
/// Generate multiple EHR fields at once from transcript text.
/// Body: {"transcriptText": "...", "fieldNames": ["complaint", "vitals"], "patientContext": {...}}
/// Response: {"complaint": "...", "vitals": "..."}
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.ehrFullSummary)(
    requireAuth(
      (ctx) => handleLlmPost(ctx, onJson: (json) async {
        final llm = context.read<LlmPort>();
        final transcriptText = json['transcriptText'] as String;
        final fieldNames = (json['fieldNames'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [
              'complaint',
              'pastHistory',
              'vitals',
              'physicalExamination',
              'investigationOrdered',
              'diagnosis',
              'advice',
              'manualPrescription',
            ];
        final patientContext = json['patientContext'] != null
            ? PatientContext.fromJson(json['patientContext'] as Map<String, dynamic>)
            : null;

        final results = await llm.generateFields(
          fieldNames,
          transcriptText,
          patientContext: patientContext,
        );

        return Response.json(body: results);
      }),
      scopes: ['clinical:write'],
    ),
  )(context);
}