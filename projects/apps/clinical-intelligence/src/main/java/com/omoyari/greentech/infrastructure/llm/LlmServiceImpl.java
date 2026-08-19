package com.omoyari.greentech.infrastructure.llm;

import com.fasterxml.jackson.databind.JsonNode;
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
import java.util.Map;
import java.util.stream.Collectors;
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

    // ============ FIELD-LEVEL GENERATION ============

    private static final Map<String, String> FIELD_PROMPTS = Map.of(
            "complaint",
            """
            You are a clinical extraction assistant. Extract ONLY the chief complaint and presenting symptoms.
            Return as JSON: {"complaint": "..."}
            Rules:
            1. Use the patient's own words where possible.
            2. Include onset, duration, severity if mentioned.
            3. Be concise but complete.
            4. If not documented, return {"complaint": "Not documented in transcript."}
            """,
            "pastHistory",
            """
            You are a clinical extraction assistant. Extract ONLY past medical, surgical, and family history.
            Return as JSON: {"pastHistory": "..."}
            Rules:
            1. Include relevant conditions, surgeries, hospitalizations.
            2. Include family history if mentioned.
            3. Exclude current complaint (that's in complaint field).
            4. If not documented, return {"pastHistory": "Not documented in transcript."}
            """,
            "vitals",
            """
            You are a clinical extraction assistant. Extract ALL vital signs with values and units.
            Return as JSON: {"vitals": "..."}
            Rules:
            1. Include numeric values with units (BP, HR, SpO2, Temp, Weight, Height, BMI).
            2. Flag abnormal values with clinical interpretation.
            3. Format: "BP 120/80 mmHg, HR 72 bpm, SpO2 98%, Temp 98.6°F, BMI 26.5"
            4. If not documented, return {"vitals": "Not documented in transcript."}
            """,
            "physicalExamination",
            """
            You are a clinical extraction assistant. Extract physical examination findings.
            Return as JSON: {"physicalExamination": "..."}
            Rules:
            1. Organize by body system (HEENT, Cardiovascular, Respiratory, etc.).
            2. Note pertinent positives and negatives.
            3. Use standard medical terminology.
            4. If not documented, return {"physicalExamination": "Not documented in transcript."}
            """,
            "investigationOrdered",
            """
            You are a clinical extraction assistant. Extract all investigations ordered or completed.
            Return as JSON: {"investigationOrdered": "..."}
            Rules:
            1. Include test names, key results (e.g., AHI 15, ODI 12).
            2. Distinguish ordered vs completed vs pending.
            3. Include sleep study specifics (AHI, ODI, min SpO2, sleep efficiency).
            4. If not documented, return {"investigationOrdered": "Not documented in transcript."}
            """,
            "diagnosis",
            """
            You are a clinical extraction assistant. Extract diagnoses with ICD-10 codes.
            Return as JSON: {"diagnosis": "..."}
            Rules:
            1. List primary diagnosis first.
            2. Include severity grading (mild/moderate/severe).
            3. Include ICD-10 codes when present in input.
            4. Differentiate confirmed vs provisional.
            5. If not documented, return {"diagnosis": "Not documented in transcript."}
            """,
            "advice",
            """
            You are a clinical extraction assistant. Extract treatment recommendations, follow-up, and medications.
            Return as JSON: {"advice": "..."}
            Rules:
            1. Number each recommendation.
            2. Separate medications from lifestyle/device recommendations.
            3. Include follow-up timeline (e.g., "Follow up in 4 weeks").
            4. Include CPAP/device settings if mentioned.
            5. If not documented, return {"advice": "Not documented in transcript."}
            """,
            "manualPrescription",
            """
            You are a clinical extraction assistant. Extract ALL medication prescriptions as free text.
            Return as JSON: {"manualPrescription": "..."}
            Rules:
            1. Include drug name, dose, frequency, duration, route.
            2. Distinguish new prescriptions from continuations.
            3. Include special instructions (e.g., "take with food").
            4. Format as a readable medication list.
            5. If not documented, return {"manualPrescription": "Not documented in transcript."}
            """
    );

    @Override
    public String generateField(String fieldName, String consultationJson) {
        LOG.info("Generating field: {}", fieldName);

        String fieldPrompt = FIELD_PROMPTS.get(fieldName);
        if (fieldPrompt == null) {
            throw new IllegalArgumentException("Unknown field: " + fieldName + ". Valid fields: " + FIELD_PROMPTS.keySet());
        }

        String userContent = fieldPrompt + "\n\nInput text:\n" + consultationJson;

        ChatResponse chatResponse = chatModel.chat(
                SystemMessage.from("You are a clinical extraction assistant. Return ONLY the JSON object with the requested field."),
                UserMessage.from(userContent));
        String response = chatResponse.aiMessage().text();

        return extractFieldValue(response, fieldName);
    }

    @Override
    public Map<String, String> generateFields(List<String> fieldNames, String consultationJson) {
        return fieldNames.stream()
                .collect(Collectors.toMap(
                        fieldName -> fieldName,
                        fieldName -> generateField(fieldName, consultationJson)
                ));
    }

    private String extractFieldValue(String response, String fieldName) {
        String cleaned = response.strip();
        if (cleaned.startsWith("```")) {
            cleaned = cleaned.replaceAll("^```(?:json)?\\s*", "").replaceAll("\\s*```$", "");
        }

        try {
            JsonNode json = objectMapper.readTree(cleaned);
            return json.has(fieldName) ? json.get(fieldName).asText() : "";
        } catch (Exception e) {
            LOG.warn("Failed to parse field response: {}", e.getMessage());
            return cleaned;
        }
    }
}
