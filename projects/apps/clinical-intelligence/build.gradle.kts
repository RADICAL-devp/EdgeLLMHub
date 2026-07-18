plugins {
    id("buildlogic.micronaut-application-conventions")
}

application {
    mainClass.set("com.omoyari.greentech.Application")
}

dependencies {
    implementation("io.micronaut.validation:micronaut-validation")
    implementation("io.micronaut.security:micronaut-security-jwt")
    implementation("jakarta.validation:jakarta.validation-api")

    // AWS SDK & utilities placeholder
    implementation("org.apache.commons:commons-text")

    // Runtime engines for yaml configuration processing
    runtimeOnly("org.yaml:snakeyaml")

    // Slf4j Simple Logger hook
    runtimeOnly("org.slf4j:slf4j-simple")

    // Project Reactor (Used in dummy authentication Mono.just)
    implementation("io.projectreactor:reactor-core")

    // Health indicators and management endpoints
    implementation("io.micronaut:micronaut-management")

    // --- LangChain4J ---
    implementation("dev.langchain4j:langchain4j:1.0.0-beta3")
    implementation("dev.langchain4j:langchain4j-open-ai:1.0.0-beta3")

    // Local embedding model (runs offline, no API key needed)
    implementation("dev.langchain4j:langchain4j-embeddings-all-minilm-l6-v2:1.0.0-beta3")

    // Qdrant vector store (production-grade persistent vector DB)
    implementation("dev.langchain4j:langchain4j-qdrant:1.0.0-beta3")

    // Jackson for JSON serialization of structured summaries
    implementation("com.fasterxml.jackson.core:jackson-databind:2.18.4")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.18.4")
    implementation("io.micronaut:micronaut-jackson-databind")

    // --- Phase 2: Transcription & Translation ---
    // Google Cloud Speech-to-Text V2 (Chirp model for Indian languages)
    implementation("com.google.cloud:google-cloud-speech:4.88.0")

    // Google Cloud Translate V3 (regional language → English)
    implementation("com.google.cloud:google-cloud-translate:2.93.0")

    // Test dependencies
    testImplementation("io.micronaut.test:micronaut-test-junit5")
    testImplementation("org.mockito:mockito-core:5.14.2")
}
