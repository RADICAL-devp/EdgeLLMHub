package com.omoyari.greentech.infrastructure.vectorstore;

import io.micronaut.context.annotation.Requires;
import io.micronaut.health.HealthStatus;
import io.micronaut.management.health.indicator.HealthIndicator;
import io.micronaut.management.health.indicator.HealthResult;
import jakarta.inject.Singleton;
import java.util.Map;
import org.reactivestreams.Publisher;
import reactor.core.publisher.Mono;

/**
 * Health indicator for Qdrant connectivity.
 * Reports UP/DOWN at the /health endpoint when vector-store type is 'qdrant'.
 * Helps operations teams monitor Qdrant availability in production dashboards.
 */
@Singleton
@Requires(property = "clinical.vector-store.type", value = "qdrant")
public class QdrantHealthIndicator implements HealthIndicator {

    private final com.omoyari.greentech.config.VectorStoreProperties properties;

    public QdrantHealthIndicator(com.omoyari.greentech.config.VectorStoreProperties properties) {
        this.properties = properties;
    }

    @Override
    public Publisher<HealthResult> getResult() {
        return Mono.fromCallable(() -> {
            try {
                // Attempt a basic TCP connection to the Qdrant gRPC port
                try (java.net.Socket socket = new java.net.Socket()) {
                    socket.connect(
                            new java.net.InetSocketAddress(properties.getHost(), properties.getPort()),
                            2000); // 2 second timeout
                }

                return HealthResult.builder("qdrant")
                        .status(HealthStatus.UP)
                        .details(Map.of(
                                "host", properties.getHost(),
                                "port", properties.getPort(),
                                "collection", properties.getCollectionName(),
                                "tls", properties.isUseTls()))
                        .build();
            } catch (Exception e) {
                return HealthResult.builder("qdrant")
                        .status(HealthStatus.DOWN)
                        .details(Map.of(
                                "host", properties.getHost(),
                                "port", properties.getPort(),
                                "error", e.getMessage()))
                        .build();
            }
        });
    }
}
