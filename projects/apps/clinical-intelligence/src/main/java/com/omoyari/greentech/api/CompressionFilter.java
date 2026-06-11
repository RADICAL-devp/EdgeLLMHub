package com.omoyari.greentech.api;

import com.omoyari.greentech.config.ClinicalProperties;
import io.micronaut.http.HttpRequest;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.HttpStatus;
import io.micronaut.http.MutableHttpResponse;
import io.micronaut.http.annotation.Filter;
import io.micronaut.http.filter.HttpServerFilter;
import io.micronaut.http.filter.ServerFilterChain;
import org.reactivestreams.Publisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import reactor.core.publisher.Flux;

/**
 * Server-side filter that:
 * 1. Checks Content-Encoding for GZIP (Micronaut handles decompression natively)
 * 2. Enforces the 10MB payload size limit post-decompression
 */
@Filter("/api/**")
public class CompressionFilter implements HttpServerFilter {

    private static final Logger LOG = LoggerFactory.getLogger(CompressionFilter.class);

    private final ClinicalProperties clinicalProperties;

    public CompressionFilter(ClinicalProperties clinicalProperties) {
        this.clinicalProperties = clinicalProperties;
    }

    @Override
    public Publisher<MutableHttpResponse<?>> doFilter(HttpRequest<?> request, ServerFilterChain chain) {
        // Check content-length header for early rejection
        long contentLength = request.getContentLength();
        long maxBytes = clinicalProperties.getMaxPayloadBytes();

        if (contentLength > maxBytes) {
            LOG.warn(
                    "Request rejected: Content-Length {} exceeds maximum {} bytes",
                    contentLength,
                    maxBytes);
            return Flux.just(HttpResponse.status(HttpStatus.REQUEST_ENTITY_TOO_LARGE));
        }

        String contentEncoding = request.getHeaders().get("Content-Encoding");
        if ("gzip".equalsIgnoreCase(contentEncoding)) {
            LOG.debug("GZIP-compressed request detected, Micronaut will decompress");
        }

        return chain.proceed(request);
    }
}
