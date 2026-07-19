package com.omoyari.greentech.infrastructure.transcription;

import com.omoyari.greentech.application.ports.TranscriptionPort;
import com.omoyari.greentech.config.AgoraProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.inject.Singleton;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Agora Real-Time Transcription (RTT) service implementation.
 * Manages the lifecycle of transcription agents via Agora's REST API:
 *   1. Acquire → get a builder token
 *   2. Start  → launch the RTT agent in a channel
 *   3. Query  → check transcription status
 *   4. Stop   → terminate the agent
 *
 * Transcription results are delivered via Stream Messages to the channel,
 * which the frontend relays to our webhook endpoint.
 */
@Singleton
public class AgoraRttService implements TranscriptionPort {

    private static final Logger LOG = LoggerFactory.getLogger(AgoraRttService.class);
    private static final String BASE_URL = "https://api.agora.io/v1/projects/%s/rtsc/speech-to-text";
    private static final int RTT_UID = 999;  // Reserved UID for the RTT agent

    private final AgoraProperties properties;
    private final AgoraTokenGenerator tokenGenerator;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    public AgoraRttService(AgoraProperties properties, AgoraTokenGenerator tokenGenerator) {
        this.properties = properties;
        this.tokenGenerator = tokenGenerator;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        this.objectMapper = new ObjectMapper();
    }

    @Override
    public String startTranscription(String channelName, String doctorId, String languageCode) {
        LOG.info("Starting Agora RTT for channel={}, doctor={}, language={}", channelName, doctorId, languageCode);

        try {
            // Step 1: Acquire builder token
            String builderToken = acquire();
            LOG.debug("Acquired builder token for RTT");

            // Step 2: Generate RTC token for the RTT agent
            String rtcToken = tokenGenerator.generateRtcToken(channelName, RTT_UID, 1);

            // Step 3: Start the RTT agent
            String taskId = start(builderToken, channelName, rtcToken, languageCode);
            LOG.info("Agora RTT started: taskId={}", taskId);

            return taskId;

        } catch (Exception e) {
            LOG.error("Failed to start Agora RTT for channel={}", channelName, e);
            throw new RuntimeException("Agora RTT start failed: " + e.getMessage(), e);
        }
    }

    @Override
    public void stopTranscription(String taskId) {
        LOG.info("Stopping Agora RTT: taskId={}", taskId);

        try {
            String url = String.format(BASE_URL, properties.getAppId())
                    + "/tasks/" + taskId + "?builderToken=" + taskId;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Authorization", tokenGenerator.getBasicAuthHeader())
                    .header("Content-Type", "application/json")
                    .DELETE()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                LOG.info("Agora RTT stopped successfully: taskId={}", taskId);
            } else {
                LOG.warn("Agora RTT stop returned status {}: {}", response.statusCode(), response.body());
            }
        } catch (Exception e) {
            LOG.error("Failed to stop Agora RTT: taskId={}", taskId, e);
            throw new RuntimeException("Agora RTT stop failed: " + e.getMessage(), e);
        }
    }

    @Override
    public String getTranscriptionStatus(String taskId) {
        LOG.debug("Querying Agora RTT status: taskId={}", taskId);

        try {
            String url = String.format(BASE_URL, properties.getAppId())
                    + "/tasks/" + taskId + "?builderToken=" + taskId;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Authorization", tokenGenerator.getBasicAuthHeader())
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                JsonNode json = objectMapper.readTree(response.body());
                String status = json.path("status").asText("UNKNOWN");
                LOG.debug("Agora RTT status: taskId={}, status={}", taskId, status);
                return status;
            } else {
                LOG.warn("Agora RTT status query failed: {}", response.body());
                return "UNKNOWN";
            }
        } catch (Exception e) {
            LOG.error("Failed to query Agora RTT status: taskId={}", taskId, e);
            return "ERROR";
        }
    }

    // ---- Private helpers ----

    private String acquire() throws Exception {
        String url = String.format(BASE_URL, properties.getAppId()) + "/builderTokens";

        ObjectNode body = objectMapper.createObjectNode();
        body.put("instanceId", properties.getAppId());

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", tokenGenerator.getBasicAuthHeader())
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() == 200 || response.statusCode() == 201) {
            JsonNode json = objectMapper.readTree(response.body());
            return json.path("tokenName").asText();
        } else {
            throw new RuntimeException("Agora acquire failed (" + response.statusCode() + "): " + response.body());
        }
    }

    private String start(String builderToken, String channelName, String rtcToken,
                          String languageCode) throws Exception {
        String url = String.format(BASE_URL, properties.getAppId())
                + "/tasks?builderToken=" + builderToken;

        // Map BCP-47 codes to Agora-compatible language strings
        String agoraLang = mapToAgoraLanguage(languageCode);

        ObjectNode body = objectMapper.createObjectNode();

        // Audio config
        ObjectNode audio = body.putObject("audio");
        audio.put("subscribeSource", "AGORARTC");
        ObjectNode agoraRtc = audio.putObject("agoraRtcConfig");
        agoraRtc.put("channelName", channelName);
        agoraRtc.put("uid", String.valueOf(RTT_UID));
        agoraRtc.put("token", rtcToken);
        agoraRtc.put("channelType", "LIVE_TYPE");
        agoraRtc.put("subscribeAudioUids", "*");

        // Transcription config
        ObjectNode config = body.putObject("config");
        ObjectNode recognizeConfig = config.putObject("recognizeConfig");
        recognizeConfig.put("language", agoraLang);
        recognizeConfig.put("model", "large");

        ObjectNode translateConfig = config.putObject("translateConfig");
        translateConfig.put("forceTranslateInterval", 5);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", tokenGenerator.getBasicAuthHeader())
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() == 200 || response.statusCode() == 201) {
            JsonNode json = objectMapper.readTree(response.body());
            return json.path("taskId").asText();
        } else {
            throw new RuntimeException("Agora start failed (" + response.statusCode() + "): " + response.body());
        }
    }

    /**
     * Map BCP-47 language codes to Agora RTT language identifiers.
     */
    private String mapToAgoraLanguage(String bcp47Code) {
        return switch (bcp47Code.toLowerCase()) {
            case "hi-in", "hi" -> "hi-IN";
            case "ta-in", "ta" -> "ta-IN";
            case "te-in", "te" -> "te-IN";
            case "mr-in", "mr" -> "mr-IN";
            case "bn-in", "bn" -> "bn-IN";
            case "kn-in", "kn" -> "kn-IN";
            case "ml-in", "ml" -> "ml-IN";
            case "gu-in", "gu" -> "gu-IN";
            case "pa-in", "pa" -> "pa-IN";
            case "en-in", "en" -> "en-US";
            default -> "en-US";
        };
    }
}
