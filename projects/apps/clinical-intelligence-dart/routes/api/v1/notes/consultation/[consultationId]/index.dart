import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/ports/doctor_note_repository.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/v1/notes/consultation/[consultationId]
///
/// Fetch the most recent synced note for a consultation.
/// Response: DoctorNote JSON, or 404 with {"error": "..."}.
Future<Response> onRequest(
  RequestContext context,
  String consultationId,
) async {
  return requireAuth(
    (ctx) => _handleFetch(ctx, consultationId),
    scopes: ['clinical:read'],
  )(context);
}

Future<Response> _handleFetch(
  RequestContext context,
  String consultationId,
) async {
  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use GET.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final repository = context.read<DoctorNoteRepository>();
    final note = await repository.findByConsultationId(consultationId);

    if (note == null) {
      return Response(
        statusCode: HttpStatus.notFound,
        body: jsonEncode({
          'error': 'No note found for consultation: $consultationId',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.json(body: note.toJson());
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({'error': 'Internal server error: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
