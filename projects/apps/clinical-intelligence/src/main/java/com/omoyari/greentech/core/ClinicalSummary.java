package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;

@Introspected
public class ClinicalSummary {
    private String id;
    private String patientId;
    private String rawSummary;
    private String generatedAt;

    public ClinicalSummary() {}

    public ClinicalSummary(String id, String patientId, String rawSummary, String generatedAt) {
        this.id = id;
        this.patientId = patientId;
        this.rawSummary = rawSummary;
        this.generatedAt = generatedAt;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getPatientId() {
        return patientId;
    }

    public void setPatientId(String patientId) {
        this.patientId = patientId;
    }

    public String getRawSummary() {
        return rawSummary;
    }

    public void setRawSummary(String rawSummary) {
        this.rawSummary = rawSummary;
    }

    public String getGeneratedAt() {
        return generatedAt;
    }

    public void setGeneratedAt(String generatedAt) {
        this.generatedAt = generatedAt;
    }
}
