package com.omoyari.greentech.infrastructure.llm;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.omoyari.greentech.application.ports.LlmPort;
import com.omoyari.greentech.core.StructuredSummary;
import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.response.ChatResponse;
import jakarta.inject.Singleton;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * LangChain4J-powered LLM service for clinical summarization.
 * Uses structured output extraction to populate the 7-field StructuredSummary.
 */
@Singleton
public class LlmServiceImpl implements LlmPort {
    private static final Logger LOG = LoggerFactory.getLogger(LlmServiceImpl.class);

    private final ChatLanguageModel chatModel;
    private final ObjectMapper objectMapper;

    private static final String SYSTEM_PROMPT =
            """
            You are a clinical summarization assistant for a sleep medicine practice.
            Given raw consultation data in JSON format, you MUST extract and return a JSON object
            with EXACTLY these 7 fields:

            {
              "complaint": "<Summarize the chief complaint and presenting symptoms>",
              "pastHistory": "<Summarize past medical history, surgical history, family history>",
              "vitals": "<Summarize all vital signs with clinical interpretation>",
              "physicalExamination": "<Summarize physical examination findings>",
              "investigationOrdered": "<Summarize all investigations ordered/completed with key results>",
              "diagnosis": "<List diagnoses with ICD-10 codes where applicable>",
              "advice": "<List all treatment recommendations, follow-up plans, medications>"
            }

            Rules:
            1. Each field MUST be a non-empty string.
            2. Use medical terminology appropriately.
            3. Include relevant numeric values (e.g., AHI scores, BP readings).
            4. For diagnosis, include severity grading and ICD-10 codes.
            5. For advice, number each recommendation.
            6. Return ONLY the JSON object, no markdown fences, no extra text.
            """;

    private static final String CONTEXT_ENRICHED_SYSTEM_PROMPT =
            """
            You are a clinical summarization assistant for a sleep medicine practice.
            You have access to PAST CONSULTATION CONTEXT from this doctor's previous patients.
            Use this context to ensure consistency in terminology, diagnosis coding, and
            treatment recommendations — but do NOT copy information from past patients
            into the current summary.

            Given raw consultation data in JSON format, extract and return a JSON object
            with EXACTLY these 7 fields:

            {
              "complaint": "<Summarize the chief complaint and presenting symptoms>",
              "pastHistory": "<Summarize past medical history, surgical history, family history>",
              "vitals": "<Summarize all vital signs with clinical interpretation>",
              "physicalExamination": "<Summarize physical examination findings>",
              "investigationOrdered": "<Summarize all investigations ordered/completed with key results>",
              "diagnosis": "<List diagnoses with ICD-10 codes where applicable>",
              "advice": "<List all treatment recommendations, follow-up plans, medications>"
            }

            Rules:
            1. Each field MUST be a non-empty string.
            2. Use medical terminology appropriately.
            3. Include relevant numeric values.
            4. For diagnosis, include severity grading and ICD-10 codes.
            5. For advice, number each recommendation.
            6. Return ONLY the JSON object, no markdown fences, no extra text.
            7. Maintain consistency with the doctor's past consultation style shown in PAST CONTEXT.
            """;

    public LlmServiceImpl(ChatLanguageModel chatModel) {
        this.chatModel = chatModel;
        this.objectMapper = new ObjectMapper();
    }

    @Override
    public StructuredSummary generateStructuredSummary(String consultationJson) {
        LOG.info("Generating structured summary via LangChain4J");

        ChatResponse chatResponse = chatModel.chat(
                SystemMessage.from(SYSTEM_PROMPT),
                UserMessage.from("Summarize this consultation:\n\n" + consultationJson));
        String response = chatResponse.aiMessage().text();

        return parseResponse(response);
    }

    @Override
    public StructuredSummary generateContextEnrichedSummary(String consultationJson, String pastContext) {
        LOG.info("Generating context-enriched summary via LangChain4J");

        String userContent = "PAST CONTEXT from this doctor's consultations:\n"
                + pastContext
                + "\n\n---\n\nNow summarize THIS consultation:\n\n"
                + consultationJson;

        ChatResponse chatResponse = chatModel.chat(
                SystemMessage.from(CONTEXT_ENRICHED_SYSTEM_PROMPT), UserMessage.from(userContent));
        String response = chatResponse.aiMessage().text();

        return parseResponse(response);
    }

    private StructuredSummary parseResponse(String response) {
        // Strip markdown code fences if the LLM wraps the JSON
        String cleaned = response.strip();
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.replaceAll("^```(?:json)?\\s*", "").replaceAll("\\s*```$", "");
        }

        try {
            return objectMapper.readValue(cleaned, StructuredSummary.class);
        } catch (Exception e) {
            LOG.warn("Failed to parse LLM response as StructuredSummary, building fallback. Error: {}", e.getMessage());
            // Fallback: if the LLM doesn't return valid JSON, wrap the whole response
            StructuredSummary fallback = new StructuredSummary();
            fallback.setComplaint("See raw output");
            fallback.setPastHistory("See raw output");
            fallback.setVitals("See raw output");
            fallback.setPhysicalExamination("See raw output");
            fallback.setInvestigationOrdered("See raw output");
            fallback.setDiagnosis("See raw output");
            fallback.setAdvice(cleaned);
            return fallback;
        }
    }
}
