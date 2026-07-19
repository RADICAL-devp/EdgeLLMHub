package com.omoyari.greentech.application.services;

import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.application.ports.SpeechToTextPort;
import com.omoyari.greentech.application.ports.TranslationPort;
import com.omoyari.greentech.core.StructuredSummary;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for NoteTakerOrchestrator.
 * Uses manual stubs (no Mockito — JDK 25 ByteBuddy incompatibility).
 */
class NoteTakerOrchestratorTest {

    private StubSpeechToText stubStt;
    private StubTranslation stubTranslation;
    private StubLlm stubLlm;
    private NoteTakerOrchestrator orchestrator;

    @BeforeEach
    void setUp() {
        stubStt = new StubSpeechToText();
        stubTranslation = new StubTranslation();
        stubLlm = new StubLlm();
        orchestrator = new NoteTakerOrchestrator(stubStt, stubTranslation, stubLlm);
    }

    @Test
    void transcribe_delegatesToSpeechToTextPort() {
        stubStt.setTranscription("रोगी को सिरदर्द है");

        String result = orchestrator.transcribe(
                new byte[]{1, 2, 3}, "hi-IN", "MP3", 16000);

        assertEquals("रोगी को सिरदर्द है", result);
    }

    @Test
    void transcribeAndTranslate_translatesNonEnglishText() {
        stubStt.setTranscription("रोगी को सिरदर्द है");
        stubTranslation.setTranslatedText("Patient has headache");

        NoteTakerOrchestrator.TranscribeAndTranslateResult result =
                orchestrator.transcribeAndTranslate(
                        new byte[]{1, 2, 3}, "hi-IN", "MP3", 16000);

        assertEquals("रोगी को सिरदर्द है", result.originalText());
        assertEquals("Patient has headache", result.englishText());
        assertEquals("hi-IN", result.sourceLanguageCode());
    }

    @Test
    void transcribeAndTranslate_skipsTranslationForEnglish() {
        stubStt.setTranscription("Patient has headache");

        NoteTakerOrchestrator.TranscribeAndTranslateResult result =
                orchestrator.transcribeAndTranslate(
                        new byte[]{1, 2, 3}, "en-IN", "MP3", 16000);

        // Should not call translate — original = english
        assertEquals("Patient has headache", result.originalText());
        assertEquals("Patient has headache", result.englishText());
        assertFalse(stubTranslation.wasCalled());
    }

    @Test
    void transcribeTranslateAndSummarize_returnsStructuredSummary() {
        stubStt.setTranscription("रोगी को सिरदर्द है");
        stubTranslation.setTranslatedText("Patient has headache");
        stubLlm.setSummary(createTestSummary());

        StructuredSummary summary = orchestrator.transcribeTranslateAndSummarize(
                new byte[]{1, 2, 3}, "hi-IN", "MP3", 16000, "DR-001", "PAT-001");

        assertNotNull(summary);
        assertEquals("Severe headache for 1 week", summary.getComplaint());
        assertTrue(stubLlm.wasCalled());
    }

    @Test
    void detectLanguage_delegatesToTranslationPort() {
        stubTranslation.setDetectedLanguage("hi");

        String detected = orchestrator.detectLanguage("यह हिंदी में है");
        assertEquals("hi", detected);
    }

    // ---- Stub implementations ----

    private StructuredSummary createTestSummary() {
        StructuredSummary summary = new StructuredSummary();
        summary.setComplaint("Severe headache for 1 week");
        summary.setDiagnosis("Tension-type headache");
        summary.setAdvice("Paracetamol 500mg PRN, follow up in 1 week");
        return summary;
    }

    static class StubSpeechToText implements SpeechToTextPort {
        private String transcription = "";

        void setTranscription(String text) { this.transcription = text; }

        @Override
        public String transcribeAudio(byte[] audioBytes, String languageCode,
                                       String audioEncoding, int sampleRateHz) {
            return transcription;
        }

        @Override
        public List<String> getSupportedLanguages() {
            return List.of("hi-IN", "ta-IN", "te-IN", "en-IN");
        }
    }

    static class StubTranslation implements TranslationPort {
        private String translatedText = "";
        private String detectedLanguage = "en";
        private boolean called = false;

        void setTranslatedText(String text) { this.translatedText = text; }
        void setDetectedLanguage(String lang) { this.detectedLanguage = lang; }
        boolean wasCalled() { return called; }

        @Override
        public String translateToEnglish(String text, String sourceLanguageCode) {
            called = true;
            return translatedText;
        }

        @Override
        public String detectLanguage(String text) {
            called = true;
            return detectedLanguage;
        }
    }

    static class StubLlm implements LlmPort {
        private StructuredSummary summary = new StructuredSummary();
        private boolean called = false;

        void setSummary(StructuredSummary s) { this.summary = s; }
        boolean wasCalled() { return called; }

        @Override
        public StructuredSummary generateStructuredSummary(String consultationText) {
            called = true;
            return summary;
        }

        @Override
        public StructuredSummary generateContextEnrichedSummary(String consultationJson, String pastContext) {
            called = true;
            return summary;
        }
    }
}
