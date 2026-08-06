import 'dart:async';
import 'package:clinical_intelligence_dart/core/audit/audit_event.dart';
import 'package:clinical_intelligence_dart/core/audit/phi_redactor.dart';
import 'package:clinical_intelligence_dart/infrastructure/persistence/clinical_database.dart';

/// Async buffered audit logger with Drift persistence.
class AuditLogger {
  AuditLogger(this._database, {
    this.batchSize = 100,
    this.flushInterval = const Duration(seconds: 5),
  });

  final ClinicalDatabase _database;
  final int batchSize;
  final Duration flushInterval;

  final _buffer = <AuditEvent>[];
  Timer? _flushTimer;
  bool _disposed = false;

  /// Log an audit event (non-blocking).
  void log(AuditEvent event) {
    if (_disposed) return;
    _buffer.add(event);
    if (_buffer.length >= batchSize) {
      _flush();
    } else if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(flushInterval, _flush);
    }
  }

  /// Log a clinical processing request/response.
  void logClinicalProcessing({
    required String correlationId,
    required AuthContext auth,
    required String action,
    required String resource,
    required String resourceId,
    required String outcome,
    Map<String, dynamic>? metadata,
  }) {
    final event = AuditEvent(
      id: _generateId(),
      timestamp: DateTime.now().toUtc(),
      userId: auth.doctorId,
      clinicId: auth.clinicId,
      action: action,
      resource: resource,
      resourceId: resourceId,
      outcome: outcome,
      metadataJson: metadata != null ? _redactor.redactJson(metadata) as String? : null,
      correlationId: correlationId,
    );
    log(event);
  }

  /// Flush buffered events to database.
  Future<void> _flush() async {
    if (_buffer.isEmpty || _disposed) return;

    final events = List<AuditEvent>.from(_buffer);
    _buffer.clear();
    _flushTimer?.cancel();
    _flushTimer = null;

    try {
      await _database.batch((batch) {
        for (final event in events) {
          batch.insert(_database.auditLogs, AuditLogsCompanion.insert(
            correlationId: event.correlationId,
            userId: Value(event.userId),
            clinicId: Value(event.clinicId),
            action: event.action,
            resource: event.resource,
            resourceId: Value(event.resourceId),
            outcome: event.outcome,
            metadataJson: Value(event.metadataJson),
            timestamp: event.timestamp,
          ));
        }
      });
    } catch (e) {
      // Re-buffer on failure (with limit to prevent memory growth)
      _buffer.insertAll(0, events.take(1000));
      // Log error but don't throw - audit logging must not break the app
      print('[AuditLogger] Failed to flush: $e');
    }
  }

  /// Force flush and wait for completion.
  Future<void> flush() async {
    await _flush();
  }

  /// Dispose the logger.
  Future<void> dispose() async {
    _disposed = true;
    _flushTimer?.cancel();
    await _flush();
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  final _redactor = PhiRedactor();
}

/// Auth context for audit logging (matches auth_middleware.dart).
class AuthContext {
  final String doctorId;
  final String clinicId;
  final List<String> roles;
  final List<String> scopes;
  final DateTime expiresAt;
  final DateTime issuedAt;

  AuthContext({
    required this.doctorId,
    required this.clinicId,
    required this.roles,
    required this.scopes,
    required this.expiresAt,
    required this.issuedAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool hasScope(String scope) => scopes.contains(scope);
  bool hasAllScopes(List<String> required) => required.every((s) => scopes.contains(s));
}
