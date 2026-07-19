package com.omoyari.greentech.infrastructure.transcription;

import com.omoyari.greentech.application.ports.SpeechToTextPort;
import com.omoyari.greentech.config.GoogleCloudProperties;
import com.google.cloud.speech.v2.AutoDetectDecodingConfig;
import com.google.cloud.speech.v2.RecognitionConfig;
import com.google.cloud.speech.v2.RecognizeRequest;
import com.google.cloud.speech.v2.RecognizeResponse;
import com.google.cloud.speech.v2.SpeechClient;
import com.google.cloud.speech.v2.SpeechRecognitionResult;
import com.google.protobuf.ByteString;
import jakarta.inject.Singleton;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Google Cloud Speech-to-Text V2 implementation.
 * Uses the Chirp model for best accuracy across Indian regional languages.
 *
 * Supports 9 Indian languages: Hindi, Tamil, Telugu, Marathi, Bengali,
 * Kannada, Malayalam, Gujarati, Punjabi.
 */
@Singleton
public class GoogleSpeechToTextService implements SpeechToTextPort {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleSpeechToTextService.class);

    private static final List<String> SUPPORTED_LANGUAGES = List.of(
            "hi-IN", "ta-IN", "te-IN", "mr-IN", "bn-IN",
            "kn-IN", "ml-IN", "gu-IN", "pa-IN", "en-IN", "en-US");

    private final GoogleCloudProperties properties;

    public GoogleSpeechToTextService(GoogleCloudProperties properties) {
        this.properties = properties;
    }

    @Override
    public String transcribeAudio(byte[] audioBytes, String languageCode,
                                   String audioEncoding, int sampleRateHz) {
        LOG.info("Transcribing audio: language={}, encoding={}, sampleRate={}, size={}KB",
                languageCode, audioEncoding, sampleRateHz, audioBytes.length / 1024);

        if (properties.getProjectId() == null || properties.getProjectId().isBlank()) {
            throw new IllegalStateException(
                    "GCP project ID not configured. Set GCP_PROJECT_ID environment variable.");
        }

        try (SpeechClient speechClient = SpeechClient.create()) {

            // Build recognizer path
            String recognizerName = String.format(
                    "projects/%s/locations/%s/recognizers/_",
                    properties.getProjectId(), properties.getLocation());

            // Configure recognition
            RecognitionConfig config = RecognitionConfig.newBuilder()
                    .setAutoDecodingConfig(AutoDetectDecodingConfig.getDefaultInstance())
                    .addLanguageCodes(languageCode)
                    .setModel(properties.getSttModel())
                    .build();

            RecognizeRequest request = RecognizeRequest.newBuilder()
                    .setRecognizer(recognizerName)
                    .setConfig(config)
                    .setContent(ByteString.copyFrom(audioBytes))
                    .build();

            // Execute recognition
            RecognizeResponse response = speechClient.recognize(request);

            // Aggregate results
            StringBuilder transcript = new StringBuilder();
            for (SpeechRecognitionResult result : response.getResultsList()) {
                if (!result.getAlternativesList().isEmpty()) {
                    transcript.append(result.getAlternatives(0).getTranscript()).append(" ");
                }
            }

            String transcribedText = transcript.toString().trim();
            LOG.info("Transcription complete: {} characters in {} results",
                    transcribedText.length(), response.getResultsCount());

            return transcribedText;

        } catch (Exception e) {
            LOG.error("Google Cloud STT failed for language={}", languageCode, e);
            throw new RuntimeException("Speech-to-Text transcription failed: " + e.getMessage(), e);
        }
    }

    @Override
    public List<String> getSupportedLanguages() {
        return SUPPORTED_LANGUAGES;
    }
}
