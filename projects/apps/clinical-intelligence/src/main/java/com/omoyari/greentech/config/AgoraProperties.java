package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

/**
 * Configuration for Agora Video Call and Real-Time Transcription (RTT) services.
 */
@ConfigurationProperties("clinical.agora")
public class AgoraProperties {
    private String appId = "";
    private String appCertificate = "";
    private String customerId = "";
    private String customerSecret = "";
    private String rttRegion = "us";

    public String getAppId() { return appId; }
    public void setAppId(String appId) { this.appId = appId; }

    public String getAppCertificate() { return appCertificate; }
    public void setAppCertificate(String appCertificate) { this.appCertificate = appCertificate; }

    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }

    public String getCustomerSecret() { return customerSecret; }
    public void setCustomerSecret(String customerSecret) { this.customerSecret = customerSecret; }

    public String getRttRegion() { return rttRegion; }
    public void setRttRegion(String rttRegion) { this.rttRegion = rttRegion; }
}
