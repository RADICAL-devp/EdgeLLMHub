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
}
