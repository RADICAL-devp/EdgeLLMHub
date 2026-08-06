/// Audit event for compliance logging.
class AuditEvent {
  AuditEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.clinicId,
    required this.action,
    required this.resource,
    this.resourceId,
    required this.outcome,
    this.metadataJson,
    required this.correlationId,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String,
      clinicId: json['clinicId'] as String,
      action: json['action'] as String,
      resource: json['resource'] as String,
      resourceId: json['resourceId'] as String?,
      outcome: json['outcome'] as String,
      metadataJson: json['metadataJson'] as String?,
      correlationId: json['correlationId'] as String,
    );
  }

  final String id;
  final DateTime timestamp;
  final String userId;
  final String clinicId;
  final String action;
  final String resource;
  final String? resourceId;
  final String outcome; // 'success', 'failure', 'error'
  final String? metadataJson;
  final String correlationId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'clinicId': clinicId,
        'action': action,
        'resource': resource,
        'resourceId': resourceId,
        'outcome': outcome,
        'metadataJson': metadataJson,
        'correlationId': correlationId,
      };
}

/// Audit action types.
class AuditAction {
  static const clinicalProcessing = 'clinical_processing';
  static const transcriptSummaryGenerate = 'transcript_summary_generate';
  static const transcriptSummaryGet = 'transcript_summary_get';
  static const transcriptSummaryRegenerate = 'transcript_summary_regenerate';
  static const modelInitialize = 'model_initialize';
  static const authLogin = 'auth_login';
  static const authTokenRefresh = 'auth_token_refresh';
  static const dataExport = 'data_export';
  static const adminAction = 'admin_action';
}

/// Audit resource types.
class AuditResource {
  static const clinicalProcessing = 'clinical_processing';
  static const transcriptSummary = 'transcript_summary';
  static const consultation = 'consultation';
  static const model = 'model';
  static const auth = 'auth';
  static const system = 'system';
}

/// Audit outcome types.
class AuditOutcome {
  static const success = 'success';
  static const failure = 'failure';
  static const error = 'error';
  static const unauthorized = 'unauthorized';
  static const forbidden = 'forbidden';
}
