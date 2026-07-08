package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;
import io.micronaut.serde.annotation.Serdeable;
import java.util.List;

@Introspected
@Serdeable
public class ExtractedClinicalFields {
    private List<String> symptoms;
    private String duration;
    private List<String> medications;
    private List<String> allergies;
    private List<String> testsRecommended;
    private List<String> followUpActions;
    private String provisionalDiagnosis;

    public ExtractedClinicalFields() {}

    public List<String> getSymptoms() {
        return symptoms;
    }

    public void setSymptoms(List<String> symptoms) {
        this.symptoms = symptoms;
    }

    public String getDuration() {
        return duration;
    }

    public void setDuration(String duration) {
        this.duration = duration;
    }

    public List<String> getMedications() {
        return medications;
    }

    public void setMedications(List<String> medications) {
        this.medications = medications;
    }

    public List<String> getAllergies() {
        return allergies;
    }

    public void setAllergies(List<String> allergies) {
        this.allergies = allergies;
    }

    public List<String> getTestsRecommended() {
        return testsRecommended;
    }

    public void setTestsRecommended(List<String> testsRecommended) {
        this.testsRecommended = testsRecommended;
    }

    public List<String> getFollowUpActions() {
        return followUpActions;
    }

    public void setFollowUpActions(List<String> followUpActions) {
        this.followUpActions = followUpActions;
    }

    public String getProvisionalDiagnosis() {
        return provisionalDiagnosis;
    }

    public void setProvisionalDiagnosis(String provisionalDiagnosis) {
        this.provisionalDiagnosis = provisionalDiagnosis;
    }
}
