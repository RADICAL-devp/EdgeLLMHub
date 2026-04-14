package com.omoyari.greentech.application.services;

import com.omoyari.greentech.api.SummaryRequest;
import com.omoyari.greentech.api.SummaryResponse;
import com.omoyari.greentech.application.ports.AuditLogPort;
import com.omoyari.greentech.application.ports.KmsPort;
import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.SummaryRepository;
import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.DecryptedPayload;
import com.omoyari.greentech.core.MedicalReport;
import jakarta.inject.Singleton;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Singleton
public class SummaryOrchestrator {
    private static final Logger LOG = LoggerFactory.getLogger(SummaryOrchestrator.class);

    private final SummaryRepository repository;
    private final KmsPort kmsPort;
    private final PromptCompressionEngine compressionEngine;
    private final LlmPort llmPort;
    private final ValidationService validationService;
    private final AuditLogPort auditLog;

    public SummaryOrchestrator(
            SummaryRepository repository,
            KmsPort kmsPort,
            PromptCompressionEngine compressionEngine,
            LlmPort llmPort,
            ValidationService validationService,
            AuditLogPort auditLog) {
        this.repository = repository;
        this.kmsPort = kmsPort;
        this.compressionEngine = compressionEngine;
        this.llmPort = llmPort;
        this.validationService = validationService;
        this.auditLog = auditLog;
    }

    public SummaryResponse summarizePatientHistory(SummaryRequest request, String requestingUserId) {
        LOG.info("Starting summary orchestration for user: {}", requestingUserId);
        validationService.validateSummaryRequest(request.getDocumentIds().toArray(new String[0]));

        StringBuilder aggregatedContent = new StringBuilder();
        String patientId = null;

        for (String docId : request.getDocumentIds()) {
            Optional<MedicalReport> reportOpt = repository.findReportById(docId);
            if (reportOpt.isPresent()) {
                MedicalReport report = reportOpt.get();
                patientId = report.getPatientId();

                auditLog.logDecryptionAccess(docId, requestingUserId);
                DecryptedPayload payload = kmsPort.decrypt(report.getEncryptedPayload());
                aggregatedContent.append(payload.getContent()).append(" ");
            }
        }

        String compressedPrompt = compressionEngine.compress(aggregatedContent.toString());

        // Resilience hook placeholder: Retry/CircuitBreaker annotations can be added here
        String llmResponse = llmPort.generateSummary(compressedPrompt);

        validationService.validateLlmResponse(llmResponse);

        String summaryId = UUID.randomUUID().toString();
        ClinicalSummary summary = new ClinicalSummary(
                summaryId,
                patientId != null ? patientId : "UNKNOWN",
                llmResponse,
                Instant.now().toString());

        repository.saveSummary(summary);
        auditLog.logSummaryGeneration(summary.getPatientId(), summaryId);

        return new SummaryResponse(summaryId, llmResponse);
    }
}
