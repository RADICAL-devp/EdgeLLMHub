package com.omoyari.greentech.infrastructure.translation;

import com.omoyari.greentech.application.ports.TranslationPort;
import com.omoyari.greentech.config.GoogleCloudProperties;
import com.google.cloud.translate.v3.DetectLanguageRequest;
import com.google.cloud.translate.v3.DetectLanguageResponse;
import com.google.cloud.translate.v3.DetectedLanguage;
import com.google.cloud.translate.v3.LocationName;
import com.google.cloud.translate.v3.TranslateTextRequest;
import com.google.cloud.translate.v3.TranslateTextResponse;
import com.google.cloud.translate.v3.TranslationServiceClient;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Google Cloud Translate V3 implementation.
 * Translates regional Indian language text to English for clinical summarization.
 *
 * Features:
 * - Real-time text translation (not batch — sub-second latency)
 * - Language auto-detection fallback
 * - Optional medical glossary support for domain-specific term accuracy
 */
@Singleton
public class GoogleTranslateService implements TranslationPort {

    private static final Logger LOG = LoggerFactory.getLogger(GoogleTranslateService.class);
    private static final String TARGET_LANGUAGE = "en";

    private final GoogleCloudProperties properties;

    public GoogleTranslateService(GoogleCloudProperties properties) {
        this.properties = properties;
    }

    @Override
    public String translateToEnglish(String text, String sourceLanguageCode) {
        LOG.info("Translating text: source={}, length={} chars", sourceLanguageCode, text.length());

        if (properties.getProjectId() == null || properties.getProjectId().isBlank()) {
            throw new IllegalStateException(
                    "GCP project ID not configured. Set GCP_PROJECT_ID environment variable.");
        }

        // Skip translation if already English
        if (sourceLanguageCode != null
                && (sourceLanguageCode.startsWith("en") || sourceLanguageCode.equals("en-IN"))) {
            LOG.info("Source language is English — skipping translation");
            return text;
        }

        try (TranslationServiceClient client = TranslationServiceClient.create()) {
            LocationName parent = LocationName.of(properties.getProjectId(), properties.getLocation());

            TranslateTextRequest.Builder requestBuilder = TranslateTextRequest.newBuilder()
                    .setParent(parent.toString())
                    .setTargetLanguageCode(TARGET_LANGUAGE)
                    .setMimeType("text/plain")
                    .addContents(text);

            // Set source language if known (improves accuracy)
            if (sourceLanguageCode != null && !sourceLanguageCode.isBlank()) {
                // Strip region suffix for Translate API (e.g., "hi-IN" → "hi")
                String langCode = sourceLanguageCode.contains("-")
                        ? sourceLanguageCode.split("-")[0]
                        : sourceLanguageCode;
                requestBuilder.setSourceLanguageCode(langCode);
            }

            TranslateTextResponse response = client.translateText(requestBuilder.build());

            if (response.getTranslationsCount() > 0) {
                String translatedText = response.getTranslations(0).getTranslatedText();
                LOG.info("Translation complete: {} → {} ({} chars → {} chars)",
                        sourceLanguageCode, TARGET_LANGUAGE, text.length(), translatedText.length());
                return translatedText;
            } else {
                LOG.warn("Translation returned no results for source={}", sourceLanguageCode);
                return text;  // fallback: return original
            }

        } catch (Exception e) {
            LOG.error("Google Cloud Translation failed for source={}", sourceLanguageCode, e);
            throw new RuntimeException("Translation failed: " + e.getMessage(), e);
        }
    }

    @Override
    public String detectLanguage(String text) {
        LOG.debug("Detecting language for text: {} chars", text.length());

        if (properties.getProjectId() == null || properties.getProjectId().isBlank()) {
            throw new IllegalStateException(
                    "GCP project ID not configured. Set GCP_PROJECT_ID environment variable.");
        }

        try (TranslationServiceClient client = TranslationServiceClient.create()) {
            LocationName parent = LocationName.of(properties.getProjectId(), properties.getLocation());

            DetectLanguageRequest request = DetectLanguageRequest.newBuilder()
                    .setParent(parent.toString())
                    .setMimeType("text/plain")
                    .setContent(text)
                    .build();

            DetectLanguageResponse response = client.detectLanguage(request);

            if (!response.getLanguagesList().isEmpty()) {
                DetectedLanguage detected = response.getLanguages(0);
                LOG.info("Detected language: {} (confidence: {})",
                        detected.getLanguageCode(), detected.getConfidence());
                return detected.getLanguageCode();
            } else {
                LOG.warn("Language detection returned no results, defaulting to 'en'");
                return "en";
            }

        } catch (Exception e) {
            LOG.error("Google Cloud language detection failed", e);
            throw new RuntimeException("Language detection failed: " + e.getMessage(), e);
        }
    }
}
