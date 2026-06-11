package com.omoyari.greentech.application.ports;

import com.omoyari.greentech.core.StructuredSummary;

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
}
