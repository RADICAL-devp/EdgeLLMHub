package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;
import io.micronaut.serde.annotation.Serdeable;
import java.time.Instant;
import java.util.List;
import java.util.Map;

@Introspected
@Serdeable
public class DoctorNote {
    private String noteId;
    private String consultationId;
    private String patientId;
    private String doctorId;
    
    private String rawText;
    private String cleanedText;
    private StructuredNoteSections structuredSections;
    private ExtractedClinicalFields extractedFields;
    private String recap;
    
    private String status; // draft, finalized
    private String modelVersion;
    
    private List<String> aiGeneratedFields;
    private List<String> doctorEditedFields;
    
    private Instant createdAt;
    private Instant updatedAt;
    private Instant syncedAt;

    public DoctorNote() {}

    public String getNoteId() { return noteId; }
    public void setNoteId(String noteId) { this.noteId = noteId; }

    public String getConsultationId() { return consultationId; }
    public void setConsultationId(String consultationId) { this.consultationId = consultationId; }

    public String getPatientId() { return patientId; }
    public void setPatientId(String patientId) { this.patientId = patientId; }

    public String getDoctorId() { return doctorId; }
    public void setDoctorId(String doctorId) { this.doctorId = doctorId; }

    public String getRawText() { return rawText; }
    public void setRawText(String rawText) { this.rawText = rawText; }

    public String getCleanedText() { return cleanedText; }
    public void setCleanedText(String cleanedText) { this.cleanedText = cleanedText; }

    public StructuredNoteSections getStructuredSections() { return structuredSections; }
    public void setStructuredSections(StructuredNoteSections structuredSections) { this.structuredSections = structuredSections; }

    public ExtractedClinicalFields getExtractedFields() { return extractedFields; }
    public void setExtractedFields(ExtractedClinicalFields extractedFields) { this.extractedFields = extractedFields; }

    public String getRecap() { return recap; }
    public void setRecap(String recap) { this.recap = recap; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getModelVersion() { return modelVersion; }
    public void setModelVersion(String modelVersion) { this.modelVersion = modelVersion; }

    public List<String> getAiGeneratedFields() { return aiGeneratedFields; }
    public void setAiGeneratedFields(List<String> aiGeneratedFields) { this.aiGeneratedFields = aiGeneratedFields; }

    public List<String> getDoctorEditedFields() { return doctorEditedFields; }
    public void setDoctorEditedFields(List<String> doctorEditedFields) { this.doctorEditedFields = doctorEditedFields; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    public Instant getSyncedAt() { return syncedAt; }
    public void setSyncedAt(Instant syncedAt) { this.syncedAt = syncedAt; }
}
