plugins {
    id("buildlogic.java-common-conventions")
    id("io.micronaut.application")
}

micronaut {
    runtime("netty") // Reactive HTTP server
    testRuntime("junit5")
    processing {
        incremental(true)
        annotations("com.omoyari.greentech.*")
    }
}
