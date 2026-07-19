package com.omoyari.greentech.core;

import java.time.Instant;

/**
 * Represents a single segment of transcribed speech from either
 * an Agora video call or an in-person recording.
 */
public class TranscriptionSegment {
    private final String speakerLabel;   // "DOCTOR", "PATIENT", or "UNKNOWN"
    private final String text;
    private final String languageCode;   // BCP-47 code, e.g. "hi-IN"
    private final Instant timestamp;
    private final boolean isFinal;       // true if this is a final transcript (not interim)

    public TranscriptionSegment(String speakerLabel, String text, String languageCode,
                                 Instant timestamp, boolean isFinal) {
        this.speakerLabel = speakerLabel;
        this.text = text;
        this.languageCode = languageCode;
        this.timestamp = timestamp;
        this.isFinal = isFinal;
    }

    public String getSpeakerLabel() { return speakerLabel; }
    public String getText() { return text; }
    public String getLanguageCode() { return languageCode; }
    public Instant getTimestamp() { return timestamp; }
    public boolean isFinal() { return isFinal; }

    @Override
    public String toString() {
        return "[" + speakerLabel + " @ " + timestamp + "] " + text;
    }
}
