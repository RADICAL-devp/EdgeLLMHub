package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;
import io.micronaut.serde.annotation.Serdeable;

@Introspected
@Serdeable
public class StructuredNoteSections {
    private String chiefComplaint;
    private String historyOfPresentIllness;
    private String assessment;
    private String planAndFollowUp;

    public StructuredNoteSections() {}

    public String getChiefComplaint() {
        return chiefComplaint;
    }

    public void setChiefComplaint(String chiefComplaint) {
        this.chiefComplaint = chiefComplaint;
    }

    public String getHistoryOfPresentIllness() {
        return historyOfPresentIllness;
    }

    public void setHistoryOfPresentIllness(String historyOfPresentIllness) {
        this.historyOfPresentIllness = historyOfPresentIllness;
    }

    public String getAssessment() {
        return assessment;
    }

    public void setAssessment(String assessment) {
        this.assessment = assessment;
    }

    public String getPlanAndFollowUp() {
        return planAndFollowUp;
    }

    public void setPlanAndFollowUp(String planAndFollowUp) {
        this.planAndFollowUp = planAndFollowUp;
    }
}
