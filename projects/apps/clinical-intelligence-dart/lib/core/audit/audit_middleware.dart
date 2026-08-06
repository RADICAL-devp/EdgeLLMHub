import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:clinical_intelligence_dart/core/audit/audit_logger.dart';
import 'package:clinical_intelligence_dart/core/audit/phi_redactor.dart';
import 'package:clinical_intelligence_dart/core/auth/auth_context.dart';

/// Middleware that logs all API requests with PHI redaction.
Middleware auditMiddleware(AuditLogger auditLogger) {
  return (handler) {
    return (context) async {
      final stopwatch = Stopwatch()..start();
      final correlationId = context.request.headers['x-correlation-id'] ?? 
          DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      
      // Add correlation ID to response headers
      context.response = context.response.copyWith(
        headers: {
          ...context.response.headers,
          'x-correlation-id': correlationId,
        },
      );

      // Read request body for logging
      String? requestBody;
      final body = await context.request.body();
      if (body.isNotEmpty) {
        requestBody = body;
      }

      // Execute handler
      Response response;
      try {
        response = await handler(context);
      } catch (e, stack) {
        stopwatch.stop();
        _logError(auditLogger, context, correlationId, e, stack, stopwatch.elapsedMilliseconds, requestBody);
        rethrow;
      }

      stopwatch.stop();
      
      // Log the request/response
      _logRequest(auditLogger, context, correlationId, response, stopwatch.elapsedMilliseconds, requestBody);

      return response;
    };
  };
}

void _logRequest(
  AuditLogger auditLogger,
  RequestContext context,
  String correlationId,
  Response response,
  int latencyMs,
  String? requestBody,
) {
  final auth = context.read<AuthContext?>();
  final method = context.request.method.value;
  final path = context.request.uri.path;
  final queryParams = context.request.uri.queryParameters;
  final statusCode = response.statusCode;

  // Determine outcome
  String outcome;
  if (statusCode >= 200 && statusCode < 300) {
    outcome = 'success';
  } else if (statusCode == 401) {
    outcome = 'unauthorized';
  } else if (statusCode == 403) {
    outcome = 'forbidden';
  } else if (statusCode >= 400 && statusCode < 500) {
    outcome = 'failure';
  } else {
    outcome = 'error';
  }

  // Redact request body
  final redactor = PhiRedactor();
  Map<String, dynamic>? metadata;
  try {
    metadata = {
      'method': method,
      'path': path,
      'queryParams': queryParams,
      'statusCode': statusCode,
      'latencyMs': latencyMs,
      if (requestBody != null) 'requestBody': redactor.redact(requestBody),
    };
  } catch (_) {
    metadata = {'error': 'Failed to serialize metadata'};
  }

  if (auth != null) {
    auditLogger.logClinicalProcessing(
      correlationId: correlationId,
      auth: auth,
      action: '$method $path',
      resource: _resourceFromPath(path),
      resourceId: _resourceIdFromPath(path),
      outcome: outcome,
      metadata: metadata,
    );
  }
}

void _logError(
  AuditLogger auditLogger,
  RequestContext context,
  String correlationId,
  Object error,
  StackTrace stack,
  int latencyMs,
  String? requestBody,
) {
  final auth = context.read<AuthContext?>();
  final method = context.request.method.value;
  final path = context.request.uri.path;

  final redactor = PhiRedactor();
  final metadata = {
    'method': method,
    'path': path,
    'latencyMs': latencyMs,
    'error': error.toString(),
    if (requestBody != null) 'requestBody': redactor.redact(requestBody),
  };

  if (auth != null) {
    auditLogger.logClinicalProcessing(
      correlationId: correlationId,
      auth: auth,
      action: '$method $path',
      resource: _resourceFromPath(path),
      resourceId: _resourceIdFromPath(path),
      outcome: 'error',
      metadata: metadata,
    );
  }
}

String _resourceFromPath(String path) {
  if (path.startsWith('/api/v1/clinical-processing')) return 'clinical_processing';
  if (path.startsWith('/api/v1/transcript-summary')) return 'transcript_summary';
  if (path.startsWith('/api/v1/auth')) return 'auth';
  if (path.startsWith('/.well-known')) return 'jwks';
  return 'unknown';
}

String? _resourceIdFromPath(String path) {
  final match = RegExp(r'/([a-zA-Z0-9-]+)/?$').firstMatch(path);
  return match?.group(1);
}
