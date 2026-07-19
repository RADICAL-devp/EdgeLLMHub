package com.omoyari.greentech.application.ports;

import java.util.List;

/**
 * Port for speech-to-text services.
 * Supports audio transcription in multiple Indian regional languages.
 */
public interface SpeechToTextPort {

    /**
     * Transcribe audio bytes to text in the specified language.
     *
     * @param audioBytes    Raw audio data
     * @param languageCode  BCP-47 language code (e.g., "hi-IN", "ta-IN")
     * @param audioEncoding Audio format (e.g., "LINEAR16", "FLAC", "MP3", "OGG_OPUS")
     * @param sampleRateHz  Sample rate in Hz (e.g., 16000)
     * @return The transcribed text in the original language
     */
    String transcribeAudio(byte[] audioBytes, String languageCode, String audioEncoding, int sampleRateHz);

    /**
     * Get the list of supported language codes.
     *
     * @return List of BCP-47 language codes this service supports
     */
    List<String> getSupportedLanguages();
}
