package com.omoyari.greentech.application.ports;

/**
 * Port for text translation services.
 * Translates regional Indian language text to English for clinical summarization.
 */
public interface TranslationPort {

    /**
     * Translate text from the given source language to English.
     *
     * @param text               The text to translate
     * @param sourceLanguageCode BCP-47 language code (e.g., "hi" for Hindi)
     * @return Translated English text
     */
    String translateToEnglish(String text, String sourceLanguageCode);

    /**
     * Detect the language of the given text.
     *
     * @param text The text to analyze
     * @return Detected BCP-47 language code (e.g., "hi", "ta", "te")
     */
    String detectLanguage(String text);
}
