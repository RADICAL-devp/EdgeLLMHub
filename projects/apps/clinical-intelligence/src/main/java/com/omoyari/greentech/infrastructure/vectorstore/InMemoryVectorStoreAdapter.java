package com.omoyari.greentech.infrastructure.vectorstore;

import com.omoyari.greentech.application.ports.VectorStorePort;
import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingSearchRequest;
import dev.langchain4j.store.embedding.EmbeddingSearchResult;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.filter.MetadataFilterBuilder;
import jakarta.inject.Singleton;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * In-memory vector store adapter with doctor-specific partitioning via metadata filtering.
 * Each embedding is tagged with a "doctorId" metadata key, and retrieval queries filter by it.
 * This enables incremental, doctor-specific context building.
 */
@Singleton
public class InMemoryVectorStoreAdapter implements VectorStorePort {

    private static final Logger LOG = LoggerFactory.getLogger(InMemoryVectorStoreAdapter.class);
    private static final String DOCTOR_ID_KEY = "doctorId";
    private static final double MIN_SCORE = 0.5; // minimum similarity threshold

    private final EmbeddingStore<TextSegment> embeddingStore;
    private final EmbeddingModel embeddingModel;

    public InMemoryVectorStoreAdapter(
            EmbeddingStore<TextSegment> embeddingStore, EmbeddingModel embeddingModel) {
        this.embeddingStore = embeddingStore;
        this.embeddingModel = embeddingModel;
    }

    @Override
    public void storeEmbedding(String doctorId, String content, Map<String, String> metadata) {
        LOG.info("Storing embedding for doctor: {} (content length: {} chars)", doctorId, content.length());

        Metadata langchainMetadata = new Metadata();
        langchainMetadata.put(DOCTOR_ID_KEY, doctorId);
        if (metadata != null) {
            metadata.forEach(langchainMetadata::put);
        }

        TextSegment segment = TextSegment.from(content, langchainMetadata);
        Embedding embedding = embeddingModel.embed(segment).content();
        embeddingStore.add(embedding, segment);

        LOG.debug("Embedding stored successfully for doctor: {}", doctorId);
    }

    @Override
    public List<String> retrieveRelevantContext(String doctorId, String query, int maxResults) {
        LOG.info("Retrieving context for doctor: {} (maxResults: {})", doctorId, maxResults);

        Embedding queryEmbedding = embeddingModel.embed(query).content();

        EmbeddingSearchRequest searchRequest = EmbeddingSearchRequest.builder()
                .queryEmbedding(queryEmbedding)
                .maxResults(maxResults)
                .minScore(MIN_SCORE)
                .filter(MetadataFilterBuilder.metadataKey(DOCTOR_ID_KEY).isEqualTo(doctorId))
                .build();

        EmbeddingSearchResult<TextSegment> results = embeddingStore.search(searchRequest);

        List<String> contextSegments = results.matches().stream()
                .map(EmbeddingMatch::embedded)
                .map(TextSegment::text)
                .collect(Collectors.toList());

        LOG.info("Found {} relevant context segments for doctor: {}", contextSegments.size(), doctorId);
        return contextSegments;
    }
}
