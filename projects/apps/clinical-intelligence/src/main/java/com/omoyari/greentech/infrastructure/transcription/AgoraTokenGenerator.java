package com.omoyari.greentech.infrastructure.transcription;

import com.omoyari.greentech.config.AgoraProperties;
import jakarta.inject.Singleton;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.zip.CRC32;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Generates Agora RTC tokens for channel authentication.
 * Used by:
 *   - Frontend clients to join video call channels
 *   - RTT agent to join and transcribe the channel
 *
 * Token generation uses HMAC-SHA256 with the Agora App Certificate.
 */
@Singleton
public class AgoraTokenGenerator {

    private static final Logger LOG = LoggerFactory.getLogger(AgoraTokenGenerator.class);
    private static final int TOKEN_EXPIRY_SECONDS = 3600; // 1 hour
    private static final String VERSION = "007";

    private final AgoraProperties properties;

    public AgoraTokenGenerator(AgoraProperties properties) {
        this.properties = properties;
    }

    /**
     * Generate an RTC token for a user to join a channel.
     *
     * @param channelName The channel name
     * @param uid         The user's UID (0 for auto-assign)
     * @param role        1 = publisher, 2 = subscriber
     * @return The generated token string
     */
    public String generateRtcToken(String channelName, int uid, int role) {
        if (properties.getAppCertificate() == null || properties.getAppCertificate().isBlank()) {
            LOG.warn("Agora App Certificate not configured — returning empty token (testing mode)");
            return "";
        }

        try {
            int timestamp = (int) (System.currentTimeMillis() / 1000) + TOKEN_EXPIRY_SECONDS;
            int salt = new SecureRandom().nextInt();

            // Build the message to sign
            ByteBuffer buf = ByteBuffer.allocate(1024).order(ByteOrder.LITTLE_ENDIAN);
            buf.putInt(salt);
            buf.putInt(timestamp);
            buf.putInt(uid);

            byte[] message = new byte[buf.position()];
            buf.flip();
            buf.get(message);

            // HMAC-SHA256 sign
            Mac hmac = Mac.getInstance("HmacSHA256");
            hmac.init(new SecretKeySpec(
                    properties.getAppCertificate().getBytes(), "HmacSHA256"));
            hmac.update(properties.getAppId().getBytes());
            hmac.update(channelName.getBytes());
            hmac.update(message);
            byte[] signature = hmac.doFinal();

            // CRC32 of channel for additional validation
            CRC32 crc = new CRC32();
            crc.update(channelName.getBytes());
            int channelCrc = (int) crc.getValue();

            // Assemble token
            ByteBuffer tokenBuf = ByteBuffer.allocate(2048).order(ByteOrder.LITTLE_ENDIAN);
            tokenBuf.put(signature);
            tokenBuf.putInt(channelCrc);
            tokenBuf.putInt(uid);
            tokenBuf.putInt(salt);
            tokenBuf.putInt(timestamp);

            byte[] tokenBytes = new byte[tokenBuf.position()];
            tokenBuf.flip();
            tokenBuf.get(tokenBytes);

            String token = VERSION + properties.getAppId()
                    + Base64.getEncoder().encodeToString(tokenBytes);

            LOG.info("Generated Agora RTC token for channel={}, uid={}", channelName, uid);
            return token;

        } catch (Exception e) {
            LOG.error("Failed to generate Agora RTC token", e);
            throw new RuntimeException("Agora token generation failed: " + e.getMessage(), e);
        }
    }

    /**
     * Generate Base64-encoded Basic Auth credentials for Agora REST API calls.
     */
    public String getBasicAuthHeader() {
        String credentials = properties.getCustomerId() + ":" + properties.getCustomerSecret();
        return "Basic " + Base64.getEncoder().encodeToString(credentials.getBytes());
    }
}
