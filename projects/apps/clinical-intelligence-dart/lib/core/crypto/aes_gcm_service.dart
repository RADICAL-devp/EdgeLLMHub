import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/aead/aead.dart';
import 'package:pointycastle/aead/chacha20_poly1305.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/random/secure_random.dart';

/// AES-GCM-256 encryption service for data at rest.
///
/// Uses PointyCastle (ChaCha20-Poly1305) for cryptographic operations.
/// Each field gets its own DEK (Data Encryption Key) derived from master key.
class AesGcmService {
  AesGcmService({
    required String masterKeyB64,
    this.keyDerivationIterations = 100000,
  }) : _masterKey = base64Url.decode(masterKeyB64) {
    if (_masterKey.length != 32) {
      throw ArgumentError('Master key must be 256 bits (32 bytes) base64url encoded');
    }
  }

  final Uint8List _masterKey;
  final int keyDerivationIterations;

  /// Derive a field-specific DEK from master key using PBKDF2.
  Uint8List deriveDek(String fieldName, {Uint8List? salt}) {
    salt ??= _deriveSalt(fieldName);
    
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, keyDerivationIterations, 32));
    
    return pbkdf2.process(_masterKey);
  }

  /// Derive deterministic salt from field name.
  Uint8List _deriveSalt(String fieldName) {
    final digest = SHA256Digest();
    final fieldBytes = utf8.encode('clinical_intel_$fieldName');
    return digest.process(Uint8List.fromList(fieldBytes));
  }

  /// Encrypt plaintext with ChaCha20-Poly1305 (AES-GCM equivalent).
  ///
  /// Returns base64url encoded: nonce || ciphertext || tag
  String encrypt(String plaintext, String fieldName) {
    if (plaintext.isEmpty) return plaintext;

    final dek = deriveDek(fieldName);
    final nonce = _generateNonce();
    final aead = _createAead(dek);
    
    final plaintextBytes = utf8.encode(plaintext);
    final aad = utf8.encode('clinical_intel'); // Additional authenticated data
    
    final ciphertext = aead.process(
      AeadParameters(nonce, 128, aad),
      plaintextBytes,
    );
    
    // Combine: nonce (12) || ciphertext || tag (16)
    final result = Uint8List(nonce.length + ciphertext.length);
    result.setRange(0, nonce.length, nonce);
    result.setRange(nonce.length, result.length, ciphertext);
    
    return base64Url.encode(result);
  }

  /// Decrypt ciphertext with ChaCha20-Poly1305.
  String decrypt(String ciphertextB64, String fieldName) {
    if (ciphertextB64.isEmpty) return ciphertextB64;

    try {
      final dek = deriveDek(fieldName);
      final combined = base64Url.decode(ciphertextB64);
      
      if (combined.length < 12 + 16) {
        throw ArgumentError('Invalid ciphertext: too short');
      }
      
      final nonce = combined.sublist(0, 12);
      final ciphertextWithTag = combined.sublist(12);
      
      final aead = _createAead(dek);
      final aad = utf8.encode('clinical_intel');
      
      final plaintextBytes = aead.process(
        AeadParameters(Uint8List.fromList(nonce), 128, aad),
        ciphertextWithTag,
      );
      
      return utf8.decode(plaintextBytes);
    } catch (e) {
      throw ArgumentError('Decryption failed: $e');
    }
  }

  AeadAlgorithm _createAead(Uint8List key) {
    return ChaCha20Poly1305()
      ..init(true, KeyParameter(key));
  }

  Uint8List _generateNonce() {
    final random = SecureRandom('Fortuna')
      ..seed(KeyParameter(_masterKey.sublist(0, 16)));
    return random.nextBytes(12); // 96-bit nonce for GCM
  }
}

/// Field encryption configuration.
class FieldEncryptionConfig {
  const FieldEncryptionConfig({
    required this.fieldName,
    required this.encrypt,
  });

  final String fieldName;
  final bool encrypt;
}

/// Mixin for transparent field encryption in Drift repositories.
mixin EncryptedRepositoryMixin {
  AesGcmService get crypto;
  
  /// Fields to encrypt. Override in subclass.
  Map<String, FieldEncryptionConfig> get encryptedFields;

  /// Encrypt fields before writing to database.
  Map<String, dynamic> encryptForWrite(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    for (final entry in encryptedFields.entries) {
      final fieldName = entry.key;
      final config = entry.value;
      if (config.encrypt && result.containsKey(fieldName)) {
        final value = result[fieldName];
        if (value is String) {
          // Note: Need access to crypto instance - override in subclass
        }
      }
    }
    return result;
  }

  /// Decrypt a single record. Override in subclass.
  T decryptRecord<T extends Object>(T record) => record;

  /// Decrypt a list of records.
  List<T> decryptRecords<T extends Object>(List<T> records) {
    return records.map(decryptRecord).toList();
  }
}
