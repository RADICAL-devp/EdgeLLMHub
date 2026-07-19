package com.omoyari.greentech.application.services;

import com.omoyari.greentech.core.TranscriptionSegment;
import com.omoyari.greentech.core.TranscriptionSession;
import jakarta.inject.Singleton;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Manages active transcription sessions and aggregates incoming segments
 * into a coherent transcript. Sessions are stored in memory (for now)
 * and can be upgraded to Redis/DynamoDB for multi-instance deployments.
 *
 * Responsibilities:
 * - Create and track transcription sessions
 * - Receive and aggregate raw transcript segments
 * - Build the final raw transcript from completed sessions
 * - Convert transcripts to structured text for the summarization pipeline
 */
@Singleton
public class TranscriptionAggregator {

    private static final Logger LOG = LoggerFactory.getLogger(TranscriptionAggregator.class);

    // In-memory session store — swap to Redis for horizontal scaling
    private final Map<String, TranscriptionSession> activeSessions = new ConcurrentHashMap<>();

    /**
     * Create a new transcription session.
     */
    public TranscriptionSession createSession(String channelName, String doctorId,
                                               String patientId, String languageCode,
                                               TranscriptionSession.Source source) {
        String sessionId = UUID.randomUUID().toString();
        TranscriptionSession session = new TranscriptionSession(
                sessionId, channelName, doctorId, patientId, languageCode, source);
        activeSessions.put(sessionId, session);

        LOG.info("Created transcription session: id={}, doctor={}, source={}",
                sessionId, doctorId, source);
        return session;
    }

    /**
     * Add a transcript segment to an active session.
     */
    public void addSegment(String sessionId, String speakerLabel, String text,
                           String languageCode, boolean isFinal) {
        TranscriptionSession session = activeSessions.get(sessionId);
        if (session == null) {
            LOG.warn("Segment received for unknown session: {}", sessionId);
            return;
        }

        TranscriptionSegment segment = new TranscriptionSegment(
                speakerLabel, text, languageCode, Instant.now(), isFinal);
        session.addSegment(segment);

        LOG.debug("Added segment to session {}: speaker={}, final={}, length={}",
                sessionId, speakerLabel, isFinal, text.length());
    }

    /**
     * Complete a session and return the raw transcript.
     */
    public String completeSession(String sessionId) {
        TranscriptionSession session = activeSessions.get(sessionId);
        if (session == null) {
            throw new IllegalArgumentException("Session not found: " + sessionId);
        }

        session.markCompleted();
        String transcript = session.buildRawTranscript();

        LOG.info("Session completed: id={}, segments={}, transcript length={}",
                sessionId, session.getSegments().size(), transcript.length());
        return transcript;
    }

    /**
     * Get an active session by ID.
     */
    public TranscriptionSession getSession(String sessionId) {
        return activeSessions.get(sessionId);
    }

    /**
     * Remove a session from the active store.
     */
    public void removeSession(String sessionId) {
        activeSessions.remove(sessionId);
        LOG.debug("Removed session: {}", sessionId);
    }

    /**
     * Build a structured consultation text from a raw transcript suitable for
     * the LLM summarization pipeline. This wraps the transcript with context
     * so the LLM can extract the 7 required fields.
     */
    public String buildConsultationTextFromTranscript(String rawTranscript, String doctorId,
                                                      String patientId) {
        return """
                The following is a transcribed doctor-patient consultation.
                Doctor ID: %s
                Patient ID: %s

                --- TRANSCRIPT START ---
                %s
                --- TRANSCRIPT END ---

                Extract the following from this consultation transcript:
                chief complaint, history of present illness, past medical history,
                vitals mentioned, physical examination findings, investigations ordered,
                and any preliminary diagnosis or advice given.
                """.formatted(doctorId, patientId, rawTranscript);
    }
}
