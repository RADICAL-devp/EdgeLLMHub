package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

@ConfigurationProperties("clinical.encryption")
public class EncryptionProperties {
    private String key = "dGhpc0lzQTMyQnl0ZUtleUZvckFFUzI1NkdDTSE=";

    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }
}
