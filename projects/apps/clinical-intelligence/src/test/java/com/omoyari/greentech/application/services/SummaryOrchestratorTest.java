package com.omoyari.greentech.application.services;

import static org.junit.jupiter.api.Assertions.*;

import com.omoyari.greentech.api.SummaryRequest;
import com.omoyari.greentech.api.SummaryResponse;
import com.omoyari.greentech.application.ports.AuditLogPort;
import com.omoyari.greentech.application.ports.EncryptionPort;
import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.SummaryRepository;
import com.omoyari.greentech.application.ports.VectorStorePort;
import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.ConsultationInput;
import com.omoyari.greentech.core.MedicalReport;
import com.omoyari.greentech.core.StructuredSummary;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Unit tests for SummaryOrchestrator using manual stub implementations
 * (avoids ByteBuddy/Mockito JDK 25 compatibility issues).
 */
class SummaryOrchestratorTest {

    private SummaryOrchestrator orchestrator;
    private StubSummaryRepository repository;
    private StubLlmPort llmPort;
    private StubVectorStorePort vectorStorePort;
    private StubAuditLogPort auditLog;

    private static final StructuredSummary MOCK_SUMMARY = new StructuredSummary(
            "Excessive daytime sleepiness for 6 months",
            "Type 2 DM on Metformin, HTN on Telmisartan",
            "BP: 142/88 mmHg, HR: 78 bpm, SpO2: 94%, BMI: 31.8",
            "Mallampati III, neck circumference 42cm, retrognathia",
            "Level 1 PSG: AHI 34.2, Min SpO2 78%, Sleep Efficiency 68.5%",
            "Severe OSA (G47.33), Obesity Class I (E66.01), T2DM (E11.65)",
            "1. CPAP initiation at 10 cmH2O\n2. Weight reduction\n3. Follow-up 4 weeks");

    @BeforeEach
    void setUp() {
        repository = new StubSummaryRepository();
        llmPort = new StubLlmPort(MOCK_SUMMARY);
        vectorStorePort = new StubVectorStorePort();
        auditLog = new StubAuditLogPort();
        StubEncryptionPort encryptionPort = new StubEncryptionPort();

        orchestrator = new SummaryOrchestrator(
                repository, llmPort, vectorStorePort, encryptionPort, new ValidationService(), auditLog);
    }

    @Test
    void testBasicSummarization() {
        SummaryRequest request = createSampleRequest();

        SummaryResponse response = orchestrator.summarize(request, "doctor", false);

        assertNotNull(response);
        assertNotNull(response.getSummaryId());
        assertEquals("PAT-2024-0042", response.getPatientId());
        assertEquals("DR-SINGH-001", response.getDoctorId());
        assertFalse(response.isContextEnriched());

        StructuredSummary summary = response.getSummary();
        assertNotNull(summary);
        assertTrue(summary.isComplete());
        assertTrue(summary.getComplaint().contains("sleepiness"));
        assertTrue(summary.getDiagnosis().contains("OSA"));

        // Verify LLM was called with basic method
        assertTrue(llmPort.generateStructuredCalled);
        assertFalse(llmPort.generateContextEnrichedCalled);

        // Verify embedding was stored
        assertEquals(1, vectorStorePort.storedEmbeddings.size());
        assertEquals("DR-SINGH-001", vectorStorePort.storedEmbeddings.get(0).doctorId);

        // Verify summary was persisted
        assertEquals(1, repository.savedSummaries.size());

        // Verify audit log
        assertTrue(auditLog.summaryGenerations.size() > 0);
    }

    @Test
    void testContextEnrichedSummarization() {
        // Seed vector store with past context
        vectorStorePort.contextToReturn = List.of(
                "Previous patient: Mild OSA, CPAP at 8 cmH2O, good compliance",
                "Previous patient: Moderate OSA with positional component");

        SummaryRequest request = createSampleRequest();

        SummaryResponse response = orchestrator.summarize(request, "doctor", true);

        assertNotNull(response);
        assertTrue(response.isContextEnriched());

        // Verify context-enriched LLM method was called
        assertTrue(llmPort.generateContextEnrichedCalled);
        assertNotNull(llmPort.lastPastContext);
        assertTrue(llmPort.lastPastContext.contains("CPAP at 8 cmH2O"));
    }

    @Test
    void testContextEnrichedWithNoHistory() {
        // Empty context
        vectorStorePort.contextToReturn = Collections.emptyList();

        SummaryRequest request = createSampleRequest();

        SummaryResponse response = orchestrator.summarize(request, "doctor", true);

        assertNotNull(response);
        assertTrue(llmPort.generateContextEnrichedCalled);
        assertTrue(llmPort.lastPastContext.contains("No prior consultation history"));
    }

    @Test
    void testValidationFailsForMissingChiefComplaint() {
        SummaryRequest request = createSampleRequest();
        request.getConsultation().setChiefComplaint(null);

        assertThrows(
                com.omoyari.greentech.common.ValidationFailedException.class,
                () -> orchestrator.summarize(request, "doctor", false));
    }

    @Test
    void testValidationFailsForMissingPatientId() {
        SummaryRequest request = createSampleRequest();
        request.getConsultation().setPatientId(null);

        assertThrows(
                com.omoyari.greentech.common.ValidationFailedException.class,
                () -> orchestrator.summarize(request, "doctor", false));
    }

    @Test
    void testIncrementalVectorStoreStorage() {
        SummaryRequest request = createSampleRequest();

        orchestrator.summarize(request, "doctor", false);

        assertEquals(1, vectorStorePort.storedEmbeddings.size());
        var stored = vectorStorePort.storedEmbeddings.get(0);
        assertEquals("DR-SINGH-001", stored.doctorId);
        assertTrue(stored.content.contains("Complaint:"));
        assertTrue(stored.content.contains("Diagnosis:"));
        assertEquals("PAT-2024-0042", stored.metadata.get("patientId"));
    }

    // --- Helper ---

    private SummaryRequest createSampleRequest() {
        ConsultationInput input = new ConsultationInput();
        input.setPatientId("PAT-2024-0042");
        input.setDoctorId("DR-SINGH-001");
        input.setChiefComplaint("Excessive daytime sleepiness for 6 months");
        input.setPastMedicalHistory("Type 2 DM, Hypertension");
        input.setPhysicalExamination("Mallampati III, neck circumference 42cm");

        ConsultationInput.Vitals vitals = new ConsultationInput.Vitals();
        vitals.setBp("142/88 mmHg");
        vitals.setHr("78 bpm");
        vitals.setSpo2("94%");
        vitals.setBmi("31.8");
        input.setVitals(vitals);

        SummaryRequest request = new SummaryRequest();
        request.setPatientId("PAT-2024-0042");
        request.setDoctorId("DR-SINGH-001");
        request.setConsultation(input);
        return request;
    }

    // --- Stub Implementations ---

    static class StubSummaryRepository implements SummaryRepository {
        final List<ClinicalSummary> savedSummaries = new ArrayList<>();

        @Override
        public Optional<MedicalReport> findReportById(String reportId) {
            return Optional.empty();
        }

        @Override
        public void saveSummary(ClinicalSummary summary) {
            savedSummaries.add(summary);
        }

        @Override
        public Optional<ClinicalSummary> findSummaryById(String summaryId) {
            return savedSummaries.stream()
                    .filter(s -> s.getId().equals(summaryId))
                    .findFirst();
        }

        @Override
        public List<ClinicalSummary> findSummariesByDoctorId(String doctorId) {
            return savedSummaries.stream()
                    .filter(s -> doctorId.equals(s.getDoctorId()))
                    .toList();
        }
    }

    static class StubLlmPort implements LlmPort {
        private final StructuredSummary summaryToReturn;
        boolean generateStructuredCalled = false;
        boolean generateContextEnrichedCalled = false;
        String lastPastContext = null;

        StubLlmPort(StructuredSummary summaryToReturn) {
            this.summaryToReturn = summaryToReturn;
        }

        @Override
        public StructuredSummary generateStructuredSummary(String consultationJson) {
            generateStructuredCalled = true;
            return summaryToReturn;
        }

        @Override
        public StructuredSummary generateContextEnrichedSummary(String consultationJson, String pastContext) {
            generateContextEnrichedCalled = true;
            lastPastContext = pastContext;
            return summaryToReturn;
        }
    }

    record StoredEmbedding(String doctorId, String content, Map<String, String> metadata) {}

    static class StubVectorStorePort implements VectorStorePort {
        final List<StoredEmbedding> storedEmbeddings = new ArrayList<>();
        List<String> contextToReturn = Collections.emptyList();

        @Override
        public void storeEmbedding(String doctorId, String content, Map<String, String> metadata) {
            storedEmbeddings.add(new StoredEmbedding(doctorId, content, new HashMap<>(metadata)));
        }

        @Override
        public List<String> retrieveRelevantContext(String doctorId, String query, int maxResults) {
            return contextToReturn;
        }
    }

    static class StubEncryptionPort implements EncryptionPort {
        @Override
        public String encrypt(String plaintext) {
            return "ENC:" + plaintext;
        }

        @Override
        public String decrypt(String ciphertext) {
            return ciphertext.replace("ENC:", "");
        }
    }

    static class StubAuditLogPort implements AuditLogPort {
        final List<String[]> summaryGenerations = new ArrayList<>();

        @Override
        public void logDecryptionAccess(String documentId, String userId) {}

        @Override
        public void logSummaryGeneration(String patientId, String summaryId) {
            summaryGenerations.add(new String[] {patientId, summaryId});
        }

        @Override
        public void logUnauthorizedAccessAttempt(String resourceId, String userId) {}
    }
}
