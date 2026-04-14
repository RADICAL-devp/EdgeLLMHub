package com.omoyari.greentech.api;

import io.micronaut.core.annotation.Introspected;

@Introspected
public class SummaryResponse {
    private String summaryId;
    private String structuredContent;

    public SummaryResponse() {}

    public SummaryResponse(String summaryId, String structuredContent) {
        this.summaryId = summaryId;
        this.structuredContent = structuredContent;
    }

    public String getSummaryId() {
        return summaryId;
    }

    public void setSummaryId(String summaryId) {
        this.summaryId = summaryId;
    }

    public String getStructuredContent() {
        return structuredContent;
    }

    public void setStructuredContent(String structuredContent) {
        this.structuredContent = structuredContent;
    }
}
