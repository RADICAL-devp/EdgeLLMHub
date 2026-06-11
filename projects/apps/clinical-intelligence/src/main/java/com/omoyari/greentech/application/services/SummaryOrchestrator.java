package com.omoyari.greentech.application.services;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.omoyari.greentech.api.SummaryRequest;
import com.omoyari.greentech.api.SummaryResponse;
import com.omoyari.greentech.application.ports.AuditLogPort;
import com.omoyari.greentech.application.ports.EncryptionPort;
import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.SummaryRepository;
import com.omoyari.greentech.application.ports.VectorStorePort;
import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.StructuredSummary;
import jakarta.inject.Singleton;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Orchestrates the clinical summarization pipeline:
 * 1. Validate input
 * 2. Serialize consultation to JSON for the LLM
 * 3. Optionally retrieve past context from vector store (doctor-specific)
 * 4. Invoke LangChain4J for structured summarization
 * 5. Validate output
 * 6. Encrypt and persist the summary
 * 7. Incrementally store embedding in vector store for future context
 * 8. Audit log everything
 */
@Singleton
public class SummaryOrchestrator {
    private static final Logger LOG = LoggerFactory.getLogger(SummaryOrchestrator.class);

    private final SummaryRepository repository;
    private final LlmPort llmPort;
    private final VectorStorePort vectorStorePort;
    private final EncryptionPort encryptionPort;
    private final ValidationService validationService;
    private final AuditLogPort auditLog;
    private final ObjectMapper objectMapper;

    public SummaryOrchestrator(
            SummaryRepository repository,
            LlmPort llmPort,
            VectorStorePort vectorStorePort,
            EncryptionPort encryptionPort,
            ValidationService validationService,
            AuditLogPort auditLog) {
        this.repository = repository;
        this.llmPort = llmPort;
        this.vectorStorePort = vectorStorePort;
        this.encryptionPort = encryptionPort;
        this.validationService = validationService;
        this.auditLog = auditLog;
        this.objectMapper = new ObjectMapper();
    }

    /**
     * Main summarization flow.
     *
     * @param request        The summary request with consultation data
     * @param requestingUser The authenticated user (doctor) making the request
     * @param useContext      Whether to retrieve past context from the vector store
     * @return The structured summary response
     */
    public SummaryResponse summarize(SummaryRequest request, String requestingUser, boolean useContext) {
        LOG.info(
                "Starting summarization for patient={}, doctor={}, useContext={}",
                request.getPatientId(),
                request.getDoctorId(),
                useContext);

        // 1. Validate input
        validationService.validateConsultationInput(request.getConsultation());

        // 2. Serialize consultation to JSON string for the LLM
        String consultationJson = serializeToJson(request.getConsultation());
        validationService.validatePayloadSize(consultationJson);

        // 3. Generate structured summary
        StructuredSummary structuredSummary;
        if (useContext) {
            // Retrieve past context from vector store for this doctor
            List<String> pastContext =
                    vectorStorePort.retrieveRelevantContext(request.getDoctorId(), consultationJson, 3);
            String contextBlock = pastContext.isEmpty()
                    ? "No prior consultation history available for this doctor."
                    : String.join("\n\n---\n\n", pastContext);
            LOG.info("Retrieved {} context segments for doctor {}", pastContext.size(), request.getDoctorId());

            structuredSummary = llmPort.generateContextEnrichedSummary(consultationJson, contextBlock);
        } else {
            structuredSummary = llmPort.generateStructuredSummary(consultationJson);
        }

        // 4. Validate the LLM output
        validationService.validateStructuredSummary(structuredSummary);

        // 5. Persist the summary
        String summaryId = UUID.randomUUID().toString();
        String generatedAt = Instant.now().toString();

        ClinicalSummary clinicalSummary = new ClinicalSummary(
                summaryId, request.getPatientId(), request.getDoctorId(), structuredSummary, generatedAt);

        repository.saveSummary(clinicalSummary);

        // 6. Incrementally store in vector store for future context enrichment
        String summaryText = buildSummaryText(structuredSummary);
        vectorStorePort.storeEmbedding(
                request.getDoctorId(),
                summaryText,
                Map.of(
                        "patientId", request.getPatientId(),
                        "summaryId", summaryId,
                        "generatedAt", generatedAt));

        // 7. Audit logging
        auditLog.logSummaryGeneration(request.getPatientId(), summaryId);

        LOG.info("Summary generated successfully: summaryId={}", summaryId);

        return new SummaryResponse(
                summaryId, structuredSummary, generatedAt, request.getDoctorId(), request.getPatientId(), useContext);
    }

    /**
     * Retrieve a previously generated summary by its ID.
     */
    public SummaryResponse getSummaryById(String summaryId) {
        return repository
                .findSummaryById(summaryId)
                .map(cs -> new SummaryResponse(
                        cs.getId(),
                        cs.getStructuredSummary(),
                        cs.getGeneratedAt(),
                        cs.getDoctorId(),
                        cs.getPatientId(),
                        false))
                .orElseThrow(
                        () -> new com.omoyari.greentech.common.ValidationFailedException("Summary not found: " + summaryId));
    }

    /**
     * Retrieve all summaries for a given doctor.
     */
    public List<SummaryResponse> getSummariesByDoctor(String doctorId) {
        return repository.findSummariesByDoctorId(doctorId).stream()
                .map(cs -> new SummaryResponse(
                        cs.getId(),
                        cs.getStructuredSummary(),
                        cs.getGeneratedAt(),
                        cs.getDoctorId(),
                        cs.getPatientId(),
                        false))
                .collect(Collectors.toList());
    }

    private String serializeToJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (JsonProcessingException e) {
            throw new com.omoyari.greentech.common.ValidationFailedException(
                    "Failed to serialize consultation to JSON: " + e.getMessage());
        }
    }

    /**
     * Build a combined text representation of the structured summary for embedding.
     */
    private String buildSummaryText(StructuredSummary summary) {
        return "Complaint: " + summary.getComplaint() + "\n"
                + "Past History: " + summary.getPastHistory() + "\n"
                + "Vitals: " + summary.getVitals() + "\n"
                + "Physical Examination: " + summary.getPhysicalExamination() + "\n"
                + "Investigation Ordered: " + summary.getInvestigationOrdered() + "\n"
                + "Diagnosis: " + summary.getDiagnosis() + "\n"
                + "Advice: " + summary.getAdvice();
    }
}
