package com.omoyari.greentech.api;

import io.micronaut.core.annotation.Introspected;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

@Introspected
public class SummaryRequest {
    @NotNull
    private List<@NotBlank String> documentIds;

    public SummaryRequest() {}

    public SummaryRequest(List<String> documentIds) {
        this.documentIds = documentIds;
    }

    public List<String> getDocumentIds() {
        return documentIds;
    }

    public void setDocumentIds(List<String> documentIds) {
        this.documentIds = documentIds;
    }
}
