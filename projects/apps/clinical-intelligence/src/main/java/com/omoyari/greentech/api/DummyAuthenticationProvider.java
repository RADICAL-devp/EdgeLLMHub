package com.omoyari.greentech.api;

import io.micronaut.http.HttpRequest;
import io.micronaut.security.authentication.AuthenticationFailureReason;
import io.micronaut.security.authentication.AuthenticationRequest;
import io.micronaut.security.authentication.AuthenticationResponse;
import io.micronaut.security.authentication.provider.HttpRequestAuthenticationProvider;
import jakarta.inject.Singleton;
import java.util.List;

@Singleton
public class DummyAuthenticationProvider implements HttpRequestAuthenticationProvider<Object> {

    @Override
    public AuthenticationResponse authenticate(
            HttpRequest<Object> httpRequest, AuthenticationRequest<String, String> authenticationRequest) {
        // Placeholder authentication allowing a dummy test login for the skeleton
        String identity = (String) authenticationRequest.getIdentity();
        String secret = (String) authenticationRequest.getSecret();

        if ("doctor".equals(identity) && "password".equals(secret)) {
            return AuthenticationResponse.success(identity, List.of("DOCTOR"));
        }

        return AuthenticationResponse.failure(AuthenticationFailureReason.CREDENTIALS_DO_NOT_MATCH);
    }
}
