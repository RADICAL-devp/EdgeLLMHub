package com.omoyari.greentech.application.ports;

import com.omoyari.greentech.core.StructuredSummary;

import java.util.List;
import java.util.Map;

/**
 * Port for LLM-based summarization.
 */
public interface LlmPort {

    /**
     * Generate a structured clinical summary from raw consultation JSON.
     */
    StructuredSummary generateStructuredSummary(String consultationJson);

    /**
     * Generate a context-enriched summary using past consultation context
     * retrieved from the vector store for the given doctor.
     */
    StructuredSummary generateContextEnrichedSummary(String consultationJson, String pastContext);

    // ============ FIELD-LEVEL GENERATION FOR EHR ASSISTANCE ============

    /**
     * Generate a single EHR field suggestion from consultation JSON.
     *
     * @param fieldName must be one of: complaint, pastHistory, vitals,
     *                  physicalExamination, investigationOrdered, diagnosis, advice,
     *                  manualPrescription
     * @return the extracted field value as a String
     */
    String generateField(String fieldName, String consultationJson);

    /**
     * Generate multiple fields at once.
     *
     * @param fieldNames list of field names to generate
     * @return map of fieldName -> fieldValue
     */
    Map<String, String> generateFields(List<String> fieldNames, String consultationJson);
}
