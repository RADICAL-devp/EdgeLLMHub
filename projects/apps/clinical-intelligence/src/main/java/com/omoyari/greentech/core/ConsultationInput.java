package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;
import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * Represents raw consultation data as received from the client.
 * Maps the Patient P → Doctor D → Sleep Test X → Sleep Lab S workflow.
 */
@Introspected
public class ConsultationInput {

    @NotBlank
    private String patientId;

    @NotBlank
    private String doctorId;

    private String consultationDate;
    private String sleepLabId;

    // Clinical content
    private String chiefComplaint;
    private String historyOfPresentIllness;
    private String pastMedicalHistory;
    private Vitals vitals;
    private String physicalExamination;
    private List<InvestigationOrder> investigationsOrdered;
    private List<String> currentMedications;
    private List<String> allergies;
    private String notes;

    public ConsultationInput() {}

    // --- Nested Types ---

    @Introspected
    public static class Vitals {
        private String bp;
        private String hr;
        private String spo2;
        private String temp;
        private String weight;
        private String height;
        private String bmi;

        public Vitals() {}

        public String getBp() {
            return bp;
        }

        public void setBp(String bp) {
            this.bp = bp;
        }

        public String getHr() {
            return hr;
        }

        public void setHr(String hr) {
            this.hr = hr;
        }

        public String getSpo2() {
            return spo2;
        }

        public void setSpo2(String spo2) {
            this.spo2 = spo2;
        }

        public String getTemp() {
            return temp;
        }

        public void setTemp(String temp) {
            this.temp = temp;
        }

        public String getWeight() {
            return weight;
        }

        public void setWeight(String weight) {
            this.weight = weight;
        }

        public String getHeight() {
            return height;
        }

        public void setHeight(String height) {
            this.height = height;
        }

        public String getBmi() {
            return bmi;
        }

        public void setBmi(String bmi) {
            this.bmi = bmi;
        }
    }

    @Introspected
    public static class InvestigationOrder {
        private String testName;
        private String sleepLabId;
        private String status;
        private SleepStudyResult results;

        public InvestigationOrder() {}

        public String getTestName() {
            return testName;
        }

        public void setTestName(String testName) {
            this.testName = testName;
        }

        public String getSleepLabId() {
            return sleepLabId;
        }

        public void setSleepLabId(String sleepLabId) {
            this.sleepLabId = sleepLabId;
        }

        public String getStatus() {
            return status;
        }

        public void setStatus(String status) {
            this.status = status;
        }

        public SleepStudyResult getResults() {
            return results;
        }

        public void setResults(SleepStudyResult results) {
            this.results = results;
        }
    }

    // --- Getters and Setters ---

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

    public String getConsultationDate() {
        return consultationDate;
    }

    public void setConsultationDate(String consultationDate) {
        this.consultationDate = consultationDate;
    }

    public String getSleepLabId() {
        return sleepLabId;
    }

    public void setSleepLabId(String sleepLabId) {
        this.sleepLabId = sleepLabId;
    }

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

    public String getPastMedicalHistory() {
        return pastMedicalHistory;
    }

    public void setPastMedicalHistory(String pastMedicalHistory) {
        this.pastMedicalHistory = pastMedicalHistory;
    }

    public Vitals getVitals() {
        return vitals;
    }

    public void setVitals(Vitals vitals) {
        this.vitals = vitals;
    }

    public String getPhysicalExamination() {
        return physicalExamination;
    }

    public void setPhysicalExamination(String physicalExamination) {
        this.physicalExamination = physicalExamination;
    }

    public List<InvestigationOrder> getInvestigationsOrdered() {
        return investigationsOrdered;
    }

    public void setInvestigationsOrdered(List<InvestigationOrder> investigationsOrdered) {
        this.investigationsOrdered = investigationsOrdered;
    }

    public List<String> getCurrentMedications() {
        return currentMedications;
    }

    public void setCurrentMedications(List<String> currentMedications) {
        this.currentMedications = currentMedications;
    }

    public List<String> getAllergies() {
        return allergies;
    }

    public void setAllergies(List<String> allergies) {
        this.allergies = allergies;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }
}
