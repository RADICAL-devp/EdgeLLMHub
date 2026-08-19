package com.omoyari.greentech.api;

import io.micronaut.http.HttpResponse;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Post;
import io.micronaut.security.annotation.Secured;
import io.micronaut.security.rules.SecurityRule;
import io.micronaut.security.token.jwt.generator.JwtTokenGenerator;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/**
 * Dev token mint endpoint matching the mobile app contract:
 *   POST /api/v1/auth/token  (anonymous)
 *
 * Returns a signed JWT the app attaches as `Authorization: Bearer <token>`.
 * Dev-only placeholder; a real identity provider replaces this without
 * touching the app, whose AuthTokenService already abstracts the endpoint.
 */
@Controller("/api/v1/auth")
@Secured(SecurityRule.IS_ANONYMOUS)
public class DevAuthController {

    private static final int TOKEN_TTL_SECONDS = 3600;

    private final JwtTokenGenerator jwtTokenGenerator;

    public DevAuthController(JwtTokenGenerator jwtTokenGenerator) {
        this.jwtTokenGenerator = jwtTokenGenerator;
    }

    @Post("/token")
    public HttpResponse<Map<String, String>> token() {
        Instant now = Instant.now();
        Instant expiresAt = now.plusSeconds(TOKEN_TTL_SECONDS);

        Map<String, Object> claims = Map.of(
                "sub", "doctor",
                "roles", List.of("DOCTOR"),
                "iat", now.getEpochSecond(),
                "exp", expiresAt.getEpochSecond()
        );

        String token = jwtTokenGenerator.generateToken(claims).orElseThrow(
                () -> new IllegalStateException("Failed to generate JWT")
        );

        return HttpResponse.ok(Map.of(
                "token", token,
                "expiresAt", expiresAt.toString()
        ));
    }
}
