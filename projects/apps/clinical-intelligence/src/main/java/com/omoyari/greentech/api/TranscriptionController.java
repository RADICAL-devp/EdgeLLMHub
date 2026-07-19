package com.omoyari.greentech.api;

import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.TranscriptionPort;
import com.omoyari.greentech.application.services.TranscriptionAggregator;
import com.omoyari.greentech.core.StructuredSummary;
import com.omoyari.greentech.core.TranscriptionSession;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.*;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.rules.SecurityRule;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * REST controller for Agora video call transcription management.
 *
 * Endpoints:
 *   POST /api/v1/transcription/start         → Start RTT for a channel
 *   POST /api/v1/transcription/stop/{id}      → Stop RTT and optionally auto-summarize
 *   GET  /api/v1/transcription/status/{id}    → Get session status + partial transcript
 *   POST /api/v1/transcription/webhook        → Receive Agora transcript segments
 *   POST /api/v1/transcription/{id}/summarize → Manual trigger: summarize current transcript
 */
@Controller("/api/v1/transcription")
@Secured(SecurityRule.IS_AUTHENTICATED)
public class TranscriptionController {

    private static final Logger LOG = LoggerFactory.getLogger(TranscriptionController.class);

    private final TranscriptionPort transcriptionPort;
    private final TranscriptionAggregator aggregator;
    private final LlmPort llmPort;

    public TranscriptionController(TranscriptionPort transcriptionPort,
                                    TranscriptionAggregator aggregator,
                                    LlmPort llmPort) {
        this.transcriptionPort = transcriptionPort;
        this.aggregator = aggregator;
        this.llmPort = llmPort;
    }

    /**
     * Start real-time transcription for a video call channel.
     */
    @Post("/start")
    public HttpResponse<Map<String, String>> startTranscription(@Body StartTranscriptionRequest request) {
        LOG.info("Starting transcription for channel={}, doctor={}", request.channelName(), request.doctorId());

        // Create an aggregation session
        TranscriptionSession session = aggregator.createSession(
                request.channelName(), request.doctorId(), request.patientId(),
                request.languageCode(), TranscriptionSession.Source.AGORA_VIDEO_CALL);

        // Start Agora RTT agent
        String agoraTaskId = transcriptionPort.startTranscription(
                request.channelName(), request.doctorId(), request.languageCode());
        session.setAgoraTaskId(agoraTaskId);

        return HttpResponse.ok(Map.of(
                "sessionId", session.getSessionId(),
                "agoraTaskId", agoraTaskId,
                "status", "STARTED"));
    }

    /**
     * Stop transcription and optionally auto-summarize.
     */
    @Post("/stop/{sessionId}")
    public HttpResponse<Map<String, Object>> stopTranscription(
            @PathVariable String sessionId,
            @QueryValue(defaultValue = "true") boolean autoSummarize) {

        LOG.info("Stopping transcription: session={}, autoSummarize={}", sessionId, autoSummarize);

        TranscriptionSession session = aggregator.getSession(sessionId);
        if (session == null) {
            return HttpResponse.notFound();
        }

        // Stop Agora RTT agent
        if (session.getAgoraTaskId() != null) {
            transcriptionPort.stopTranscription(session.getAgoraTaskId());
        }

        // Complete the session and get raw transcript
        String rawTranscript = aggregator.completeSession(sessionId);

        Map<String, Object> response = new java.util.HashMap<>(Map.of(
                "sessionId", sessionId,
                "status", "COMPLETED",
                "transcript", rawTranscript,
                "segmentCount", session.getSegments().size()));

        // Auto-summarize if requested
        if (autoSummarize && !rawTranscript.isBlank()) {
            String consultationText = aggregator.buildConsultationTextFromTranscript(
                    rawTranscript, session.getDoctorId(), session.getPatientId());
            StructuredSummary summary = llmPort.generateStructuredSummary(consultationText);
            response.put("summary", summary);
        }

        return HttpResponse.ok(response);
    }

    /**
     * Get the current status and partial transcript of an active session.
     */
    @Get("/status/{sessionId}")
    public HttpResponse<Map<String, Object>> getStatus(@PathVariable String sessionId) {
        TranscriptionSession session = aggregator.getSession(sessionId);
        if (session == null) {
            return HttpResponse.notFound();
        }

        return HttpResponse.ok(Map.of(
                "sessionId", sessionId,
                "status", session.getStatus().name(),
                "segmentCount", session.getSegments().size(),
                "partialTranscript", session.buildRawTranscript(),
                "source", session.getSource().name(),
                "startedAt", session.getStartedAt().toString()));
    }

    /**
     * Webhook endpoint for receiving Agora transcript segments.
     * This is called by the frontend when it receives Stream Messages from the RTT agent.
     * Open access since Agora/frontend sends these without JWT.
     */
    @Post("/webhook")
    @Secured(SecurityRule.IS_ANONYMOUS)
    public HttpResponse<Void> receiveWebhook(@Body WebhookPayload payload) {
        LOG.debug("Webhook received: session={}, speaker={}", payload.sessionId(), payload.speakerLabel());

        aggregator.addSegment(
                payload.sessionId(),
                payload.speakerLabel(),
                payload.text(),
                payload.languageCode(),
                payload.isFinal());

        return HttpResponse.ok();
    }

    /**
     * Manually trigger summarization of the current transcript.
     */
    @Post("/{sessionId}/summarize")
    public HttpResponse<Map<String, Object>> manualSummarize(@PathVariable String sessionId) {
        LOG.info("Manual summarization triggered for session={}", sessionId);

        TranscriptionSession session = aggregator.getSession(sessionId);
        if (session == null) {
            return HttpResponse.notFound();
        }

        String rawTranscript = session.buildRawTranscript();
        if (rawTranscript.isBlank()) {
            return HttpResponse.badRequest(Map.of("error", "No transcript segments available yet"));
        }

        String consultationText = aggregator.buildConsultationTextFromTranscript(
                rawTranscript, session.getDoctorId(), session.getPatientId());
        StructuredSummary summary = llmPort.generateStructuredSummary(consultationText);

        return HttpResponse.ok(Map.of(
                "sessionId", sessionId,
                "summary", summary,
                "transcriptLength", rawTranscript.length()));
    }

    // ---- Request/Response Records ----

    public record StartTranscriptionRequest(
            String channelName,
            String doctorId,
            String patientId,
            String languageCode
    ) {}

    public record WebhookPayload(
            String sessionId,
            String speakerLabel,
            String text,
            String languageCode,
            boolean isFinal
    ) {}
}
