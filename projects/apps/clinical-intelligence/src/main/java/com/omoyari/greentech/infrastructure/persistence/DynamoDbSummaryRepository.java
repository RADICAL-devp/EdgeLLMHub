package com.omoyari.greentech.infrastructure.persistence;

import com.omoyari.greentech.application.ports.SummaryRepository;
import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.MedicalReport;
import jakarta.inject.Singleton;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

@Singleton
public class DynamoDbSummaryRepository implements SummaryRepository {

    // In-memory representation of DynamoDB tables for the skeleton
    private final Map<String, MedicalReport> reportsTable = new ConcurrentHashMap<>();
    private final Map<String, ClinicalSummary> summariesTable = new ConcurrentHashMap<>();

    public DynamoDbSummaryRepository() {
        // Seed dummy data: Base64 encoding of "Patient has a history of high blood pressure."
        String encodedPayload =
                Base64.getEncoder().encodeToString("Patient has a history of high blood pressure.".getBytes());
        reportsTable.put("doc123", new MedicalReport("doc123", "pat999", encodedPayload));
    }

    @Override
    public Optional<MedicalReport> findReportById(String reportId) {
        return Optional.ofNullable(reportsTable.get(reportId));
    }

    @Override
    public void saveSummary(ClinicalSummary summary) {
        summariesTable.put(summary.getId(), summary);
    }

    @Override
    public Optional<ClinicalSummary> findSummaryById(String summaryId) {
        return Optional.ofNullable(summariesTable.get(summaryId));
    }
}
