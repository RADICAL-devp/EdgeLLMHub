import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';

/// Mixin for transparent field encryption in Drift repositories.
///
/// Usage:
/// ```dart
/// class MyRepository extends DriftRepository with EncryptedRepositoryMixin {
///   MyRepository(super.db, super.crypto);
///   
///   @override
///   Map<String, FieldEncryptionConfig> get encryptedFields => {
///     'transcriptText': FieldEncryptionConfig(fieldName: 'transcriptText', encrypt: true),
///     'processedText': FieldEncryptionConfig(fieldName: 'processedText', encrypt: true),
///   };
/// }
/// ```
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
          result[fieldName] = _crypto.encrypt(value, config.fieldName);
        }
      }
    }
    return result;
  }

  /// Decrypt fields after reading from database.
  T decryptOnRead<T extends Object>(T record) {
    // This is a simplified version - actual implementation depends on record type
    // Subclasses should override decryptRecord() for their specific record type
    return record;
  }

  /// Decrypt a single record. Override in subclass.
  T decryptRecord<T extends Object>(T record) => record;

  /// Decrypt a list of records.
  List<T> decryptRecords<T extends Object>(List<T> records) {
    return records.map(decryptRecord).toList();
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
