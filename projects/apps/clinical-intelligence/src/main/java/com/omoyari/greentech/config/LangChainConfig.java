package com.omoyari.greentech.config;

import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.inmemory.InMemoryEmbeddingStore;
import dev.langchain4j.store.embedding.qdrant.QdrantEmbeddingStore;
import io.micronaut.context.annotation.Factory;
import io.micronaut.context.annotation.Requires;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Micronaut factory for LangChain4J beans.
 * Wires up the ChatLanguageModel, EmbeddingModel, and EmbeddingStore as injectable singletons.
 * The EmbeddingStore bean is conditionally loaded based on the 'clinical.vector-store.type' property.
 */
@Factory
public class LangChainConfig {

    private static final Logger LOG = LoggerFactory.getLogger(LangChainConfig.class);

    @Singleton
    public ChatLanguageModel chatLanguageModel(LlmProperties props) {
        LOG.info("Configuring ChatLanguageModel: provider={}, model={}", props.getProvider(), props.getModelName());

        return OpenAiChatModel.builder()
                .baseUrl(props.getApiUrl())
                .apiKey(props.getApiKey())
                .modelName(props.getModelName())
                .temperature(props.getTemperature())
                .maxTokens(props.getMaxTokens())
                .build();
    }

    /**
     * Local embedding model — runs entirely offline, no API key required.
     * all-MiniLM-L6-v2 produces 384-dimension embeddings, suitable for
     * semantic search over clinical consultation text.
     */
    @Singleton
    public EmbeddingModel embeddingModel() {
        LOG.info("Loading local embedding model: all-MiniLM-L6-v2");
        return new AllMiniLmL6V2EmbeddingModel();
    }

    /**
     * In-memory vector store — used in development mode.
     * Doctor-specific partitioning is handled at the adapter level via metadata filtering.
     */
    @Singleton
    @Requires(property = "clinical.vector-store.type", value = "in-memory")
    public EmbeddingStore<TextSegment> inMemoryEmbeddingStore() {
        LOG.info("Using InMemoryEmbeddingStore (dev mode)");
        return new InMemoryEmbeddingStore<>();
    }

    /**
     * Qdrant vector store — used in production mode.
     * Connects to a Qdrant instance via gRPC for persistent, scalable vector search.
     * The collection must be pre-created with 384 dimensions (matching all-MiniLM-L6-v2).
     */
    @Singleton
    @Requires(property = "clinical.vector-store.type", value = "qdrant")
    public EmbeddingStore<TextSegment> qdrantEmbeddingStore(VectorStoreProperties props) {
        LOG.info("Configuring QdrantEmbeddingStore: host={}, port={}, collection={}, tls={}",
                props.getHost(), props.getPort(), props.getCollectionName(), props.isUseTls());

        QdrantEmbeddingStore.Builder builder = QdrantEmbeddingStore.builder()
                .host(props.getHost())
                .port(props.getPort())
                .collectionName(props.getCollectionName())
                .useTls(props.isUseTls());

        if (props.getApiKey() != null && !props.getApiKey().isBlank()) {
            builder.apiKey(props.getApiKey());
        }

        return builder.build();
    }
}
