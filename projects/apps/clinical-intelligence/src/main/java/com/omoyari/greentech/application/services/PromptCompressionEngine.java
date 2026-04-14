package com.omoyari.greentech.application.services;

import jakarta.inject.Singleton;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Singleton
public class PromptCompressionEngine {

    private static final Pattern LAB_REGEX = Pattern.compile("(?i)(BP|HR|Temp)\\s*:\\s*(\\d+[/\\.]?\\d*)");
    private static final Pattern CONDITION_REGEX = Pattern.compile("(?i)(hypertension|diabetes|asthma)");

    public String compress(String rawText) {
        if (rawText == null || rawText.isBlank()) {
            return "";
        }

        // 1. Text cleaning
        String cleanedText = rawText.replaceAll("\\s+", " ").trim();

        // 2. Entity extraction and deduplication
        Set<String> labs = extractEntities(cleanedText, LAB_REGEX);
        Set<String> conditions = extractEntities(cleanedText, CONDITION_REGEX);

        // 3. Structuring into a deterministic JSON-like format
        StringBuilder compressed = new StringBuilder("{\n");
        compressed
                .append("  \"conditions\": [")
                .append(String.join(", ", conditions))
                .append("],\n");
        compressed.append("  \"labs\": [").append(String.join(", ", labs)).append("]\n");
        compressed.append("}");

        return compressed.toString();
    }

    private Set<String> extractEntities(String text, Pattern pattern) {
        Set<String> entities = new HashSet<>();
        Matcher matcher = pattern.matcher(text);
        while (matcher.find()) {
            entities.add("\"" + matcher.group() + "\"");
        }
        return entities;
    }
}
