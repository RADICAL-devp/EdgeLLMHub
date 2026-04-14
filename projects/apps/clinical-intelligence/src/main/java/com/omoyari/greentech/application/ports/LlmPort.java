package com.omoyari.greentech.application.ports;

public interface LlmPort {
    String generateSummary(String compressedPrompt);
}
