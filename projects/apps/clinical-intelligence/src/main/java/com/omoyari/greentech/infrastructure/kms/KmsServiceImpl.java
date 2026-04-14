package com.omoyari.greentech.infrastructure.kms;

import com.omoyari.greentech.application.ports.KmsPort;
import com.omoyari.greentech.common.SecureDecryptionException;
import com.omoyari.greentech.core.DecryptedPayload;
import jakarta.inject.Singleton;
import java.util.Base64;

@Singleton
public class KmsServiceImpl implements KmsPort {

    @Override
    public DecryptedPayload decrypt(String encryptedPayload) {
        if (encryptedPayload == null || encryptedPayload.isBlank()) {
            throw new SecureDecryptionException("Encrypted payload cannot be null or empty");
        }
        try {
            // Placeholder: In real life, this would call AWS KMS.
            // For now, we simulate decryption with Base64 decoding.
            byte[] decodedBytes = Base64.getDecoder().decode(encryptedPayload);
            return new DecryptedPayload(new String(decodedBytes));
        } catch (IllegalArgumentException e) {
            throw new SecureDecryptionException("Failed to decrypt payload", e);
        }
    }
}
