package com.omoyari.greentech.common;

public class SecureDecryptionException extends RuntimeException {
    public SecureDecryptionException(String message) {
        super(message);
    }

    public SecureDecryptionException(String message, Throwable cause) {
        super(message, cause);
    }
}
