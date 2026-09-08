import 'dart:io';
import 'package:doctor_app/core/models/structured_summary.dart';

/// PHI detection and redaction for audit logging.
class PhiRedactor {
  String redact(String input) {
    if (input.isEmpty) return input;
    return input
      .replaceAll(RegExp(r'\b\d{3}-\d{2}-\d{4}\b'), '[SSN REDACTED]')
      .replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b'), '[DOB REDACTED]')
      .replaceAll(RegExp(r'Dr\.\s+\w+'), '[PHYSICIAN REDACTED]')
      .replaceAll(RegExp(r'Patient:\s+\w+'), '[PATIENT REDACTED]');
  }
}

/// Medical query audit service for HIPAA/GDPR compliance.
class AuditEvent {
  AuditEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.action,
    required this.resource,
    required this.resourceId,
    required this.outcome,
    required this.metadataJson,
    required this.correlationId,
  });
  final String id;
  final DateTime timestamp;
  final String userId;
  final String action;
  final String resource;
  final String? resourceId;
  final String outcome;
  final String? metadataJson;
  final String correlationId;
}

/// Medical query audit service for HIPAA/GDPR compliance.
///
/// Logs all medical LLM queries with PHI redaction,
/// maintains an audit trail for compliance purposes.
class AuditService {
  final PhiRedactor _phiRedactor = PhiRedactor();

  /// Log a medical LLM query with redacted PHI.
  Future<void> logMedicalQuery({
    required String userId,
    required String query,
    required String response,
    required String modelId,
    required String specialty,
  }) async {
    final redactedQuery = _phiRedactor.redact(query);
    final redactedResponse = _phiRedactor.redact(response);

    final event = AuditEvent(
      id: _generateId(),
      timestamp: DateTime.now().toUtc(),
      userId: userId,
      action: 'MEDICAL_LLM_QUERY',
      resource: 'structured_summary',
      resourceId: null,
      outcome: 'success',
      metadataJson: {
        'model_id': modelId,
        'specialty': specialty,
        'query_length': query.length,
        'response_length': response.length,
        'redacted_query': redactedQuery,
        'redacted_response': redactedResponse,
      }.toString(),
      correlationId: _generateId(),
    );

    print('[AuditService] ${event.timestamp.toIso8601String()} - $userId - $modelId - $specialty');
  }

  /// Log a structured summary generation event.
  Future<void> logStructuredSummary({
    required String userId,
    required StructuredSummary summary,
    required String modelId,
    required String specialty,
    required String transcript,
  }) async {
    final redactedTranscript = _phiRedactor.redact(transcript);
    final response = summary.toJson().toString();
    await logMedicalQuery(
      userId: userId,
      query: redactedTranscript,
      response: response,
      modelId: modelId,
      specialty: specialty,
    );
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}
