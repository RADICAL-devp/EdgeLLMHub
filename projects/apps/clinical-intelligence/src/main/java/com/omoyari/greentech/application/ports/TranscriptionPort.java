package com.omoyari.greentech.application.ports;

/**
 * Port for managing real-time transcription sessions (e.g., Agora RTT).
 * Controls the lifecycle of a transcription agent in a video call channel.
 */
public interface TranscriptionPort {

    /**
     * Start a real-time transcription agent in the given channel.
     *
     * @param channelName The Agora channel to join
     * @param doctorId    The doctor who owns this session
     * @param languageCode BCP-47 language code (e.g., "hi-IN" for Hindi)
     * @return A unique task/session ID for managing this transcription
     */
    String startTranscription(String channelName, String doctorId, String languageCode);

    /**
     * Stop an active transcription agent.
     *
     * @param taskId The task ID returned by startTranscription
     */
    void stopTranscription(String taskId);

    /**
     * Query the status of a running transcription.
     *
     * @param taskId The task ID
     * @return Status string (e.g., "STARTED", "IN_PROGRESS", "STOPPED")
     */
    String getTranscriptionStatus(String taskId);
}
