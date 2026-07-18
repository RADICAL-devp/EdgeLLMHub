package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

@ConfigurationProperties("clinical.vector-store")
public class VectorStoreProperties {
    private String type = "in-memory";
    private String host = "localhost";
    private int port = 6334;
    private String collectionName = "clinical-embeddings";
    private String apiKey = "";
    private boolean useTls = false;

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public String getCollectionName() {
        return collectionName;
    }

    public void setCollectionName(String collectionName) {
        this.collectionName = collectionName;
    }

    public String getApiKey() {
        return apiKey;
    }

    public void setApiKey(String apiKey) {
        this.apiKey = apiKey;
    }

    public boolean isUseTls() {
        return useTls;
    }

    public void setUseTls(boolean useTls) {
        this.useTls = useTls;
    }
}
