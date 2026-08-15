import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:clinical_intelligence_dart/core/auth/token_signer.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:test/test.dart';

void main() {
  group('LocalKeySigner', () {
    test('produces a JWT that JwtService can verify', () async {
      final keys = _generateKeys();
      final signer = LocalKeySigner(privateKeyPem: keys.privatePem);
      final service = JwtService(
        privateKeyPem: keys.privatePem,
        publicKeyPem: keys.publicPem,
        signer: signer,
      );

      final token = await service.sign(
        claims: {'sub': 'doctor-1', 'org': 'clinic-a'},
      );
      final claims = await service.verify(token);

      expect(claims.subject, 'doctor-1');
      expect(claims.clinicId, 'clinic-a');
      expect(claims.isExpired, isFalse);
    });
  });

  group('KmsSigner', () {
    late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair;
    late String publicKeyPem;

    setUp(() {
      final keys = _generateKeys();
      keyPair = keys.pair;
      publicKeyPem = keys.publicPem;
    });

    test(
        'sends a SigV4-signed KMS Sign request and yields a verifiable JWT',
        () async {
      http.Request? captured;
      final fakeClient = _FakeKmsClient((request) async {
        captured = request;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final message = base64Decode(payload['Message'] as String);
        final signature = _signPkcs1v1_5Sha256(
          keyPair.privateKey,
          utf8.encode(utf8.decode(message)),
        );
        return http.Response(
          jsonEncode({'Signature': base64Encode(signature)}),
          200,
          headers: const {'content-type': 'application/x-amz-json-1.1'},
        );
      });

      final signer = KmsSigner(
        keyId: 'alias/jwt-signing',
        region: 'us-east-1',
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'SECRET',
        sessionToken: 'TOKEN123',
        httpClient: fakeClient,
      );
      final service = JwtService(
        privateKeyPem: 'unused-in-kms-mode',
        publicKeyPem: publicKeyPem,
        signer: signer,
      );

      final token = await service.sign(
        claims: {'sub': 'doctor-1', 'org': 'clinic-a'},
      );

      // The KMS-produced signature base64url-encodes into a verifiable JWT.
      final claims = await service.verify(token);
      expect(claims.subject, 'doctor-1');
      expect(claims.clinicId, 'clinic-a');
      expect(token.split('.'), hasLength(3));

      // The request targets KMS Sign with the correct parameters.
      expect(captured, isNotNull);
      expect(captured!.url.toString(), 'https://kms.us-east-1.amazonaws.com/');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['KeyId'], 'alias/jwt-signing');
      expect(body['SigningAlgorithm'], 'RSASSA_PKCS1_V1_5_SHA256');
      expect(body['MessageType'], 'RAW');
      // Message is the base64 of the JWT signing input (ASCII).
      final message = utf8.decode(base64Decode(body['Message'] as String));
      expect(message, token.split('.').take(2).join('.'));

      // SigV4 signing headers are present.
      final headers = captured!.headers;
      expect(headers['host'], 'kms.us-east-1.amazonaws.com');
      expect(headers['content-type'], 'application/x-amz-json-1.1');
      expect(headers['x-amz-target'], 'TrentService.Sign');
      expect(headers['x-amz-date'], matches(RegExp(r'^\d{8}T\d{6}Z$')));
      expect(headers['x-amz-security-token'], 'TOKEN123');
      final authorization = headers['authorization']!;
      expect(authorization, startsWith('AWS4-HMAC-SHA256'));
      expect(authorization, contains('Credential=AKIDEXAMPLE/'));
      expect(authorization, contains('/us-east-1/kms/aws4_request'));
      expect(
        authorization,
        contains('SignedHeaders=content-type;host;x-amz-date;'
            'x-amz-security-token;x-amz-target'),
      );
      expect(authorization, contains('Signature='));
      // The signed header set covers exactly the sent headers
      // (authorization itself is never signed in SigV4).
      final signedSet = RegExp('SignedHeaders=([^,]+)')
          .firstMatch(authorization)!
          .group(1)!
          .split(';')
          .toSet();
      final sentSet = headers.keys.map((h) => h.toLowerCase()).toSet()
        ..remove('authorization');
      expect(signedSet, sentSet);
    });

    test('omits x-amz-security-token when no session token is configured',
        () async {
      http.Request? captured;
      final fakeClient = _FakeKmsClient((request) async {
        captured = request;
        final signature = _signPkcs1v1_5Sha256(
          keyPair.privateKey,
          utf8.encode('ignored'),
        );
        return http.Response(
          jsonEncode({'Signature': base64Encode(signature)}),
          200,
          headers: const {'content-type': 'application/x-amz-json-1.1'},
        );
      });

      final signer = KmsSigner(
        keyId: 'key/123',
        region: 'eu-west-1',
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'SECRET',
        httpClient: fakeClient,
      );
      await signer.sign('header.payload');

      expect(captured!.headers.containsKey('x-amz-security-token'), isFalse);
      expect(captured!.headers['host'], 'kms.eu-west-1.amazonaws.com');
      expect(
        captured!.headers['authorization'],
        contains('/eu-west-1/kms/aws4_request'),
      );
    });

    test('throws TokenSignerException on a non-200 KMS response', () async {
      final fakeClient = _FakeKmsClient(
        (_) async => http.Response(
          '{"message":"InvalidCiphertextException"}',
          400,
          headers: const {'content-type': 'application/x-amz-json-1.1'},
        ),
      );

      final signer = KmsSigner(
        keyId: 'key/123',
        region: 'us-east-1',
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'SECRET',
        httpClient: fakeClient,
      );

      await expectLater(
        signer.sign('header.payload'),
        throwsA(isA<TokenSignerException>()),
      );
    });

    test('SigV4 matches the official AWS sig-v4-test-suite get-vanilla vector',
        () {
      const emptyPayloadHash =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final canonicalRequest = KmsSigner.buildCanonicalRequest(
        'GET',
        '/',
        {
          'host': 'example.amazonaws.com',
          'x-amz-date': '20150830T123600Z',
        },
        emptyPayloadHash,
      );
      expect(
        canonicalRequest,
        'GET\n'
            '/\n'
            '\n'
            'host:example.amazonaws.com\n'
            'x-amz-date:20150830T123600Z\n'
            '\n'
            'host;x-amz-date\n'
            '$emptyPayloadHash',
      );

      final stringToSign = KmsSigner.buildStringToSign(
        amzDate: '20150830T123600Z',
        scope: '20150830/us-east-1/service/aws4_request',
        canonicalRequest: canonicalRequest,
      );
      expect(
        stringToSign,
        'AWS4-HMAC-SHA256\n'
            '20150830T123600Z\n'
            '20150830/us-east-1/service/aws4_request\n'
            'bb579772317eb040ac9ed261061d46c1f17a8133879d6129b6e1c25292927e63',
      );

      final signature = KmsSigner.computeSignature(
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        dateStamp: '20150830',
        region: 'us-east-1',
        service: 'service',
        stringToSign: stringToSign,
      );
      expect(
        signature,
        '5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
      );
    });
  });

  group('selectTokenSigner', () {
    test('returns a KmsSigner when AWS_KMS_KEY_ID is set', () {
      final signer = selectTokenSigner(
        privateKeyPem: 'pem',
        environment: {
          'AWS_KMS_KEY_ID': 'alias/jwt-signing',
          'AWS_KMS_REGION': 'eu-central-1',
          'AWS_ACCESS_KEY_ID': 'AKIDEXAMPLE',
          'AWS_SECRET_ACCESS_KEY': 'SECRET',
          'AWS_SESSION_TOKEN': 'TOKEN',
        },
      );
      expect(signer, isA<KmsSigner>());
    });

    test('returns a LocalKeySigner when AWS_KMS_KEY_ID is unset', () {
      expect(
        selectTokenSigner(
          privateKeyPem: 'pem',
          environment: const {'AWS_ACCESS_KEY_ID': 'AKIDEXAMPLE'},
        ),
        isA<LocalKeySigner>(),
      );
    });

    test('returns a LocalKeySigner when AWS_KMS_KEY_ID is empty', () {
      expect(
        selectTokenSigner(
          privateKeyPem: 'pem',
          environment: const {'AWS_KMS_KEY_ID': ''},
        ),
        isA<LocalKeySigner>(),
      );
    });

    test('JwtService constructor defaults to the env-selected signer',
        () async {
      final service = JwtService(
        privateKeyPem: _privateKeyPem,
        publicKeyPem: _publicKeyPem,
      );
      final token = await service.sign(claims: {'sub': 'doctor-1'});
      final claims = await service.verify(token);
      expect(claims.subject, 'doctor-1');
    });
  });
}

/// Fake HTTP client that captures the request and serves canned responses.
class _FakeKmsClient extends http.BaseClient {
  _FakeKmsClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

List<int> _signPkcs1v1_5Sha256(RSAPrivateKey privateKey, List<int> data) {
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  return signer.generateSignature(Uint8List.fromList(data)).bytes;
}

({String privatePem, String publicPem,
    AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> pair}) _generateKeys() {
  final pair = _generateKeyPair();
  return (
    privatePem: _encodePrivateKeyPem(pair.privateKey),
    publicPem: _encodePublicKeyPem(pair.publicKey),
    pair: pair,
  );
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
