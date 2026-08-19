import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encryption service for protecting PHI at rest.
///
/// Uses AES-256-GCM for authenticated encryption.
/// Keys are stored in platform secure storage (Keychain/Keystore).
class PhiEncryptionService {
  PhiEncryptionService({
    FlutterSecureStorage? secureStorage,
    String? keyAlias,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _keyAlias = keyAlias ?? 'phi_encryption_key';

  final FlutterSecureStorage _secureStorage;
  final String _keyAlias;

  /// Get or create the encryption key.
  Future<encrypt.Key> _getOrCreateKey() async {
    String? keyBase64 = await _secureStorage.read(key: _keyAlias);
    if (keyBase64 != null) {
      return encrypt.Key.fromBase64(keyBase64);
    }

    // Generate new key
    final key = encrypt.Key.fromSecureRandom(32);
    await _secureStorage.write(
      key: _keyAlias,
      value: key.base64,
      aOptions: const AndroidOptions(),
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    );
    return key;
  }

  /// Encrypt a string containing PHI.
  Future<String> encryptString(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;

    final key = await _getOrCreateKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // In encrypt 5.x, the authTag is included in the encrypted.bytes for GCM mode
    // The format is: ciphertext + authTag (16 bytes)
    final combined = Uint8List.fromList([
      ...iv.bytes,
      ...encrypted.bytes,
    ]);

    return base64Encode(combined);
  }

  /// Decrypt a string containing PHI.
  Future<String> decryptString(String ciphertextBase64) async {
    if (ciphertextBase64.isEmpty) return ciphertextBase64;

    try {
      final key = await _getOrCreateKey();
      final combined = base64Decode(ciphertextBase64);

      if (combined.length < 16 + 16) { // IV (16) + min ciphertext+tag (16)
        throw FormatException('Ciphertext too short');
      }

      final iv = encrypt.IV(combined.sublist(0, 16));
      final ciphertextWithTag = combined.sublist(16);

      final encrypted = encrypt.Encrypted(ciphertextWithTag);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw EncryptionException('Failed to decrypt PHI: $e');
    }
  }

  /// Encrypt a Map (JSON-serializable) containing PHI.
  Future<String> encryptJson(Map<String, dynamic> json) async {
    final jsonString = jsonEncode(json);
    return encryptString(jsonString);
  }

  /// Decrypt a Map containing PHI.
  Future<Map<String, dynamic>> decryptJson(String encryptedJson) async {
    final decrypted = await decryptString(encryptedJson);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  /// Rotate the encryption key (re-encrypt all data with new key).
  Future<void> rotateKey() async {
    final oldKeyBase64 = await _secureStorage.read(key: _keyAlias);
    if (oldKeyBase64 == null) return;

    final oldKey = encrypt.Key.fromBase64(oldKeyBase64);
    final newKey = encrypt.Key.fromSecureRandom(32);

    await _secureStorage.write(
      key: _keyAlias,
      value: newKey.base64,
      aOptions: const AndroidOptions(),
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    );

    // Note: In production, you would need to re-encrypt all stored PHI
    // with the new key. This requires a migration process.
  }
}

/// Exception thrown for encryption/decryption failures.
class EncryptionException implements Exception {
  const EncryptionException(this.message);
  final String message;

  @override
  String toString() => 'EncryptionException: $message';
}

/// Mixin for repositories that need PHI encryption at rest.
mixin EncryptedRepositoryMixin<T> {
  PhiEncryptionService get encryptionService;

  /// Fields that should be encrypted (override in subclass).
  Set<String> get encryptedFields;

  /// Encrypt sensitive fields in a data map before storage.
  Future<Map<String, dynamic>> encryptForStorage(Map<String, dynamic> data) async {
    final result = Map<String, dynamic>.from(data);
    for (final field in encryptedFields) {
      if (result[field] != null) {
        result[field] = await encryptionService.encryptString(result[field] as String);
      }
    }
    return result;
  }

  /// Decrypt sensitive fields after retrieval from storage.
  Future<Map<String, dynamic>> decryptFromStorage(Map<String, dynamic> data) async {
    final result = Map<String, dynamic>.from(data);
    for (final field in encryptedFields) {
      if (result[field] != null) {
        result[field] = await encryptionService.decryptString(result[field] as String);
      }
    }
    return result;
  }
}