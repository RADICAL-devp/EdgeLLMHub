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
import io.micronaut.context.annotation.Requires;
import jakarta.inject.Singleton;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Qdrant-backed vector store adapter for production use.
 * Provides persistent, scalable doctor-specific vector search with:
 * - Metadata-based doctor partitioning (same approach as in-memory)
 * - Retry logic with exponential backoff for transient network failures
 * - Structured logging for observability
 *
 * Only active when clinical.vector-store.type=qdrant.
 */
@Singleton
@Requires(property = "clinical.vector-store.type", value = "qdrant")
public class QdrantVectorStoreAdapter implements VectorStorePort {

    private static final Logger LOG = LoggerFactory.getLogger(QdrantVectorStoreAdapter.class);
    private static final String DOCTOR_ID_KEY = "doctorId";
    private static final double MIN_SCORE = 0.5;
    private static final int MAX_RETRIES = 3;
    private static final long INITIAL_BACKOFF_MS = 200;

    private final EmbeddingStore<TextSegment> embeddingStore;
    private final EmbeddingModel embeddingModel;

    public QdrantVectorStoreAdapter(
            EmbeddingStore<TextSegment> embeddingStore, EmbeddingModel embeddingModel) {
        this.embeddingStore = embeddingStore;
        this.embeddingModel = embeddingModel;
    }

    @Override
    public void storeEmbedding(String doctorId, String content, Map<String, String> metadata) {
        LOG.info("Storing embedding in Qdrant for doctor: {} (content length: {} chars)", doctorId, content.length());

        Metadata langchainMetadata = new Metadata();
        langchainMetadata.put(DOCTOR_ID_KEY, doctorId);
        if (metadata != null) {
            metadata.forEach(langchainMetadata::put);
        }

        TextSegment segment = TextSegment.from(content, langchainMetadata);
        Embedding embedding = embeddingModel.embed(segment).content();

        executeWithRetry(() -> {
            embeddingStore.add(embedding, segment);
            return null;
        }, "storeEmbedding", doctorId);

        LOG.debug("Embedding stored successfully in Qdrant for doctor: {}", doctorId);
    }

    @Override
    public List<String> retrieveRelevantContext(String doctorId, String query, int maxResults) {
        LOG.info("Retrieving context from Qdrant for doctor: {} (maxResults: {})", doctorId, maxResults);

        Embedding queryEmbedding = embeddingModel.embed(query).content();

        EmbeddingSearchRequest searchRequest = EmbeddingSearchRequest.builder()
                .queryEmbedding(queryEmbedding)
                .maxResults(maxResults)
                .minScore(MIN_SCORE)
                .filter(MetadataFilterBuilder.metadataKey(DOCTOR_ID_KEY).isEqualTo(doctorId))
                .build();

        EmbeddingSearchResult<TextSegment> results = executeWithRetry(
                () -> embeddingStore.search(searchRequest), "retrieveRelevantContext", doctorId);

        if (results == null) {
            LOG.warn("Qdrant search returned null after retries for doctor: {}", doctorId);
            return Collections.emptyList();
        }

        List<String> contextSegments = results.matches().stream()
                .map(EmbeddingMatch::embedded)
                .map(TextSegment::text)
                .collect(Collectors.toList());

        LOG.info("Found {} relevant context segments from Qdrant for doctor: {}", contextSegments.size(), doctorId);
        return contextSegments;
    }

    /**
     * Execute an operation with exponential backoff retry for transient Qdrant failures.
     */
    private <T> T executeWithRetry(java.util.function.Supplier<T> operation, String operationName, String doctorId) {
        int attempt = 0;
        long backoffMs = INITIAL_BACKOFF_MS;

        while (true) {
            try {
                return operation.get();
            } catch (Exception e) {
                attempt++;
                if (attempt >= MAX_RETRIES) {
                    LOG.error("Qdrant operation '{}' failed after {} attempts for doctor: {}",
                            operationName, MAX_RETRIES, doctorId, e);
                    throw new RuntimeException(
                            "Qdrant " + operationName + " failed after " + MAX_RETRIES + " retries: " + e.getMessage(), e);
                }
                LOG.warn("Qdrant operation '{}' attempt {}/{} failed for doctor: {}, retrying in {}ms",
                        operationName, attempt, MAX_RETRIES, doctorId, backoffMs, e);
                try {
                    Thread.sleep(backoffMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("Interrupted during retry backoff", ie);
                }
                backoffMs *= 2; // exponential backoff
            }
        }
    }
}
