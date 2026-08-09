import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';

/// Hermetic RSA keypair + AES master key for integration tests.
class TestKeys {
  TestKeys._(this.privateKeyPem, this.publicKeyPem, this.masterKeyB64);

  final String privateKeyPem;
  final String publicKeyPem;
  final String masterKeyB64;

  static TestKeys generate() {
    final pair = _generateKeyPair();
    final aes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return TestKeys._(
      _encodePrivateKeyPem(pair.privateKey),
      _encodePublicKeyPem(pair.publicKey),
      base64Url.encode(aes),
    );
  }

  String signToken({
    String sub = 'dr-smith',
    String org = 'clinic-a',
    List<String> roles = const ['doctor'],
    List<String> scopes = const ['clinical:read', 'clinical:write'],
    Duration expiresIn = const Duration(hours: 1),
  }) {
    final service = JwtService(
      privateKeyPem: privateKeyPem,
      publicKeyPem: publicKeyPem,
    );
    return service.sign(
      claims: {
        'sub': sub,
        'org': org,
        'roles': roles,
        'scope': scopes.join(' '),
      },
      expiresIn: expiresIn,
    );
  }
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
