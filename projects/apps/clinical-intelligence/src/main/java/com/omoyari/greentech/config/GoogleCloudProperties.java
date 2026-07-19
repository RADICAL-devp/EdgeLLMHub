package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

/**
 * Configuration for Google Cloud services (Speech-to-Text, Translate).
 */
@ConfigurationProperties("clinical.google-cloud")
public class GoogleCloudProperties {
    private String projectId = "";
    private String location = "us-central1";
    private String sttModel = "chirp";
    private String glossaryId = "";

    public String getProjectId() { return projectId; }
    public void setProjectId(String projectId) { this.projectId = projectId; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public String getSttModel() { return sttModel; }
    public void setSttModel(String sttModel) { this.sttModel = sttModel; }

    public String getGlossaryId() { return glossaryId; }
    public void setGlossaryId(String glossaryId) { this.glossaryId = glossaryId; }
}
