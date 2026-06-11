package com.omoyari.greentech.infrastructure.persistence;

import com.omoyari.greentech.application.ports.SummaryRepository;
import com.omoyari.greentech.core.ClinicalSummary;
import com.omoyari.greentech.core.MedicalReport;
import jakarta.inject.Singleton;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * In-memory repository simulating DynamoDB for the POC.
 * Replace with real DynamoDB SDK calls for production.
 */
@Singleton
public class DynamoDbSummaryRepository implements SummaryRepository {

    // In-memory representation of DynamoDB tables for the skeleton
    private final Map<String, MedicalReport> reportsTable = new ConcurrentHashMap<>();
    private final Map<String, ClinicalSummary> summariesTable = new ConcurrentHashMap<>();

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

    @Override
    public List<ClinicalSummary> findSummariesByDoctorId(String doctorId) {
        return summariesTable.values().stream()
                .filter(s -> doctorId.equals(s.getDoctorId()))
                .collect(Collectors.toList());
    }
}
