import 'dart:convert';

import 'package:clinical_intelligence_dart/core/crypto/aes_gcm_service.dart';
import 'package:test/test.dart';

const _masterKey =
    '7DOi+T/bVoL8yBQpYcLlXOqNb4MwmeOQ8J0hOR/xCjM=';

void main() {
  group('AesGcmService', () {
    late AesGcmService service;

    setUp(() {
      service = AesGcmService(masterKeyB64: _masterKey);
    });

    test('rejects a master key that is not 32 bytes', () {
      expect(
        () => AesGcmService(masterKeyB64: 'too-short'),
        throwsArgumentError,
      );
    });

    test('encrypt/decrypt roundtrip preserves plaintext', () {
      const plaintext = 'Patient John Doe complained of chest pain';
      final encrypted = service.encrypt(plaintext, 'transcriptText');
      expect(encrypted, isNot(contains('John')));
      expect(service.decrypt(encrypted, 'transcriptText'), plaintext);
    });

    test('encryption is non-deterministic (fresh nonce per call)', () {
      const plaintext = 'same text every time';
      final a = service.encrypt(plaintext, 'patientId');
      final b = service.encrypt(plaintext, 'patientId');
      expect(a, isNot(equals(b)));
      expect(service.decrypt(a, 'patientId'), plaintext);
      expect(service.decrypt(b, 'patientId'), plaintext);
    });

    test('ciphertext embeds nonce and tag (12 + data + 16)', () {
      const plaintext = 'hello';
      final encrypted = service.encrypt(plaintext, 'doctorId');
      final bytes = base64Decode(encrypted);
      expect(bytes.length, greaterThanOrEqualTo(12 + 16 + plaintext.length));
    });

    test('decrypt with wrong field name fails', () {
      final encrypted = service.encrypt('secret note', 'transcriptText');
      expect(
        () => service.decrypt(encrypted, 'doctorId'),
        throwsArgumentError,
      );
    });

    test('decrypt with tampered ciphertext fails', () {
      final encrypted = service.encrypt('integrity matters', 'transcriptText');
      final bytes = base64Decode(encrypted);
      bytes[bytes.length - 1] ^= 0x01; // flip a bit in the tag
      expect(
        () => service.decrypt(base64Encode(bytes), 'transcriptText'),
        throwsArgumentError,
      );
    });

    test('empty plaintext roundtrips as identity', () {
      expect(service.encrypt('', 'patientId'), '');
      expect(service.decrypt('', 'patientId'), '');
    });

    test('derives distinct DEKs per field', () {
      final a = service.deriveDek('transcriptText');
      final b = service.deriveDek('doctorId');
      expect(a, isNot(equals(b)));
      // Deterministic for the same field
      expect(service.deriveDek('transcriptText'), equals(a));
    });
  });
}

List<int> base64Decode(String input) => const Base64Codec().decode(input);

String base64Encode(List<int> input) => const Base64Codec().encode(input);
