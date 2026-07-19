package com.omoyari.greentech.application.services;

import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.SpeechToTextPort;
import com.omoyari.greentech.application.ports.TranslationPort;
import com.omoyari.greentech.core.StructuredSummary;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Orchestrates the full audio → text → translation → summary pipeline
 * for in-person consultations recorded in regional Indian languages.
 *
 * Pipeline:
 * 1. Audio bytes → Speech-to-Text (in original language)
 * 2. Regional text → Translate to English (skip if already English)
 * 3. English text → LLM structured summarization
 */
@Singleton
public class NoteTakerOrchestrator {

    private static final Logger LOG = LoggerFactory.getLogger(NoteTakerOrchestrator.class);

    private final SpeechToTextPort speechToTextPort;
    private final TranslationPort translationPort;
    private final LlmPort llmPort;

    public NoteTakerOrchestrator(SpeechToTextPort speechToTextPort,
                                  TranslationPort translationPort,
                                  LlmPort llmPort) {
        this.speechToTextPort = speechToTextPort;
        this.translationPort = translationPort;
        this.llmPort = llmPort;
    }

    /**
     * Transcribe audio to text in the original language.
     */
    public String transcribe(byte[] audioBytes, String languageCode,
                              String audioEncoding, int sampleRateHz) {
        LOG.info("Step 1: Transcribing audio — language={}, encoding={}", languageCode, audioEncoding);
        return speechToTextPort.transcribeAudio(audioBytes, languageCode, audioEncoding, sampleRateHz);
    }

    /**
     * Transcribe audio and translate the result to English.
     */
    public TranscribeAndTranslateResult transcribeAndTranslate(
            byte[] audioBytes, String languageCode, String audioEncoding, int sampleRateHz) {

        // Step 1: Transcribe in original language
        String originalText = transcribe(audioBytes, languageCode, audioEncoding, sampleRateHz);
        LOG.info("Step 1 complete: {} characters transcribed", originalText.length());

        // Step 2: Translate to English (skip if English)
        String englishText;
        if (languageCode.startsWith("en")) {
            englishText = originalText;
            LOG.info("Step 2: Skipping translation — source is English");
        } else {
            LOG.info("Step 2: Translating {} → English", languageCode);
            englishText = translationPort.translateToEnglish(originalText, languageCode);
            LOG.info("Step 2 complete: {} characters translated", englishText.length());
        }

        return new TranscribeAndTranslateResult(originalText, englishText, languageCode);
    }

    /**
     * Full pipeline: audio → transcribe → translate → structured summary.
     */
    public StructuredSummary transcribeTranslateAndSummarize(
            byte[] audioBytes, String languageCode, String audioEncoding,
            int sampleRateHz, String doctorId, String patientId) {

        // Steps 1 & 2: Transcribe and translate
        TranscribeAndTranslateResult result = transcribeAndTranslate(
                audioBytes, languageCode, audioEncoding, sampleRateHz);

        // Step 3: Build a consultation-formatted text for the LLM
        String consultationText = """
                Transcribed Doctor-Patient Consultation
                Doctor ID: %s | Patient ID: %s
                Original Language: %s
                
                --- TRANSLATED CONSULTATION ---
                %s
                --- END ---
                """.formatted(doctorId, patientId, languageCode, result.englishText());

        LOG.info("Step 3: Generating structured summary from translated text");
        StructuredSummary summary = llmPort.generateStructuredSummary(consultationText);
        LOG.info("Step 3 complete: summary generated with {} fields populated",
                countPopulatedFields(summary));

        return summary;
    }

    /**
     * Translate already-transcribed text to English.
     * Useful when the frontend handles transcription and only needs translation.
     */
    public String translateOnly(String text, String sourceLanguageCode) {
        return translationPort.translateToEnglish(text, sourceLanguageCode);
    }

    /**
     * Detect the language of the given text.
     */
    public String detectLanguage(String text) {
        return translationPort.detectLanguage(text);
    }

    private int countPopulatedFields(StructuredSummary summary) {
        int count = 0;
        if (summary.getComplaint() != null && !summary.getComplaint().isBlank()) count++;
        if (summary.getPastHistory() != null && !summary.getPastHistory().isBlank()) count++;
        if (summary.getVitals() != null && !summary.getVitals().isBlank()) count++;
        if (summary.getPhysicalExamination() != null && !summary.getPhysicalExamination().isBlank()) count++;
        if (summary.getInvestigationOrdered() != null && !summary.getInvestigationOrdered().isBlank()) count++;
        if (summary.getDiagnosis() != null && !summary.getDiagnosis().isBlank()) count++;
        if (summary.getAdvice() != null && !summary.getAdvice().isBlank()) count++;
        return count;
    }

    /**
     * Result object for the transcribe + translate pipeline.
     */
    public record TranscribeAndTranslateResult(
            String originalText,
            String englishText,
            String sourceLanguageCode
    ) {}
}
