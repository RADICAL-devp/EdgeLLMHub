import 'dart:convert';
import 'dart:io';

import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/auth/token
///
/// Development-only token mint endpoint. Signs a JWT with the embedded dev
/// private key so the mobile app can exercise the full API without an
/// identity provider.
///
/// Disable by setting DISABLE_DEV_AUTH=true in the environment.
/// In production, tokens MUST come from a real identity provider.
Future<Response> onRequest(RequestContext context) async {
  if (Platform.environment['DISABLE_DEV_AUTH'] == 'true') {
    return Response(
      statusCode: HttpStatus.notFound,
      body: jsonEncode({'error': 'Not found'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      body: jsonEncode({'error': 'Method not allowed. Use POST.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final jwtService = context.read<JwtService>();
  final expiresIn = Duration(hours: 12);

  final token = await jwtService.sign(
    claims: {
      'sub': 'dev-doctor',
      'org': 'dev-clinic',
      'roles': ['doctor'],
      'scope': 'clinical:read clinical:write',
    },
    expiresIn: expiresIn,
  );

  final expiresAt = DateTime.now().toUtc().add(expiresIn);

  return Response.json(
    body: {
      'token': token,
      'tokenType': 'Bearer',
      'expiresAt': expiresAt.toIso8601String(),
      'scopes': ['clinical:read', 'clinical:write'],
    },
  );
}
