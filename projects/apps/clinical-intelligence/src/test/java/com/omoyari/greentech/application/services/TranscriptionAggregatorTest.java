package com.omoyari.greentech.application.services;

import com.omoyari.greentech.core.TranscriptionSession;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for TranscriptionAggregator.
 * Validates session management, segment aggregation, and transcript building.
 */
class TranscriptionAggregatorTest {

    private TranscriptionAggregator aggregator;

    @BeforeEach
    void setUp() {
        aggregator = new TranscriptionAggregator();
    }

    @Test
    void createSession_returnsSessionWithCorrectProperties() {
        TranscriptionSession session = aggregator.createSession(
                "test-channel", "DR-001", "PAT-001", "hi-IN",
                TranscriptionSession.Source.AGORA_VIDEO_CALL);

        assertNotNull(session.getSessionId());
        assertEquals("test-channel", session.getChannelName());
        assertEquals("DR-001", session.getDoctorId());
        assertEquals("PAT-001", session.getPatientId());
        assertEquals("hi-IN", session.getLanguageCode());
        assertEquals(TranscriptionSession.Source.AGORA_VIDEO_CALL, session.getSource());
        assertEquals(TranscriptionSession.Status.STARTED, session.getStatus());
    }

    @Test
    void addSegment_updatesSessionStatusToInProgress() {
        TranscriptionSession session = aggregator.createSession(
                null, "DR-002", "PAT-002", "ta-IN",
                TranscriptionSession.Source.IN_PERSON_RECORDING);

        assertEquals(TranscriptionSession.Status.STARTED, session.getStatus());

        aggregator.addSegment(session.getSessionId(), "DOCTOR",
                "Patient ka blood pressure check karo", "hi-IN", true);

        assertEquals(TranscriptionSession.Status.IN_PROGRESS, session.getStatus());
        assertEquals(1, session.getSegments().size());
    }

    @Test
    void completeSession_buildsRawTranscript() {
        TranscriptionSession session = aggregator.createSession(
                "channel-1", "DR-003", "PAT-003", "en-US",
                TranscriptionSession.Source.AGORA_VIDEO_CALL);

        aggregator.addSegment(session.getSessionId(), "DOCTOR",
                "What brings you in today?", "en-US", true);
        aggregator.addSegment(session.getSessionId(), "PATIENT",
                "I have been having headaches for a week.", "en-US", true);
        aggregator.addSegment(session.getSessionId(), "DOCTOR",
                "Any nausea or visual disturbances?", "en-US", true);

        String transcript = aggregator.completeSession(session.getSessionId());

        assertTrue(transcript.contains("[DOCTOR]: What brings you in today?"));
        assertTrue(transcript.contains("[PATIENT]: I have been having headaches for a week."));
        assertTrue(transcript.contains("[DOCTOR]: Any nausea or visual disturbances?"));
        assertEquals(TranscriptionSession.Status.COMPLETED, session.getStatus());
    }

    @Test
    void completeSession_excludesInterimSegments() {
        TranscriptionSession session = aggregator.createSession(
                "channel-2", "DR-004", "PAT-004", "en-US",
                TranscriptionSession.Source.AGORA_VIDEO_CALL);

        // Add interim (non-final) segment — should NOT appear in transcript
        aggregator.addSegment(session.getSessionId(), "DOCTOR",
                "partial text...", "en-US", false);
        // Add final segment — should appear
        aggregator.addSegment(session.getSessionId(), "DOCTOR",
                "What is your blood pressure?", "en-US", true);

        String transcript = aggregator.completeSession(session.getSessionId());

        assertFalse(transcript.contains("partial text..."));
        assertTrue(transcript.contains("What is your blood pressure?"));
    }

    @Test
    void addSegment_ignoresUnknownSessionId() {
        // Should not throw
        aggregator.addSegment("non-existent-id", "DOCTOR", "text", "en-US", true);
    }

    @Test
    void buildConsultationTextFromTranscript_containsMetadata() {
        String text = aggregator.buildConsultationTextFromTranscript(
                "[DOCTOR]: Headache complaint\n[PATIENT]: Yes, severe", "DR-005", "PAT-005");

        assertTrue(text.contains("Doctor ID: DR-005"));
        assertTrue(text.contains("Patient ID: PAT-005"));
        assertTrue(text.contains("[DOCTOR]: Headache complaint"));
    }

    @Test
    void getSession_returnsNullForUnknownId() {
        assertNull(aggregator.getSession("unknown-session"));
    }

    @Test
    void removeSession_removesFromStore() {
        TranscriptionSession session = aggregator.createSession(
                null, "DR-006", "PAT-006", "en-US",
                TranscriptionSession.Source.IN_PERSON_RECORDING);

        assertNotNull(aggregator.getSession(session.getSessionId()));
        aggregator.removeSession(session.getSessionId());
        assertNull(aggregator.getSession(session.getSessionId()));
    }
}
