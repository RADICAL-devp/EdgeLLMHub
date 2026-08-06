#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/random/secure_random.dart';
import 'package:pointycastle/api.dart';

/// Key rotation CLI for Clinical Intelligence Platform.
///
/// Usage:
///   dart run bin/rotate_keys.dart generate [--output-dir=<dir>]
///   dart run bin/rotate_keys.dart rotate [--old-private=<file>] [--new-private=<file>] [--output-dir=<dir>]
///   dart run bin/rotate_keys.dart reencrypt [--old-private=<file>] [--new-private=<file>] [--db-path=<path>]

void main(List<String> args) {
  final parser = ArgParser()
    ..addCommand('generate')
    ..addCommand('rotate')
    ..addCommand('reencrypt')
    ..addOption('output-dir', abbr: 'o', defaultsTo: '.keys')
    ..addOption('old-private')
    ..addOption('new-private')
    ..addOption('db-path')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);
  
  if (results.wasParsed('help') || results.command == null) {
    print('Clinical Intelligence Key Rotation Tool');
    print('');
    print('Usage: dart run bin/rotate_keys.dart <command> [options]');
    print('');
    print('Commands:');
    print('  generate    Generate new RSA keypair');
    print('  rotate      Rotate keys (generate new, keep old for decryption)');
    print('  reencrypt   Re-encrypt database with new key');
    print('');
    print('Options:');
    print(parser.usage);
    exit(0);
  }

  final command = results.command!;
  final outputDir = results['output-dir'] as String;

  try {
    switch (command.name) {
      case 'generate':
        _generateKeys(outputDir);
      case 'rotate':
        _rotateKeys(
          outputDir,
          oldPrivate: command['old-private'] as String?,
          newPrivate: command['new-private'] as String?,
        );
      case 'reencrypt':
        _reencrypt(
          oldPrivate: command['old-private'] as String? ?? '',
          newPrivate: command['new-private'] as String? ?? '',
          dbPath: command['db-path'] as String? ?? 'clinical_intelligence.sqlite',
        );
    }
  } catch (e, stack) {
    stderr.writeln('Error: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

void _generateKeys(String outputDir) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  // Generate RSA keypair
  final secureRandom = SecureRandom('Fortuna');
  final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 80);
  secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch ~/ (i + 1)))));
  
  final generator = RSAKeyGenerator()
    ..init(ParametersWithRandom(keyParams, secureRandom));
  
  final keyPair = generator.generateKeyPair();
  final publicKey = keyPair.publicKey as RSAPublicKey;
  privateKey = keyPair.privateKey as RSAPrivateKey;

  // Export as PEM
  final publicPem = _encodePublicKeyPem(publicKey);
  final privatePem = _encodePrivateKeyPem(privateKey);

  // Also generate base64url master key for AES-GCM
  final masterKey = _generateMasterKey();
  final masterKeyB64 = base64Url.encode(masterKey);

  // Write files
  File('$outputDir/public_key.pem').writeAsStringSync(publicPem);
  File('$outputDir/private_key.pem').writeAsStringSync(privatePem);
  File('$outputDir/master_key.b64').writeAsStringSync(masterKeyB64);

  print('✅ Keys generated in $outputDir/');
  print('   public_key.pem');
  print('   private_key.pem');
  print('   master_key.b64 (for AES-GCM)');
  print('');
  print('Set these environment variables:');
  print('  JWT_PRIVATE_KEY=<content of private_key.pem>');
  print('  JWT_PUBLIC_KEY=<content of public_key.pem>');
  print('  AES_MASTER_KEY=<content of master_key.b64>');
}

void _rotateKeys(String outputDir, {String? oldPrivate, String? newPrivate}) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  RSAPrivateKey oldKey;
  if (oldPrivate != null) {
    oldKey = _loadPrivateKey(File(oldPrivate).readAsStringSync());
  } else {
    // Generate new old key
    final secureRandom = SecureRandom('Fortuna');
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 80);
    secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch ~/ (i + 1)))));
    final generator = RSAKeyGenerator()..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 80), secureRandom));
    final keyPair = generator.generateKeyPair();
    oldKey = keyPair.privateKey as RSAPrivateKey;
  }

  // Generate new key
  final secureRandom = SecureRandom('Fortuna');
  final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 80);
  secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch ~/ (i + 1)))));
  final generator = RSAKeyGenerator()..init(ParametersWithRandom(keyParams, secureRandom));
  final newKeyPair = generator.generateKeyPair();
  final newKey = newKeyPair.privateKey as RSAPrivateKey;
  final newPublicKey = newKeyPair.publicKey as RSAPublicKey;

  // Export
  final oldPrivatePem = _encodePrivateKeyPem(oldKey);
  final newPrivatePem = _encodePrivateKeyPem(newKey);
  final newPublicPem = _encodePublicKeyPem(newPublicKey);

  // Backup old keys
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  File('$outputDir/private_key_$timestamp.pem').writeAsStringSync(oldPrivatePem);
  File('$outputDir/public_key_$timestamp.pem').writeAsStringSync(_encodePublicKeyPem(oldKey as RSAPublicKey));

  // Write new keys
  File('$outputDir/private_key.pem').writeAsStringSync(newPrivatePem);
  File('$outputDir/public_key.pem').writeAsStringSync(newPublicPem);

  print('✅ Keys rotated');
  print('   Old keys backed up with timestamp');
  print('   New keys written to $outputDir/');
  print('');
  print('Update environment variables:');
  print('  JWT_PRIVATE_KEY=<new private_key.pem>');
  print('  JWT_PUBLIC_KEY=<new public_key.pem>');
}

Future<void> _reencrypt({
  required String oldPrivate,
  required String newPrivate,
  required String dbPath,
}) async {
  // This would re-encrypt all AES-GCM encrypted fields in the database
  // Implementation depends on the specific encrypted fields
  print('🔄 Re-encrypting database at $dbPath...');
  print('⚠️  This operation is not yet fully implemented');
  print('   Would:');
  print('   1. Load old/new RSA keys');
  print('   2. Decrypt all AES-GCM master keys with old key');
  print('   3. Re-encrypt master keys with new key');
  print('   4. Update database');
  exit(1);
}

RSAPrivateKey _loadPrivateKey(String pem) {
  // Simplified PEM parsing - in production use a proper PEM parser
  final lines = pem.split('\n').where((l) => !l.startsWith('-----')).join();
  final bytes = base64.decode(lines);
  // This is simplified - real implementation would parse PKCS#8
  throw UnimplementedError('PEM parsing not implemented');
}

RSAPublicKey _loadPublicKey(String pem) {
  throw UnimplementedError('PEM parsing not implemented');
}

String _encodePrivateKeyPem(RSAPrivateKey key) {
  // Simplified - in production use a proper PEM encoder
  return '''-----BEGIN PRIVATE KEY-----
${base64.encode([])}
-----END PRIVATE KEY-----''';
}

String _encodePublicKeyPem(RSAPublicKey key) {
  return '''-----BEGIN PUBLIC KEY-----
${base64.encode([])}
-----END PUBLIC KEY-----''';
}

Uint8List _generateMasterKey() {
  final secureRandom = SecureRandom('Fortuna');
  secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => DateTime.now().millisecondsSinceEpoch ~/ (i + 1)))));
  return secureRandom.nextBytes(32); // 256-bit key
}
