package com.omoyari.greentech.application.ports;

import java.util.List;
import java.util.Map;

/**
 * Port for doctor-specific incremental vector storage.
 * Each doctor has their own logical partition in the vector store.
 */
public interface VectorStorePort {

    /**
     * Store an embedding of the given content with metadata.
     * The doctorId is used as the partition key for doctor-specific isolation.
     */
    void storeEmbedding(String doctorId, String content, Map<String, String> metadata);

    /**
     * Retrieve the most relevant past context for a query, scoped to a specific doctor.
     *
     * @param doctorId   The doctor whose embeddings to search
     * @param query      The query text (typically the current consultation summary)
     * @param maxResults Maximum number of relevant segments to return
     * @return List of relevant text segments from past consultations
     */
    List<String> retrieveRelevantContext(String doctorId, String query, int maxResults);
}
