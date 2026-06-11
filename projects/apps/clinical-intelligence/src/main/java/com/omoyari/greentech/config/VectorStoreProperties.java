package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

@ConfigurationProperties("clinical.vector-store")
public class VectorStoreProperties {
    private String type = "in-memory";

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }
}
