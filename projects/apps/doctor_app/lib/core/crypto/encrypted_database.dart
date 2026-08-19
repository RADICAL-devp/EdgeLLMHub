import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:sqlite3/sqlite3.dart';

/// Encrypted database connection using SQLCipher.
///
/// Wraps Drift's NativeDatabase with a per-app encryption key
/// stored in secure storage (Keychain/Keystore).
class EncryptedDatabase {
  EncryptedDatabase({
    String? databaseName,
    FlutterSecureStorage? secureStorage,
    String? keyAlias,
  }) : _databaseName = databaseName ?? 'doctor_notes_encrypted.sqlite',
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _keyAlias = keyAlias ?? 'database_encryption_key';

  final String _databaseName;
  final FlutterSecureStorage _secureStorage;
  final String _keyAlias;

  /// Open an encrypted database connection.
  ///
  /// The encryption key is derived from a master key stored in secure storage.
  /// On first run, a new master key is generated.
  Future<QueryExecutor> openConnection() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, _databaseName));

    final key = await _getOrCreateKey();

    return NativeDatabase.createInBackground(
      file,
      // SQLCipher requires the key to be set via PRAGMA
      setup: (db) {
        db.execute("PRAGMA key = '${_escapeSqlString(key)}'");
        db.execute('PRAGMA cipher_page_size = 4096');
        db.execute('PRAGMA kdf_iter = 256000');
        db.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
        db.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
        db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Get or create the master encryption key.
  Future<String> _getOrCreateKey() async {
    String? key = await _secureStorage.read(key: _keyAlias);
    if (key != null) return key;

    // Generate a new 256-bit key
    final random = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch & 0xFF);
    final keyBytes = sha256.convert(random).bytes;
    key = hex.encode(keyBytes);

    await _secureStorage.write(
      key: _keyAlias,
      value: key,
      aOptions: const AndroidOptions(),
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    );
    return key;
  }

  /// Rotate the database encryption key.
  ///
  /// This re-encrypts the entire database with a new key.
  /// Must be called when the app is not actively using the database.
  Future<void> rotateKey() async {
    final oldKey = await _secureStorage.read(key: _keyAlias);
    if (oldKey == null) return;

    final newKey = await _generateNewKey();

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, _databaseName));

    // Rekey the database - open synchronously with sqlite3 directly
    final db = sqlite3.open(file.path);
    try {
      db.execute("PRAGMA key = '${_escapeSqlString(oldKey)}'");
      db.execute("PRAGMA rekey = '${_escapeSqlString(newKey)}'");
    } finally {
      db.dispose();
    }

    // Update stored key
    await _secureStorage.write(
      key: _keyAlias,
      value: newKey,
      aOptions: const AndroidOptions(),
      iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    );
  }

  Future<String> _generateNewKey() async {
    final random = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch & 0xFF);
    final keyBytes = sha256.convert(random).bytes;
    return hex.encode(keyBytes);
  }

  String _escapeSqlString(String input) {
    return input.replaceAll("'", "''");
  }
}

/// Create a Drift database with SQLCipher encryption.
LazyDatabase createEncryptedDatabaseConnection({
  String? databaseName,
  FlutterSecureStorage? secureStorage,
  String? keyAlias,
}) {
  final encryptedDb = EncryptedDatabase(
    databaseName: databaseName,
    secureStorage: secureStorage,
    keyAlias: keyAlias,
  );
  return LazyDatabase(() => encryptedDb.openConnection());
}