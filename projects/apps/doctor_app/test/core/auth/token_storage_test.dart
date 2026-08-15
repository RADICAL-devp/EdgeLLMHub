import 'package:doctor_app/core/auth/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryTokenStorage', () {
    test('round-trips a stored token', () async {
      final storage = InMemoryTokenStorage();
      final token = StoredAuthToken(
        token: 'abc',
        expiresAt: DateTime.utc(2030, 1, 1),
      );

      expect(await storage.read(), isNull);

      await storage.write(token);
      final read = await storage.read();
      expect(read, isNotNull);
      expect(read!.token, 'abc');
      expect(read.expiresAt, DateTime.utc(2030, 1, 1));
    });

    test('clear removes the persisted token', () async {
      final storage = InMemoryTokenStorage();
      await storage.write(
        const StoredAuthToken(token: 'abc', expiresAt: null),
      );

      await storage.clear();

      expect(await storage.read(), isNull);
    });
  });

  group('SecureTokenStorage', () {
    test('reads/writes the token and expiry via the secure store', () async {
      final fake = _FakeSecureStorage(values: {
        'auth_token': 'secret-token',
        'auth_token_expires_at': '2030-01-01T00:00:00.000Z',
      });
      final storage = SecureTokenStorage(storage: fake);

      final read = await storage.read();

      expect(read, isNotNull);
      expect(read!.token, 'secret-token');
      expect(read.expiresAt, DateTime.utc(2030, 1, 1));
    });

    test('returns null when the store is empty', () async {
      final storage = SecureTokenStorage(storage: _FakeSecureStorage());

      expect(await storage.read(), isNull);
    });

    test('write persists token and expiry through the store', () async {
      final fake = _FakeSecureStorage();
      final storage = SecureTokenStorage(storage: fake);

      await storage.write(StoredAuthToken(
        token: 'secret-token',
        expiresAt: DateTime.utc(2030, 1, 1),
      ));

      expect(fake.values['auth_token'], 'secret-token');
      expect(fake.values['auth_token_expires_at'], '2030-01-01T00:00:00.000Z');
    });

    test('clear deletes both keys', () async {
      final fake = _FakeSecureStorage(values: {
        'auth_token': 't',
        'auth_token_expires_at': '2030-01-01T00:00:00.000Z',
      });
      final storage = SecureTokenStorage(storage: fake);

      await storage.clear();

      expect(fake.values, isEmpty);
    });

    test('never throws when the underlying store fails', () async {
      final storage = SecureTokenStorage(storage: _BoomStorage());

      expect(await storage.read(), isNull);
      await storage.write(
        const StoredAuthToken(token: 't', expiresAt: null),
      );
      await storage.clear();
    });
  });
}

/// In-memory [FlutterSecureStorage] stand-in (no platform channel).
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage({Map<String, String>? values})
      : values = {...?values};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

/// Secure store whose operations throw, simulating an unavailable Keychain.
class _BoomStorage extends _FakeSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keychain unavailable');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keychain unavailable');
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keychain unavailable');
  }
}
