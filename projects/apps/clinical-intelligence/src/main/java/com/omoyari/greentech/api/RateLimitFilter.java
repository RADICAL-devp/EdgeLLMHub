package com.omoyari.greentech.api;

import io.micronaut.http.HttpRequest;
import io.micronaut.http.MutableHttpResponse;
import io.micronaut.http.annotation.Filter;
import io.micronaut.http.filter.HttpServerFilter;
import io.micronaut.http.filter.ServerFilterChain;
import org.reactivestreams.Publisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Filter("/**")
public class RateLimitFilter implements HttpServerFilter {
    private static final Logger LOG = LoggerFactory.getLogger(RateLimitFilter.class);

    @Override
    public Publisher<MutableHttpResponse<?>> doFilter(HttpRequest<?> request, ServerFilterChain chain) {
        // Placeholder for Token-Bucket / Redis based rate limiting.
        LOG.debug("Rate limiting check for request: {}", request.getPath());
        return chain.proceed(request);
    }
}
