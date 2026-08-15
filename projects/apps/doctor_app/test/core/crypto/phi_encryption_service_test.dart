import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:doctor_app/core/crypto/phi_encryption_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('PhiEncryptionService', () {
    late MockFlutterSecureStorage mockStorage;
    late PhiEncryptionService service;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      service = PhiEncryptionService(secureStorage: mockStorage);
    });

    test('encrypts and decrypts string correctly', () async {
      const plaintext = 'Patient John Doe, BP 120/80, HR 72 bpm, Temp 98.6°F';

      final encrypted = await service.encryptString(plaintext);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(plaintext)));

      final decrypted = await service.decryptString(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('handles empty string', () async {
      const plaintext = '';

      final encrypted = await service.encryptString(plaintext);
      expect(encrypted, equals(plaintext));

      final decrypted = await service.decryptString(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('produces different ciphertext for same plaintext (IV randomization)', () async {
      const plaintext = 'Sensitive medical data';

      final encrypted1 = await service.encryptString(plaintext);
      final encrypted2 = await service.encryptString(plaintext);

      expect(encrypted1, isNot(equals(encrypted2)));

      final decrypted1 = await service.decryptString(encrypted1);
      final decrypted2 = await service.decryptString(encrypted2);

      expect(decrypted1, equals(plaintext));
      expect(decrypted2, equals(plaintext));
    });

    test('throws on corrupted ciphertext', () async {
      const plaintext = 'Test data';
      final encrypted = await service.encryptString(plaintext);

      // Corrupt the ciphertext
      final corrupted = encrypted.substring(0, encrypted.length - 1) + 'X';

      expect(
        () => service.decryptString(corrupted),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('throws on truncated ciphertext', () async {
      const plaintext = 'Test data';
      final encrypted = await service.encryptString(plaintext);

      // Truncate the ciphertext
      final truncated = encrypted.substring(0, encrypted.length - 10);

      expect(
        () => service.decryptString(truncated),
        throwsA(isA<EncryptionException>()),
      );
    });

    test('encrypts and decrypts JSON map', () async {
      final json = {
        'patientName': 'John Doe',
        'diagnosis': 'Hypertension',
        'medications': ['Lisinopril 10mg', 'Hydrochlorothiazide 25mg'],
        'vitals': {
          'bp': '120/80',
          'hr': 72,
          'temp': 98.6,
        },
      };

      final encrypted = await service.encryptJson(json);
      expect(encrypted, isNotEmpty);

      final decrypted = await service.decryptJson(encrypted);
      expect(decrypted, equals(json));
    });

    test('reuses key from secure storage on subsequent calls', () async {
      when(() => mockStorage.read(key: 'phi_encryption_key'))
          .thenAnswer((_) async => null); // First call: no key
      when(() => mockStorage.write(key: 'phi_encryption_key', value: any()))
          .thenAnswer((_) async => {}); // Key generation

      await service.encryptString('test');

      // Second call should read the key
      when(() => mockStorage.read(key: 'phi_encryption_key'))
          .thenAnswer((_) async => 'existing_key_base64');

      await service.encryptString('test2');

      verify(() => mockStorage.read(key: 'phi_encryption_key')).called(2);
    });
  });
}