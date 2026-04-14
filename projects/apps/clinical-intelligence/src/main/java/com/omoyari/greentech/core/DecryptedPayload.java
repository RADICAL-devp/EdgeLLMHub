package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;

@Introspected
public class DecryptedPayload {
    private String content;

    public DecryptedPayload() {}

    public DecryptedPayload(String content) {
        this.content = content;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}
