package com.omoyari.greentech.config;

import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.inmemory.InMemoryEmbeddingStore;
import io.micronaut.context.annotation.Factory;
import jakarta.inject.Singleton;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Micronaut factory for LangChain4J beans.
 * Wires up the ChatLanguageModel, EmbeddingModel, and EmbeddingStore as injectable singletons.
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
     * In-memory vector store. Doctor-specific partitioning is handled at the
     * adapter level via metadata filtering — the store itself is shared.
     * Swap this bean for QdrantEmbeddingStore in production.
     */
    @Singleton
    public EmbeddingStore<TextSegment> embeddingStore() {
        LOG.info("Using InMemoryEmbeddingStore (swap to Qdrant for production)");
        return new InMemoryEmbeddingStore<>();
    }
}
