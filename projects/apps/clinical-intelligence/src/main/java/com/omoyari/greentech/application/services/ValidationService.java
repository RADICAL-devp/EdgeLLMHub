package com.omoyari.greentech.application.services;

import com.omoyari.greentech.common.ValidationFailedException;
import jakarta.inject.Singleton;

@Singleton
public class ValidationService {

    public void validateSummaryRequest(String[] documentIds) {
        if (documentIds == null || documentIds.length == 0) {
            throw new ValidationFailedException("At least one document ID is required.");
        }
    }

    public void validateLlmResponse(String jsonResponse) {
        if (jsonResponse == null || !jsonResponse.contains("patientStatus")) {
            throw new ValidationFailedException("LLM Response failed schema validation: Missing patientStatus.");
        }

        // Domain validation (medical constraints placeholder)
        if (jsonResponse.contains("fatal") && !jsonResponse.contains("reviewRequired")) {
            throw new ValidationFailedException("LLM Response failed domain bounds constraint.");
        }
    }
}
