package com.omoyari.greentech.infrastructure.audit;

import com.omoyari.greentech.application.ports.AuditLogPort;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Singleton
public class AuditLogService implements AuditLogPort {
    private static final Logger AUDIT_LOG = LoggerFactory.getLogger("AUDIT");

    @Override
    public void logDecryptionAccess(String documentId, String userId) {
        AUDIT_LOG.info("DECRYPTION_ACCESS | User: {} | Document: {}", userId, documentId);
    }

    @Override
    public void logSummaryGeneration(String patientId, String summaryId) {
        AUDIT_LOG.info("SUMMARY_GENERATED | Patient: {} | Summary: {}", patientId, summaryId);
    }

    @Override
    public void logUnauthorizedAccessAttempt(String resourceId, String userId) {
        AUDIT_LOG.warn("UNAUTHORIZED_ACCESS_ATTEMPT | User: {} | Resource: {}", userId, resourceId);
    }
}
