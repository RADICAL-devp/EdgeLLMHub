package com.omoyari.greentech.application.ports;

/**
 * Port for server-side encryption/decryption of sensitive clinical data at rest.
 */
public interface EncryptionPort {

    /**
     * Encrypt plaintext data. Returns a Base64-encoded ciphertext.
     */
    String encrypt(String plaintext);

    /**
     * Decrypt Base64-encoded ciphertext back to plaintext.
     */
    String decrypt(String ciphertext);
}
