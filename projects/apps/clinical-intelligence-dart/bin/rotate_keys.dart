#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';

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

  final keyPair = _generateKeyPair();
  final publicPem = _encodePublicKeyPem(keyPair.publicKey);
  final privatePem = _encodePrivateKeyPem(keyPair.privateKey);

  // Also generate base64url master key for AES-GCM
  final masterKey = _generateMasterKey();
  final masterKeyB64 = base64Url.encode(masterKey);

  // Write files
  File('$outputDir/public_key.pem').writeAsStringSync(publicPem);
  File('$outputDir/private_key.pem').writeAsStringSync(privatePem);
  File('$outputDir/master_key.b64').writeAsStringSync(masterKeyB64);

  print('Keys generated in $outputDir/');
  print('   public_key.pem');
  print('   private_key.pem');
  print('   master_key.b64 (for AES-GCM)');
  print('');
  print('Set these environment variables:');
  print('  JWT_PRIVATE_KEY=<content of private_key.pem>');
  print('  JWT_PUBLIC_KEY=<content of public_key.pem>');
  print('  AES_MASTER_KEY=<content of master_key.b64>');
}

void _rotateKeys(String outputDir, {String? oldPrivate}) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  RSAPrivateKey oldKey;
  if (oldPrivate != null) {
    oldKey = _parsePkcs8PrivateKey(oldPrivate);
  } else {
    // Generate a key to serve as the "old" key
    oldKey = _generateKeyPair().privateKey;
  }

  // Generate new key
  final newKeyPair = _generateKeyPair();
  final newKey = newKeyPair.privateKey;
  final newPublicKey = newKeyPair.publicKey;

  // Export
  final oldPrivatePem = _encodePrivateKeyPem(oldKey);
  final newPrivatePem = _encodePrivateKeyPem(newKey);
  final newPublicPem = _encodePublicKeyPem(newPublicKey);

  // Backup old keys
  final timestamp =
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
  File('$outputDir/private_key_$timestamp.pem')
      .writeAsStringSync(oldPrivatePem);
  File('$outputDir/public_key_$timestamp.pem').writeAsStringSync(
      _encodePublicKeyPem(RSAPublicKey(oldKey.modulus!, oldKey.n!)));

  // Write new keys
  File('$outputDir/private_key.pem').writeAsStringSync(newPrivatePem);
  File('$outputDir/public_key.pem').writeAsStringSync(newPublicPem);

  print('Keys rotated');
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
  print('Re-encrypting database at $dbPath...');
  print('WARNING: This operation is not yet fully implemented');
  print('   Would:');
  print('   1. Load old/new RSA keys');
  print('   2. Decrypt all AES-GCM master keys with old key');
  print('   3. Re-encrypt master keys with new key');
  print('   4. Update database');
  exit(1);
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateKeyPair() {
  final rnd = Random.secure();
  final secure = FortunaRandom()
    ..seed(KeyParameter(
        Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)))));
  final gen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64), secure));
  final pair = gen.generateKeyPair();
  return AsymmetricKeyPair(
    pair.publicKey as RSAPublicKey,
    pair.privateKey as RSAPrivateKey,
  );
}

Uint8List _generateMasterKey() {
  final rnd = Random.secure();
  return Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256))); // 256-bit key
}

// --- ASN.1 DER encoding helpers ---

List<int> _len(int len) {
  if (len < 0x80) return [len];
  final bytes = <int>[];
  var l = len;
  while (l > 0) {
    bytes.insert(0, l & 0xff);
    l >>= 8;
  }
  return [0x80 | bytes.length, ...bytes];
}

List<int> _seq(List<int> content) => [0x30, ..._len(content.length), ...content];

List<int> _int(BigInt v) {
  var bytes = _toBytes(v);
  if (bytes[0] & 0x80 != 0) bytes = [0, ...bytes];
  return [0x02, ..._len(bytes.length), ...bytes];
}

List<int> _toBytes(BigInt v) {
  final hex = v.toRadixString(16);
  final padded = hex.length.isOdd ? '0$hex' : hex;
  final bytes = <int>[];
  for (var i = 0; i < padded.length; i += 2) {
    bytes.add(int.parse(padded.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

List<int> _octets(List<int> content) =>
    [0x04, ..._len(content.length), ...content];

List<int> _bitString(List<int> content) => [
      0x03,
      ..._len(content.length + 1),
      0x00,
      ...content,
    ];

String _pem(String label, List<int> der) {
  final b64 = base64Encode(der);
  final lines = <String>['-----BEGIN $label-----'];
  for (var i = 0; i < b64.length; i += 64) {
    lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
  }
  lines.add('-----END $label-----');
  return lines.join('\n');
}

String _encodePrivateKeyPem(RSAPrivateKey key) {
  final n = key.modulus!, e = key.exponent!;
  final d = key.privateExponent!, p = key.p!, q = key.q!;
  final dp = d % (p - BigInt.one), dq = d % (q - BigInt.one);
  final qinv = q.modInverse(p);

  const rsaOid = [
    0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
  ];
  const alg = [0x30, 0x0d, ...rsaOid, 0x05, 0x00];

  final rsaPriv = _seq([
    ..._int(BigInt.zero),
    ..._int(n),
    ..._int(e),
    ..._int(d),
    ..._int(p),
    ..._int(q),
    ..._int(dp),
    ..._int(dq),
    ..._int(qinv),
  ]);
  final pkcs8 = _seq([..._int(BigInt.zero), ...alg, ..._octets(rsaPriv)]);
  return _pem('PRIVATE KEY', pkcs8);
}

String _encodePublicKeyPem(RSAPublicKey key) {
  const rsaOid = [
    0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
  ];
  const alg = [0x30, 0x0d, ...rsaOid, 0x05, 0x00];
  final rsaPub = _seq([..._int(key.modulus!), ..._int(key.exponent!)]);
  final spki = _seq([...alg, ..._bitString(rsaPub)]);
  return _pem('PUBLIC KEY', spki);
}

/// Minimal PKCS#8 (RSAPrivateKey) DER parser used by `rotate`.
RSAPrivateKey _parsePkcs8PrivateKey(String pem) {
  final b64 = pem
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  final der = base64.decode(b64);

  // PKCS#8: SEQ { INT(0), SEQ { OID, NULL }, OCTET STRING (RSAPrivateKey) }
  final (_, outerStart) = _header(der, 0);
  final (verLen, verStart) = _header(der, outerStart);
  var pos = verStart + verLen;
  final (algLen, algStart) = _header(der, pos);
  pos = algStart + algLen;
  final (octLen, octStart) = _header(der, pos);
  final rsa = der.sublist(octStart, octStart + octLen);

  // RSAPrivateKey: SEQ { INT(0), INT(n), INT(e), INT(d), INT(p), INT(q), ... }
  final (_, r0Start) = _header(rsa, 0);
  var rp = r0Start + 1;
  final n = _readInt(rsa, rp);
  rp = n.$2;
  final e = _readInt(rsa, rp);
  rp = e.$2;
  final d = _readInt(rsa, rp);
  rp = d.$2;
  final p = _readInt(rsa, rp);
  rp = p.$2;
  final q = _readInt(rsa, rp);
  return RSAPrivateKey(n.$1, d.$1, p.$1, q.$1, e.$1);
}

// --- Minimal DER reader ---

/// Returns `(contentLength, contentStart)` for the TLV at [offset].
(int, int) _header(List<int> der, int offset) {
  var len = der[offset + 1];
  var pos = offset + 2;
  if (len & 0x80 != 0) {
    final count = len & 0x7f;
    var l = 0;
    for (var i = 0; i < count; i++) {
      l = (l << 8) | der[pos + i];
    }
    len = l;
    pos += count;
  }
  return (len, pos);
}

/// Reads the INTEGER at [offset], returning `(value, nextOffset)`.
(BigInt, int) _readInt(List<int> der, int offset) {
  final (len, start) = _header(der, offset);
  final hex = der
      .sublist(start, start + len)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return (BigInt.parse(hex, radix: 16), start + len);
}
