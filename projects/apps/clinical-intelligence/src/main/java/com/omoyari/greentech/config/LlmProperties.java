package com.omoyari.greentech.config;

import io.micronaut.context.annotation.ConfigurationProperties;

@ConfigurationProperties("clinical.llm")
public class LlmProperties {
    private String modelName = "meta.llama3-70b-instruct-v1:0";
    private double temperature = 0.1;
    private int maxTokens = 2000;

    public String getModelName() {
        return modelName;
    }

    public void setModelName(String modelName) {
        this.modelName = modelName;
    }

    public double getTemperature() {
        return temperature;
    }

    public void setTemperature(double temperature) {
        this.temperature = temperature;
    }

    public int getMaxTokens() {
        return maxTokens;
    }

    public void setMaxTokens(int maxTokens) {
        this.maxTokens = maxTokens;
    }
}
