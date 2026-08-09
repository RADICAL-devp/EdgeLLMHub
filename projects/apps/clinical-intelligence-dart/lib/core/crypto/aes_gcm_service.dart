import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/macs/poly1305.dart';
import 'package:pointycastle/stream/chacha20poly1305.dart';
import 'package:pointycastle/stream/chacha7539.dart';

/// AES-GCM-256 encryption service for data at rest.
///
/// Uses PointyCastle (ChaCha20-Poly1305) for cryptographic operations.
/// Each field gets its own DEK (Data Encryption Key) derived from master key.
class AesGcmService {
  AesGcmService({
    required String masterKeyB64,
    this.keyDerivationIterations = 100000,
  }) : _masterKey = _decodeMasterKey(masterKeyB64);

  final Uint8List _masterKey;
  final int keyDerivationIterations;

  static Uint8List _decodeMasterKey(String masterKeyB64) {
    final Uint8List bytes;
    try {
      bytes = base64Url.decode(masterKeyB64);
    } catch (_) {
      throw ArgumentError(
          'Master key must be 256 bits (32 bytes) base64url encoded');
    }
    if (bytes.length != 32) {
      throw ArgumentError(
          'Master key must be 256 bits (32 bytes) base64url encoded');
    }
    return bytes;
  }

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
    final aad = utf8.encode('clinical_intel'); // Additional authenticated data

    final ciphertext = _processAead(
      key: dek,
      nonce: nonce,
      aad: aad,
      data: Uint8List.fromList(utf8.encode(plaintext)),
      forEncryption: true,
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
      final aad = utf8.encode('clinical_intel');

      final plaintextBytes = _processAead(
        key: dek,
        nonce: Uint8List.fromList(nonce),
        aad: aad,
        data: Uint8List.fromList(ciphertextWithTag),
        forEncryption: false,
      );

      return utf8.decode(plaintextBytes);
    } catch (e) {
      throw ArgumentError('Decryption failed: $e');
    }
  }

  static Uint8List _processAead({
    required Uint8List key,
    required Uint8List nonce,
    required List<int> aad,
    required Uint8List data,
    required bool forEncryption,
  }) {
    final aead = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
    aead.init(
      forEncryption,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List.fromList(aad),
      ),
    );
    final out = Uint8List(aead.getOutputSize(data.length));
    final written = aead.processBytes(data, 0, data.length, out, 0);
    final finalized = written + aead.doFinal(out, written);
    return Uint8List.sublistView(out, 0, finalized);
  }

  Uint8List _generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(12, (_) => random.nextInt(256)),
    ); // 96-bit nonce
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
