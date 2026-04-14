package com.omoyari.greentech.api;

import com.omoyari.greentech.application.services.SummaryOrchestrator;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.Post;
import io.micronaut.security.annotation.Secured;
import java.security.Principal;

@Controller("/api/v1/summary")
@Secured({"DOCTOR", "ADMIN"})
public class SummaryController {

    private final SummaryOrchestrator orchestrator;

    public SummaryController(SummaryOrchestrator orchestrator) {
        this.orchestrator = orchestrator;
    }

    @Post("/generate")
    public SummaryResponse summarizePatientHistory(@Body SummaryRequest request, Principal principal) {
        return orchestrator.summarizePatientHistory(request, principal.getName());
    }

    @Get("/{summaryId}")
    public String getSummary(String summaryId) {
        // Placeholder for GET summary
        return "Summary for " + summaryId;
    }

    @Post("/{summaryId}/review")
    public String reviewSummary(String summaryId) {
        // Placeholder for Doctor review endpoint
        return "Review flagged for " + summaryId;
    }

    @Post("/{summaryId}/edit")
    public String editSummary(String summaryId, @Body String modifications) {
        // Placeholder for edit flow
        return "Modifications saved for " + summaryId;
    }
}
