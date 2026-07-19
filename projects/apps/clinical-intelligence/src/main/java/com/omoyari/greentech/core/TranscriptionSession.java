package com.omoyari.greentech.core;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Domain model tracking an active or completed transcription session.
 * Used by both the Agora video call pipeline and the in-person note-taker.
 */
public class TranscriptionSession {

    public enum Status {
        STARTED, IN_PROGRESS, COMPLETED, FAILED
    }

    public enum Source {
        AGORA_VIDEO_CALL, IN_PERSON_RECORDING
    }

    private final String sessionId;
    private final String channelName;  // Agora channel name (null for in-person)
    private final String doctorId;
    private final String patientId;
    private final String languageCode;
    private final Source source;
    private Status status;
    private final List<TranscriptionSegment> segments;
    private final Instant startedAt;
    private Instant completedAt;
    private String agoraTaskId;        // Agora RTT agent task ID (null for in-person)

    public TranscriptionSession(String sessionId, String channelName, String doctorId,
                                 String patientId, String languageCode, Source source) {
        this.sessionId = sessionId;
        this.channelName = channelName;
        this.doctorId = doctorId;
        this.patientId = patientId;
        this.languageCode = languageCode;
        this.source = source;
        this.status = Status.STARTED;
        this.segments = new ArrayList<>();
        this.startedAt = Instant.now();
    }

    public void addSegment(TranscriptionSegment segment) {
        this.segments.add(segment);
        if (this.status == Status.STARTED) {
            this.status = Status.IN_PROGRESS;
        }
    }

    public void markCompleted() {
        this.status = Status.COMPLETED;
        this.completedAt = Instant.now();
    }

    public void markFailed() {
        this.status = Status.FAILED;
        this.completedAt = Instant.now();
    }

    /**
     * Build the full raw transcript from all final segments, ordered by timestamp.
     */
    public String buildRawTranscript() {
        StringBuilder sb = new StringBuilder();
        segments.stream()
                .filter(TranscriptionSegment::isFinal)
                .forEach(seg -> {
                    sb.append("[").append(seg.getSpeakerLabel()).append("]: ");
                    sb.append(seg.getText()).append("\n");
                });
        return sb.toString().trim();
    }

    // --- Getters ---
    public String getSessionId() { return sessionId; }
    public String getChannelName() { return channelName; }
    public String getDoctorId() { return doctorId; }
    public String getPatientId() { return patientId; }
    public String getLanguageCode() { return languageCode; }
    public Source getSource() { return source; }
    public Status getStatus() { return status; }
    public List<TranscriptionSegment> getSegments() { return Collections.unmodifiableList(segments); }
    public Instant getStartedAt() { return startedAt; }
    public Instant getCompletedAt() { return completedAt; }
    public String getAgoraTaskId() { return agoraTaskId; }
    public void setAgoraTaskId(String agoraTaskId) { this.agoraTaskId = agoraTaskId; }
}
