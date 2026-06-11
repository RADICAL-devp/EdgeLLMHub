package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;

/**
 * The 7-field structured output from the LangChain4J summarization.
 * This is what the LLM extracts from raw consultation data.
 */
@Introspected
public class StructuredSummary {

    private String complaint;
    private String pastHistory;
    private String vitals;
    private String physicalExamination;
    private String investigationOrdered;
    private String diagnosis;
    private String advice;

    public StructuredSummary() {}

    public StructuredSummary(
            String complaint,
            String pastHistory,
            String vitals,
            String physicalExamination,
            String investigationOrdered,
            String diagnosis,
            String advice) {
        this.complaint = complaint;
        this.pastHistory = pastHistory;
        this.vitals = vitals;
        this.physicalExamination = physicalExamination;
        this.investigationOrdered = investigationOrdered;
        this.diagnosis = diagnosis;
        this.advice = advice;
    }

    public String getComplaint() {
        return complaint;
    }

    public void setComplaint(String complaint) {
        this.complaint = complaint;
    }

    public String getPastHistory() {
        return pastHistory;
    }

    public void setPastHistory(String pastHistory) {
        this.pastHistory = pastHistory;
    }

    public String getVitals() {
        return vitals;
    }

    public void setVitals(String vitals) {
        this.vitals = vitals;
    }

    public String getPhysicalExamination() {
        return physicalExamination;
    }

    public void setPhysicalExamination(String physicalExamination) {
        this.physicalExamination = physicalExamination;
    }

    public String getInvestigationOrdered() {
        return investigationOrdered;
    }

    public void setInvestigationOrdered(String investigationOrdered) {
        this.investigationOrdered = investigationOrdered;
    }

    public String getDiagnosis() {
        return diagnosis;
    }

    public void setDiagnosis(String diagnosis) {
        this.diagnosis = diagnosis;
    }

    public String getAdvice() {
        return advice;
    }

    public void setAdvice(String advice) {
        this.advice = advice;
    }

    /**
     * Checks whether all 7 required fields are non-null and non-blank.
     */
    public boolean isComplete() {
        return isPresent(complaint)
                && isPresent(pastHistory)
                && isPresent(vitals)
                && isPresent(physicalExamination)
                && isPresent(investigationOrdered)
                && isPresent(diagnosis)
                && isPresent(advice);
    }

    private boolean isPresent(String value) {
        return value != null && !value.isBlank();
    }
}
