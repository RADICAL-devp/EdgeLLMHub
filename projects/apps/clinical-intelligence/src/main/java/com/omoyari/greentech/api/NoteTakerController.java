package com.omoyari.greentech.api;

import com.omoyari.greentech.application.services.NoteTakerOrchestrator;
import com.omoyari.greentech.core.StructuredSummary;
import io.micronaut.core.annotation.Nullable;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.MediaType;
import io.micronaut.http.annotation.*;
import io.micronaut.http.multipart.CompletedFileUpload;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.rules.SecurityRule;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * REST controller for in-person consultation note-taking.
 * Accepts audio recordings in regional Indian languages, transcribes,
 * translates to English, and generates structured clinical summaries.
 *
 * Endpoints:
 *   POST /api/v1/note-taker/transcribe              → Audio → text (original language)
 *   POST /api/v1/note-taker/transcribe-and-translate → Audio → text → English
 *   POST /api/v1/note-taker/transcribe-and-summarize → Audio → text → English → summary
 *   GET  /api/v1/note-taker/languages                → List supported languages
 */
@Controller("/api/v1/note-taker")
@Secured(SecurityRule.IS_AUTHENTICATED)
public class NoteTakerController {

    private static final Logger LOG = LoggerFactory.getLogger(NoteTakerController.class);
    private static final int DEFAULT_SAMPLE_RATE = 16000;
    private static final String DEFAULT_ENCODING = "MP3";

    private final NoteTakerOrchestrator orchestrator;

    public NoteTakerController(NoteTakerOrchestrator orchestrator) {
        this.orchestrator = orchestrator;
    }

    /**
     * Transcribe an audio file to text in the original language.
     */
    @Post(value = "/transcribe", consumes = MediaType.MULTIPART_FORM_DATA)
    public HttpResponse<Map<String, String>> transcribe(
            @Part CompletedFileUpload audioFile,
            @Part String languageCode,
            @Nullable @Part String audioEncoding,
            @Nullable @Part String sampleRateHz) throws IOException {

        String encoding = audioEncoding != null ? audioEncoding : DEFAULT_ENCODING;
        int sampleRate = sampleRateHz != null ? Integer.parseInt(sampleRateHz) : DEFAULT_SAMPLE_RATE;

        LOG.info("Transcribe request: language={}, encoding={}, fileSize={}KB",
                languageCode, encoding, audioFile.getSize() / 1024);

        byte[] audioBytes = audioFile.getBytes();
        String text = orchestrator.transcribe(audioBytes, languageCode, encoding, sampleRate);

        return HttpResponse.ok(Map.of(
                "languageCode", languageCode,
                "transcribedText", text));
    }

    /**
     * Transcribe audio and translate the result to English.
     */
    @Post(value = "/transcribe-and-translate", consumes = MediaType.MULTIPART_FORM_DATA)
    public HttpResponse<Map<String, String>> transcribeAndTranslate(
            @Part CompletedFileUpload audioFile,
            @Part String languageCode,
            @Nullable @Part String audioEncoding,
            @Nullable @Part String sampleRateHz) throws IOException {

        String encoding = audioEncoding != null ? audioEncoding : DEFAULT_ENCODING;
        int sampleRate = sampleRateHz != null ? Integer.parseInt(sampleRateHz) : DEFAULT_SAMPLE_RATE;

        LOG.info("Transcribe+Translate request: language={}, fileSize={}KB",
                languageCode, audioFile.getSize() / 1024);

        byte[] audioBytes = audioFile.getBytes();
        NoteTakerOrchestrator.TranscribeAndTranslateResult result = orchestrator.transcribeAndTranslate(
                audioBytes, languageCode, encoding, sampleRate);

        return HttpResponse.ok(Map.of(
                "sourceLanguageCode", result.sourceLanguageCode(),
                "originalText", result.originalText(),
                "englishText", result.englishText()));
    }

    /**
     * Full pipeline: audio → transcribe → translate → structured clinical summary.
     */
    @Post(value = "/transcribe-and-summarize", consumes = MediaType.MULTIPART_FORM_DATA)
    public HttpResponse<Map<String, Object>> transcribeAndSummarize(
            @Part CompletedFileUpload audioFile,
            @Part String languageCode,
            @Part String doctorId,
            @Part String patientId,
            @Nullable @Part String audioEncoding,
            @Nullable @Part String sampleRateHz) throws IOException {

        String encoding = audioEncoding != null ? audioEncoding : DEFAULT_ENCODING;
        int sampleRate = sampleRateHz != null ? Integer.parseInt(sampleRateHz) : DEFAULT_SAMPLE_RATE;

        LOG.info("Full pipeline request: language={}, doctor={}, patient={}, fileSize={}KB",
                languageCode, doctorId, patientId, audioFile.getSize() / 1024);

        byte[] audioBytes = audioFile.getBytes();
        StructuredSummary summary = orchestrator.transcribeTranslateAndSummarize(
                audioBytes, languageCode, encoding, sampleRate, doctorId, patientId);

        return HttpResponse.ok(Map.of(
                "doctorId", doctorId,
                "patientId", patientId,
                "sourceLanguageCode", languageCode,
                "summary", summary));
    }

    /**
     * List all supported regional languages for transcription.
     */
    @Get("/languages")
    @Secured(SecurityRule.IS_ANONYMOUS)
    public HttpResponse<Map<String, Object>> getSupportedLanguages() {
        List<Map<String, String>> languages = List.of(
                Map.of("code", "hi-IN", "name", "Hindi", "script", "Devanagari"),
                Map.of("code", "ta-IN", "name", "Tamil", "script", "Tamil"),
                Map.of("code", "te-IN", "name", "Telugu", "script", "Telugu"),
                Map.of("code", "mr-IN", "name", "Marathi", "script", "Devanagari"),
                Map.of("code", "bn-IN", "name", "Bengali", "script", "Bengali"),
                Map.of("code", "kn-IN", "name", "Kannada", "script", "Kannada"),
                Map.of("code", "ml-IN", "name", "Malayalam", "script", "Malayalam"),
                Map.of("code", "gu-IN", "name", "Gujarati", "script", "Gujarati"),
                Map.of("code", "pa-IN", "name", "Punjabi", "script", "Gurmukhi"),
                Map.of("code", "en-IN", "name", "English (India)", "script", "Latin"),
                Map.of("code", "en-US", "name", "English (US)", "script", "Latin"));

        return HttpResponse.ok(Map.of(
                "supportedLanguages", languages,
                "total", languages.size()));
    }
}
