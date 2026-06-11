package com.omoyari.greentech.infrastructure.encryption;

import com.omoyari.greentech.application.ports.EncryptionPort;
import com.omoyari.greentech.common.SecureDecryptionException;
import com.omoyari.greentech.config.EncryptionProperties;
import jakarta.inject.Singleton;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * AES-256-GCM encryption service for server-side at-rest data protection.
 * The encryption key is loaded from config (swap for AWS KMS in production).
 *
 * Format: Base64( IV[12 bytes] || ciphertext || authTag[16 bytes] )
 */
@Singleton
public class AesGcmEncryptionService implements EncryptionPort {

    private static final Logger LOG = LoggerFactory.getLogger(AesGcmEncryptionService.class);
    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128; // bits

    private final SecretKeySpec keySpec;
    private final SecureRandom secureRandom;

    public AesGcmEncryptionService(EncryptionProperties properties) {
        byte[] keyBytes = Base64.getDecoder().decode(properties.getKey());

        // Ensure key is valid length for AES (16, 24, or 32 bytes)
        if (keyBytes.length != 16 && keyBytes.length != 24 && keyBytes.length != 32) {
            // Pad or truncate to 32 bytes for AES-256
            byte[] adjusted = new byte[32];
            System.arraycopy(keyBytes, 0, adjusted, 0, Math.min(keyBytes.length, 32));
            keyBytes = adjusted;
        }

        this.keySpec = new SecretKeySpec(keyBytes, "AES");
        this.secureRandom = new SecureRandom();
        LOG.info("AES-GCM encryption service initialized (key length: {} bits)", keyBytes.length * 8);
    }

    @Override
    public String encrypt(String plaintext) {
        try {
            byte[] iv = new byte[GCM_IV_LENGTH];
            secureRandom.nextBytes(iv);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, parameterSpec);

            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(java.nio.charset.StandardCharsets.UTF_8));

            // Prepend IV to ciphertext: IV || encrypted || tag
            ByteBuffer byteBuffer = ByteBuffer.allocate(iv.length + ciphertext.length);
            byteBuffer.put(iv);
            byteBuffer.put(ciphertext);

            return Base64.getEncoder().encodeToString(byteBuffer.array());
        } catch (Exception e) {
            throw new SecureDecryptionException("Encryption failed", e);
        }
    }

    @Override
    public String decrypt(String ciphertext) {
        try {
            byte[] decoded = Base64.getDecoder().decode(ciphertext);

            ByteBuffer byteBuffer = ByteBuffer.wrap(decoded);
            byte[] iv = new byte[GCM_IV_LENGTH];
            byteBuffer.get(iv);
            byte[] encrypted = new byte[byteBuffer.remaining()];
            byteBuffer.get(encrypted);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, parameterSpec);

            byte[] plaintext = cipher.doFinal(encrypted);
            return new String(plaintext, java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new SecureDecryptionException("Decryption failed", e);
        }
    }
}
