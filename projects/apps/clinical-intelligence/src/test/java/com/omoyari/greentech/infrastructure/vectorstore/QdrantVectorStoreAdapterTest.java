package com.omoyari.greentech.infrastructure.vectorstore;

import com.omoyari.greentech.application.ports.VectorStorePort;
import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.output.Response;
import dev.langchain4j.store.embedding.EmbeddingMatch;
import dev.langchain4j.store.embedding.EmbeddingSearchRequest;
import dev.langchain4j.store.embedding.EmbeddingSearchResult;
import dev.langchain4j.store.embedding.EmbeddingStore;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for QdrantVectorStoreAdapter.
 * Uses manual stub implementations (no Mockito — JDK 25 ByteBuddy incompatibility).
 * These tests validate the adapter logic in isolation, independent of a real Qdrant server.
 */
class QdrantVectorStoreAdapterTest {

    private StubEmbeddingStore stubStore;
    private StubEmbeddingModel stubModel;
    private VectorStorePort adapter;

    @BeforeEach
    void setUp() {
        stubStore = new StubEmbeddingStore();
        stubModel = new StubEmbeddingModel();
        adapter = new QdrantVectorStoreAdapter(stubStore, stubModel);
    }

    @Test
    void storeEmbedding_addsToStoreWithDoctorIdMetadata() {
        adapter.storeEmbedding("DR-001", "Patient complaint: headache", Map.of("patientId", "PAT-1"));

        assertEquals(1, stubStore.getStoredCount());
        TextSegment stored = stubStore.getLastStoredSegment();
        assertEquals("Patient complaint: headache", stored.text());
        assertEquals("DR-001", stored.metadata().getString("doctorId"));
        assertEquals("PAT-1", stored.metadata().getString("patientId"));
    }

    @Test
    void storeEmbedding_handlesNullMetadata() {
        adapter.storeEmbedding("DR-002", "Some content", null);

        assertEquals(1, stubStore.getStoredCount());
        assertEquals("DR-002", stubStore.getLastStoredSegment().metadata().getString("doctorId"));
    }

    @Test
    void retrieveRelevantContext_returnsMatchingSegments() {
        // Pre-populate the stub with results
        stubStore.setSearchResults(List.of(
                TextSegment.from("Previous diagnosis: OSA", new Metadata()),
                TextSegment.from("Past vitals: BP 140/90", new Metadata())));

        List<String> context = adapter.retrieveRelevantContext("DR-001", "current complaint", 5);

        assertEquals(2, context.size());
        assertEquals("Previous diagnosis: OSA", context.get(0));
        assertEquals("Past vitals: BP 140/90", context.get(1));
    }

    @Test
    void retrieveRelevantContext_returnsEmptyListWhenNoMatches() {
        stubStore.setSearchResults(List.of());

        List<String> context = adapter.retrieveRelevantContext("DR-999", "unknown query", 3);

        assertTrue(context.isEmpty());
    }

    // ---- Manual Stub Implementations (no Mockito) ----

    /**
     * Stub EmbeddingModel that returns a fixed-dimension zero vector.
     */
    static class StubEmbeddingModel implements EmbeddingModel {
        private static final float[] ZERO_VECTOR = new float[384]; // matches all-MiniLM-L6-v2 dimension

        @Override
        public Response<Embedding> embed(String text) {
            return Response.from(new Embedding(ZERO_VECTOR));
        }

        @Override
        public Response<Embedding> embed(TextSegment segment) {
            return Response.from(new Embedding(ZERO_VECTOR));
        }

        @Override
        public Response<List<Embedding>> embedAll(List<TextSegment> segments) {
            List<Embedding> embeddings = segments.stream()
                    .map(s -> new Embedding(ZERO_VECTOR))
                    .toList();
            return Response.from(embeddings);
        }
    }

    /**
     * Stub EmbeddingStore that records what was stored and returns preconfigured search results.
     */
    static class StubEmbeddingStore implements EmbeddingStore<TextSegment> {
        private int storedCount = 0;
        private TextSegment lastStoredSegment;
        private List<TextSegment> searchResults = List.of();

        void setSearchResults(List<TextSegment> results) {
            this.searchResults = results;
        }

        int getStoredCount() {
            return storedCount;
        }

        TextSegment getLastStoredSegment() {
            return lastStoredSegment;
        }

        @Override
        public String add(Embedding embedding) {
            storedCount++;
            return "stub-id-" + storedCount;
        }

        @Override
        public void add(String id, Embedding embedding) {
            storedCount++;
        }

        @Override
        public String add(Embedding embedding, TextSegment textSegment) {
            storedCount++;
            lastStoredSegment = textSegment;
            return "stub-id-" + storedCount;
        }

        @Override
        public List<String> addAll(List<Embedding> embeddings) {
            storedCount += embeddings.size();
            return embeddings.stream().map(e -> "stub-id-" + storedCount).toList();
        }

        @Override
        public EmbeddingSearchResult<TextSegment> search(EmbeddingSearchRequest request) {
            List<EmbeddingMatch<TextSegment>> matches = searchResults.stream()
                    .map(segment -> new EmbeddingMatch<>(0.9, "match-id", new Embedding(new float[384]), segment))
                    .toList();
            return new EmbeddingSearchResult<>(matches);
        }
    }
}
