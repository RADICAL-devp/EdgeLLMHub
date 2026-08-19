import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/application/ports/doctor_note_repository.dart';
import 'package:clinical_intelligence_dart/core/auth/require_auth.dart';
import 'package:clinical_intelligence_dart/core/models/doctor_note.dart';
import 'package:clinical_intelligence_dart/core/validation/request_validator.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/notes/sync
///
/// Upsert a doctor note synced from the mobile app (last-write-wins).
/// Body: DoctorNote JSON (see lib/core/models/doctor_note.dart).
Future<Response> onRequest(RequestContext context) async {
  return jsonSchemaValidation(RequestSchemas.notesSync)(
    requireAuth(_handleSync, scopes: ['clinical:write']),
  )(context);
}

Future<Response> _handleSync(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final body = await context.request.body();
    if (body.isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Request body is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['noteId'] is! String || (json['noteId'] as String).isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Field "noteId" is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (json['consultationId'] is! String ||
        (json['consultationId'] as String).isEmpty) {
      return Response(
        statusCode: HttpStatus.badRequest,
        body: jsonEncode({'error': 'Field "consultationId" is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final note = DoctorNote.fromJson(json);
    final repository = context.read<DoctorNoteRepository>();
    await repository.upsert(note);

    return Response.json(body: {'synced': true, 'noteId': note.noteId});
  } on FormatException catch (e) {
    return Response(
      statusCode: HttpStatus.badRequest,
      body: jsonEncode({'error': 'Invalid JSON: ${e.message}'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(
      statusCode: HttpStatus.internalServerError,
      body: jsonEncode({'error': 'Internal server error: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
