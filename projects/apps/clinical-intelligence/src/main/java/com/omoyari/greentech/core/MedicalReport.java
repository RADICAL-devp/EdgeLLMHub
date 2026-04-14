package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;

@Introspected
public class MedicalReport {
    private String id;
    private String patientId;
    private String encryptedPayload;

    public MedicalReport() {}

    public MedicalReport(String id, String patientId, String encryptedPayload) {
        this.id = id;
        this.patientId = patientId;
        this.encryptedPayload = encryptedPayload;
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

    public String getEncryptedPayload() {
        return encryptedPayload;
    }

    public void setEncryptedPayload(String encryptedPayload) {
        this.encryptedPayload = encryptedPayload;
    }
}
