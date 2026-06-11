package com.omoyari.greentech.api;

import com.omoyari.greentech.core.ConsultationInput;
import io.micronaut.core.annotation.Introspected;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * API request for generating a clinical summary.
 * Accepts the full consultation JSON payload.
 */
@Introspected
public class SummaryRequest {

    @NotBlank
    private String patientId;

    @NotBlank
    private String doctorId;

    @NotNull
    private ConsultationInput consultation;

    private String sleepLabId;

    /**
     * If true, the request body was GZIP-compressed by the client.
     * The CompressionFilter handles decompression transparently.
     */
    private boolean compressed;

    public SummaryRequest() {}

    public SummaryRequest(String patientId, String doctorId, ConsultationInput consultation) {
        this.patientId = patientId;
        this.doctorId = doctorId;
        this.consultation = consultation;
    }

    public String getPatientId() {
        return patientId;
    }

    public void setPatientId(String patientId) {
        this.patientId = patientId;
    }

    public String getDoctorId() {
        return doctorId;
    }

    public void setDoctorId(String doctorId) {
        this.doctorId = doctorId;
    }

    public ConsultationInput getConsultation() {
        return consultation;
    }

    public void setConsultation(ConsultationInput consultation) {
        this.consultation = consultation;
    }

    public String getSleepLabId() {
        return sleepLabId;
    }

    public void setSleepLabId(String sleepLabId) {
        this.sleepLabId = sleepLabId;
    }

    public boolean isCompressed() {
        return compressed;
    }

    public void setCompressed(boolean compressed) {
        this.compressed = compressed;
    }
}
