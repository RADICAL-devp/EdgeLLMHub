package com.omoyari.greentech.application.ports;

public interface AuditLogPort {
    void logDecryptionAccess(String documentId, String userId);

    void logSummaryGeneration(String patientId, String summaryId);

    void logUnauthorizedAccessAttempt(String resourceId, String userId);
}
