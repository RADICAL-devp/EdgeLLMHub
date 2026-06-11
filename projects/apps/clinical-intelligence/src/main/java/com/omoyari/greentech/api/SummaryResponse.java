package com.omoyari.greentech.api;

import com.omoyari.greentech.core.StructuredSummary;
import io.micronaut.core.annotation.Introspected;

/**
 * API response containing the structured clinical summary.
 */
@Introspected
public class SummaryResponse {

    private String summaryId;
    private StructuredSummary summary;
    private String generatedAt;
    private String doctorId;
    private String patientId;
    private boolean contextEnriched;

    public SummaryResponse() {}

    public SummaryResponse(
            String summaryId,
            StructuredSummary summary,
            String generatedAt,
            String doctorId,
            String patientId,
            boolean contextEnriched) {
        this.summaryId = summaryId;
        this.summary = summary;
        this.generatedAt = generatedAt;
        this.doctorId = doctorId;
        this.patientId = patientId;
        this.contextEnriched = contextEnriched;
    }

    public String getSummaryId() {
        return summaryId;
    }

    public void setSummaryId(String summaryId) {
        this.summaryId = summaryId;
    }

    public StructuredSummary getSummary() {
        return summary;
    }

    public void setSummary(StructuredSummary summary) {
        this.summary = summary;
    }

    public String getGeneratedAt() {
        return generatedAt;
    }

    public void setGeneratedAt(String generatedAt) {
        this.generatedAt = generatedAt;
    }

    public String getDoctorId() {
        return doctorId;
    }

    public void setDoctorId(String doctorId) {
        this.doctorId = doctorId;
    }

    public String getPatientId() {
        return patientId;
    }

    public void setPatientId(String patientId) {
        this.patientId = patientId;
    }

    public boolean isContextEnriched() {
        return contextEnriched;
    }

    public void setContextEnriched(boolean contextEnriched) {
        this.contextEnriched = contextEnriched;
    }
}
