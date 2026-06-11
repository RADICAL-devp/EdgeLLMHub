package com.omoyari.greentech.application.ports;

import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.MedicalReport;
import java.util.List;
import java.util.Optional;

public interface SummaryRepository {
    Optional<MedicalReport> findReportById(String reportId);

    void saveSummary(ClinicalSummary summary);

    Optional<ClinicalSummary> findSummaryById(String summaryId);

    /**
     * Find all summaries generated for a specific doctor.
     */
    List<ClinicalSummary> findSummariesByDoctorId(String doctorId);
}
