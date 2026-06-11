package com.omoyari.greentech.application.services;

import com.omoyari.greentech.common.ValidationFailedException;
import com.omoyari.greentech.core.ConsultationInput;
import com.omoyari.greentech.core.StructuredSummary;
import jakarta.inject.Singleton;

/**
 * Validates both incoming consultation data and outgoing LLM-generated summaries.
 */
@Singleton
public class ValidationService {

    private static final long MAX_PAYLOAD_BYTES = 10_485_760L; // 10MB

    /**
     * Validate the incoming consultation input for required fields.
     */
    public void validateConsultationInput(ConsultationInput input) {
        if (input == null) {
            throw new ValidationFailedException("Consultation input cannot be null.");
        }
        if (input.getPatientId() == null || input.getPatientId().isBlank()) {
            throw new ValidationFailedException("Patient ID is required.");
        }
        if (input.getDoctorId() == null || input.getDoctorId().isBlank()) {
            throw new ValidationFailedException("Doctor ID is required.");
        }
        if (input.getChiefComplaint() == null || input.getChiefComplaint().isBlank()) {
            throw new ValidationFailedException("Chief complaint is required for summarization.");
        }
    }

    /**
     * Validate the LLM-generated structured summary has all 7 required fields.
     */
    public void validateStructuredSummary(StructuredSummary summary) {
        if (summary == null) {
            throw new ValidationFailedException("LLM returned null summary.");
        }
        if (!summary.isComplete()) {
            throw new ValidationFailedException(
                    "LLM response missing required fields. All 7 summary fields must be non-empty: "
                            + "complaint, pastHistory, vitals, physicalExamination, investigationOrdered, diagnosis, advice.");
        }
    }

    /**
     * Validate that the serialized payload size doesn't exceed the 10MB limit.
     */
    public void validatePayloadSize(String serializedPayload) {
        if (serializedPayload != null && serializedPayload.getBytes().length > MAX_PAYLOAD_BYTES) {
            throw new ValidationFailedException("Payload exceeds maximum allowed size of 10MB.");
        }
    }
}
