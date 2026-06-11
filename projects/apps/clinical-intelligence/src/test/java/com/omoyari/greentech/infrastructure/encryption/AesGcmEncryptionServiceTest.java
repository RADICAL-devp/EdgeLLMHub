package com.omoyari.greentech.infrastructure.encryption;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

/**
 * Tests for AES-256-GCM encryption round-trip.
 */
class AesGcmEncryptionServiceTest {

    @Test
    void testEncryptDecryptRoundTrip() {
        // Use the default dev key from EncryptionProperties
        var props = new com.omoyari.greentech.config.EncryptionProperties();
        var service = new AesGcmEncryptionService(props);

        String original = "Patient has severe OSA with AHI 34.2. CPAP recommended.";
        String encrypted = service.encrypt(original);

        assertNotNull(encrypted);
        assertNotEquals(original, encrypted); // must be different

        String decrypted = service.decrypt(encrypted);
        assertEquals(original, decrypted);
    }

    @Test
    void testEncryptProducesUniqueOutput() {
        var props = new com.omoyari.greentech.config.EncryptionProperties();
        var service = new AesGcmEncryptionService(props);

        String input = "Same input";
        String enc1 = service.encrypt(input);
        String enc2 = service.encrypt(input);

        // GCM with random IV should produce different ciphertexts
        assertNotEquals(enc1, enc2);

        // But both should decrypt to the same value
        assertEquals(input, service.decrypt(enc1));
        assertEquals(input, service.decrypt(enc2));
    }

    @Test
    void testDecryptInvalidCiphertext() {
        var props = new com.omoyari.greentech.config.EncryptionProperties();
        var service = new AesGcmEncryptionService(props);

        assertThrows(
                com.omoyari.greentech.common.SecureDecryptionException.class,
                () -> service.decrypt("dGhpcyBpcyBub3QgdmFsaWQgY2lwaGVydGV4dA=="));
    }
}
