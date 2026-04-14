package com.omoyari.greentech.application.ports;

import com.omoyari.greentech.core.DecryptedPayload;

public interface KmsPort {
    DecryptedPayload decrypt(String encryptedPayload);
}
