import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:test/test.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';

const _privateKeyPem = '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDBezQrknoUxPW4
xF+qZHtYE5BeSBPZMYbzhiBktPscpZZeCZqMrwNIu7oFbDdFoOQAaiKAe6boWnch
1EBL5u9Yr6PW/XVQD9RTsY02AyDpYTw2HJSFyRss6FA5Y7tm4Xb4A2l8aIiU0GVH
ItsEJC5iEpMUVB/uJyir8z6Gj7vUSG5EgIyQPFf07ovB70jHk2B67OUTV0mbxpHv
kcbNa3Z4o9OA8n0a8m7ss08aLR47t02RzCpSVj/hX01RvELFTwd9jNRLmWokqJHF
GpL5UpgUMbYqhml0yPH6V3bHZRNRfrFBm51tADFkTrxSEOfVFoJOyrRfZ3Q2AK9h
76VlhNp9AgMBAAECggEBAJLeRxfcNLeXWz9KMaRSah7NmwU2iXqRUfOBmQ1ZJFT2
jVIM0DiCkWeguPBs2PgNzYVTC6WkN2qhYVVYnQYA4ybbDO+hrm971J1DZgHeFhmS
KfaZc1Sq9+n63wrxXcwW0gwp6uT5JNRx7K83EjHulRb1Kph/000ghIsiNhBHAzl7
/9dUsmUDVLuqzBKExNoCRZaEqmR2p9pYT9KD6F2U4ffV9vDgzkiVVQZeBPt8hzOk
ndbeD9IDymB0guezcFDByAal3MIWMDhzMNwNOZHDj4T/iGcNfTReMlfUaeMOVpiP
q4/oAcp4a5h/ClCuP+mNK12OFvrdJt5pSfcxrc7I7YECgYEA5JcoVfWdJDi2LnxD
48l5Oh/mWINaT50vgfMM6PsJNNB/MW0wXj7Mi1CyVcozDoEnMtjnVtmrRotItiQw
u4yY3GChGnOjOZZwv0CxynzZXhLnjkvl+Hi0MOJcmfKy2YWVpaktMLGiFsz2VN2/
IhfnKF78etWA1o5izoMY9Qnz6DkCgYEA2K5UcAYZ7xf23kOA/seu6R1oJwmh+WR1
S0DGrbB52QaktiG3IhWeqo2EjGqqiFk+cOi13Fex2NANeajkLqtU5/y31l94SaIv
893lja8FekO9Jl/SNiWUuuM1qVqH0JP+RDk2koLKxoB72v4K1nmAA6gAghIk2icS
B8/6n3oEHGUCgYAwjWqj12dpKiKH/RzuZPy6u8vRQRUNk/VjRJyZX7i03xQlC2wa
mHwZmypFzozJp+ULh8abS+B1O2BWT5mKPHK7XErbs3QX5zxLYxJgT+Rbduh38OcH
v5uGRo4kpMgYK6d9aFGQ5innbeFkZTUTqMAQcxxteqvC5rtV4cKLSXHlAQKBgBK6
1v+r91fsiWFjEmZzmlH6QcOGGKM3JNBxc/sVkyLIaTp5JZxjpAh4HSoKGl2Y4UXf
R8EZL31fVpral4bVNoyrErUMIZiz1VNOLgaWR3HvIw2LIN+fVgDlnQDbm3vTHxqE
m4wElESeXJZseUFa1U77mbekm9zjnbJhLvfUE0DlAoGAS8V0oCRNkMPpxAvejK49
8uDAHg9zoZyGarTdL9WD86aPbYwAF3WaeloVBehugOxrK0Wr5CP6PVA445MJwgMm
2nEaPCuNTvO/y9ubAUFSeRqEMRHo+mxLppKmyGNp/hQZVyVrITCT2BDXnsq1GdD+
hFVSurtGYXaHhwgtno+3ddw=
-----END PRIVATE KEY-----''';

const _publicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwXs0K5J6FMT1uMRfqmR7
WBOQXkgT2TGG84YgZLT7HKWWXgmajK8DSLu6BWw3RaDkAGoigHum6Fp3IdRAS+bv
WK+j1v11UA/UU7GNNgMg6WE8NhyUhckbLOhQOWO7ZuF2+ANpfGiIlNBlRyLbBCQu
YhKTFFQf7icoq/M+ho+71EhuRICMkDxX9O6Lwe9Ix5NgeuzlE1dJm8aR75HGzWt2
eKPTgPJ9GvJu7LNPGi0eO7dNkcwqUlY/4V9NUbxCxU8HfYzUS5lqJKiRxRqS+VKY
FDG2KoZpdMjx+ld2x2UTUX6xQZudbQAxZE68UhDn1RaCTsq0X2d0NgCvYe+lZYTa
fQIDAQAB
-----END PUBLIC KEY-----''';

void main() {
  group('JwtService', () {
    late JwtService service;

    setUp(() {
      service = JwtService(
        privateKeyPem: _privateKeyPem,
        publicKeyPem: _publicKeyPem,
      );
    });

    test('sign produces a 3-part compact serialization', () {
      final token = service.sign(claims: {'sub': 'doctor-1'});
      expect(token.split('.'), hasLength(3));
    });

    test('verify returns original claims', () async {
      final token = service.sign(
        claims: {
          'sub': 'doctor-1',
          'org': 'clinic-a',
          'roles': ['doctor'],
          'scope': 'clinical:read clinical:write',
        },
      );
      final claims = await service.verify(token);
      expect(claims.subject, 'doctor-1');
      expect(claims.clinicId, 'clinic-a');
      expect(claims.roles, contains('doctor'));
      expect(claims.scopes, containsAll(['clinical:read', 'clinical:write']));
      expect(claims.isExpired, isFalse);
      expect(claims.hasScope('clinical:read'), isTrue);
      expect(claims.hasAllScopes(['clinical:read', 'clinical:write']), isTrue);
    });

    test('verify sets exp/iat from expiresIn', () async {
      final token = service.sign(
        claims: {'sub': 'doctor-1'},
        expiresIn: const Duration(hours: 2),
      );
      final claims = await service.verify(token);
      final expectedExp = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2));
      expect(
        claims.expiresAt.difference(expectedExp).inSeconds.abs(),
        lessThan(5),
      );
      expect(
        claims.issuedAt.difference(DateTime.now().toUtc()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('verify rejects a tampered token', () async {
      final token = service.sign(claims: {'sub': 'doctor-1'});
      final parts = token.split('.');
      parts[1] = base64UrlEncodeUtf8('{"sub":"doctor-2"}');
      await expectLater(
        service.verify(parts.join('.')),
        throwsA(isA<JwtException>()),
      );
    });

    test('verify rejects a token signed with a different key', () async {
      final keyPair = _generateKeyPair();
      final other = JwtService(
        privateKeyPem: _encodePrivateKeyPem(keyPair.privateKey),
        publicKeyPem: _encodePublicKeyPem(keyPair.publicKey),
      );
      final token = other.sign(claims: {'sub': 'doctor-1'});
      await expectLater(
        service.verify(token),
        throwsA(isA<JwtException>()),
      );
    });

    test('getJwks exposes RS256 public key material', () {
      final jwks = service.getJwks();
      final key = jwks['keys'].first as Map<String, dynamic>;
      expect(key['kty'], 'RSA');
      expect(key['alg'], 'RS256');
      expect(key['use'], 'sig');
      expect(key['n'], isNotEmpty);
      expect(key['e'], isNotEmpty);
      expect(key['kid'], isNotEmpty);
      // Cached on second call
      expect(service.getJwks(), same(jwks));
    });
  });
}

String base64UrlEncodeUtf8(String input) {
  return base64Url.encode(utf8.encode(input));
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
