package com.omoyari.greentech.api;

import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.rules.SecurityRule;

@Controller("/gateway")
@Secured(SecurityRule.IS_AUTHENTICATED)
public class GatewayController {

    @Get("/health")
    @Secured(SecurityRule.IS_ANONYMOUS)
    public String health() {
        return "Gateway is up";
    }

    // Placeholder for routing downstream requests
}
