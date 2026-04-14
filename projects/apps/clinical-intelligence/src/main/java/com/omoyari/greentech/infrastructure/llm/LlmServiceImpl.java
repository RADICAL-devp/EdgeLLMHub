package com.omoyari.greentech.infrastructure.llm;

import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.config.LlmProperties;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Singleton
public class LlmServiceImpl implements LlmPort {
    private static final Logger LOG = LoggerFactory.getLogger(LlmServiceImpl.class);

    private final LlmProperties llmProperties;

    public LlmServiceImpl(LlmProperties llmProperties) {
        this.llmProperties = llmProperties;
    }

    @Override
    public String generateSummary(String compressedPrompt) {
        LOG.info(
                "Invoking LLM {} with temperature {} and maxTokens {}",
                llmProperties.getModelName(),
                llmProperties.getTemperature(),
                llmProperties.getMaxTokens());

        // Placeholder for LangChain4j / AWS Bedrock integration.
        // E.g., Return fixed structured JSON for skeleton
        return "{\n" + "  \"patientStatus\": \"Stable\",\n"
                + "  \"keyFindings\": [\"Hypertension controlled\", \"No acute issues\"]\n"
                + "}";
    }
}
