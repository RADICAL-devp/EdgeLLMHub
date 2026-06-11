package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

@ConfigurationProperties("clinical")
public class ClinicalProperties {
    private long maxPayloadBytes = 10_485_760L; // 10MB

    public long getMaxPayloadBytes() {
        return maxPayloadBytes;
    }

    public void setMaxPayloadBytes(long maxPayloadBytes) {
        this.maxPayloadBytes = maxPayloadBytes;
    }
}
