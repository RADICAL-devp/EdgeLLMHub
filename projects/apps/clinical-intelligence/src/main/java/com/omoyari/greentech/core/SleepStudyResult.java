package com.omoyari.greentech.core;

import io.micronaut.core.annotation.Introspected;

/**
 * Sleep study (polysomnography) result data.
 * Nested inside ConsultationInput.InvestigationOrder.
 */
@Introspected
public class SleepStudyResult {

    private double ahi; // Apnea-Hypopnea Index
    private int oxygenDesatIndex;
    private int minimumSpO2;
    private double sleepEfficiency;
    private double remAhi;
    private double supineAhi;

    public SleepStudyResult() {}

    public double getAhi() {
        return ahi;
    }

    public void setAhi(double ahi) {
        this.ahi = ahi;
    }

    public int getOxygenDesatIndex() {
        return oxygenDesatIndex;
    }

    public void setOxygenDesatIndex(int oxygenDesatIndex) {
        this.oxygenDesatIndex = oxygenDesatIndex;
    }

    public int getMinimumSpO2() {
        return minimumSpO2;
    }

    public void setMinimumSpO2(int minimumSpO2) {
        this.minimumSpO2 = minimumSpO2;
    }

    public double getSleepEfficiency() {
        return sleepEfficiency;
    }

    public void setSleepEfficiency(double sleepEfficiency) {
        this.sleepEfficiency = sleepEfficiency;
    }

    public double getRemAhi() {
        return remAhi;
    }

    public void setRemAhi(double remAhi) {
        this.remAhi = remAhi;
    }

    public double getSupineAhi() {
        return supineAhi;
    }

    public void setSupineAhi(double supineAhi) {
        this.supineAhi = supineAhi;
    }
}
