import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:meta/meta.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Signs RS256 JWT signing inputs.
///
/// A [TokenSigner] receives the JWT signing input —
/// `base64url(header).base64url(payload)` — and returns the raw RS256
/// signature bytes that `JwtService` base64url-encodes into the compact
/// serialization. Verification is unaffected by the signer choice: it always
/// uses the static public key / JWKS.
// ignore: one_member_abstracts -- the signer is the seam for KMS vs local
abstract class TokenSigner {
  /// Signs [signingInput] (the ASCII JWT signing input) and returns the
  /// raw signature bytes.
  Future<List<int>> sign(String signingInput);
}

/// Signs with a local private key PEM (dev mode).
///
/// Replicates the historical `JwtService` behavior: the JWS is built with the
/// `jose` package and the signature bytes are extracted from the compact
/// serialization, so produced tokens are byte-for-byte identical to the
/// previous implementation.
class LocalKeySigner implements TokenSigner {
  LocalKeySigner({required String privateKeyPem})
      : _privateKeyPem = privateKeyPem;

  final String _privateKeyPem;

  @override
  Future<List<int>> sign(String signingInput) async {
    final parts = signingInput.split('.');
    final header = jsonDecode(_decodePart(parts[0])) as Map<String, dynamic>;
    final payload = jsonDecode(_decodePart(parts[1])) as Map<String, dynamic>;

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = payload
      ..setProtectedHeader('typ', header['typ'] as String? ?? 'JWT')
      ..addRecipient(
        JsonWebKey.fromPem(_privateKeyPem),
        algorithm: 'RS256',
      );

    final signature = builder.build().toCompactSerialization().split('.').last;
    return base64Url.decode(base64Url.normalize(signature));
  }

  static String _decodePart(String part) =>
      utf8.decode(base64Url.decode(base64Url.normalize(part)));
}

/// Signs via the AWS KMS `Sign` API in production mode.
///
/// Sends a SigV4-signed `TrentService.Sign` request with
/// `RSASSA_PKCS1_V1_5_SHA256` over the ASCII JWT signing input. The HTTP
/// client is injectable for testability; the default performs real requests.
class KmsSigner implements TokenSigner {
  KmsSigner({
    required String keyId,
    required String region,
    required String accessKeyId,
    required String secretAccessKey,
    String? sessionToken,
    http.Client? httpClient,
  })  : _keyId = keyId,
        _region = region,
        _accessKeyId = accessKeyId,
        _secretAccessKey = secretAccessKey,
        _sessionToken = sessionToken,
        _httpClient = httpClient ?? http.Client();

  static const _service = 'kms';
  static const _target = 'TrentService.Sign';

  final String _keyId;
  final String _region;
  final String _accessKeyId;
  final String _secretAccessKey;
  final String? _sessionToken;
  final http.Client _httpClient;

  @override
  Future<List<int>> sign(String signingInput) async {
    final body = jsonEncode({
      'KeyId': _keyId,
      'Message': base64Encode(utf8.encode(signingInput)),
      'MessageType': 'RAW',
      'SigningAlgorithm': 'RSASSA_PKCS1_V1_5_SHA256',
    });

    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = amzDate.substring(0, 8);
    final host = '$_service.$_region.amazonaws.com';

    final headers = <String, String>{
      'content-type': 'application/x-amz-json-1.1',
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-target': _target,
      if (_sessionToken case final token? when token.isNotEmpty)
        'x-amz-security-token': token,
    };

    final signedHeaderNames = headers.keys.toList()..sort();
    final payloadHash = _sha256Hex(utf8.encode(body));
    final scope = '$dateStamp/$_region/$_service/aws4_request';
    final canonicalRequest =
        buildCanonicalRequest('POST', '/', headers, payloadHash);
    final stringToSign = buildStringToSign(
      amzDate: amzDate,
      scope: scope,
      canonicalRequest: canonicalRequest,
    );
    final signature = computeSignature(
      secretAccessKey: _secretAccessKey,
      dateStamp: dateStamp,
      region: _region,
      service: _service,
      stringToSign: stringToSign,
    );
    headers['authorization'] =
        'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$scope, '
        'SignedHeaders=${signedHeaderNames.join(';')}, Signature=$signature';

    final response = await _httpClient.post(
      Uri.parse('https://$host/'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw TokenSignerException(
        'KMS Sign failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final signatureB64 = decoded['Signature'] as String;
    return base64Decode(signatureB64);
  }

  static String _formatAmzDate(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// Builds the SigV4 canonical request (query string is always empty for
  /// the KMS JSON protocol).
  @visibleForTesting
  static String buildCanonicalRequest(
    String method,
    String path,
    Map<String, String> headers,
    String payloadHash,
  ) {
    final names = headers.keys.toList()..sort();
    final canonicalHeaders =
        names.map((name) => '$name:${headers[name]}').join('\n') + '\n';
    return [
      method,
      path,
      '',
      canonicalHeaders,
      names.join(';'),
      payloadHash,
    ].join('\n');
  }

  /// Builds the SigV4 string-to-sign.
  @visibleForTesting
  static String buildStringToSign({
    required String amzDate,
    required String scope,
    required String canonicalRequest,
  }) =>
      [
        'AWS4-HMAC-SHA256',
        amzDate,
        scope,
        _sha256Hex(utf8.encode(canonicalRequest)),
      ].join('\n');

  /// Derives the SigV4 signing key and returns the hex signature.
  @visibleForTesting
  static String computeSignature({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    required String service,
    required String stringToSign,
  }) {
    final kDate = _hmac(
      utf8.encode('AWS4$secretAccessKey'),
      utf8.encode(dateStamp),
    );
    final kRegion = _hmac(kDate, utf8.encode(region));
    final kService = _hmac(kRegion, utf8.encode(service));
    final kSigning = _hmac(kService, utf8.encode('aws4_request'));
    return _toHex(_hmac(kSigning, utf8.encode(stringToSign)));
  }

  static Uint8List _hmac(List<int> key, List<int> data) {
    final hmac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(key)));
    final out = Uint8List(hmac.macSize);
    hmac
      ..update(Uint8List.fromList(data), 0, data.length)
      ..doFinal(out, 0);
    return out;
  }

  static List<int> _sha256(List<int> input) =>
      SHA256Digest().process(Uint8List.fromList(input));

  static String _sha256Hex(List<int> input) => _toHex(_sha256(input));

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Selects the [TokenSigner] from the environment: [KmsSigner] when
/// `AWS_KMS_KEY_ID` is set and non-empty, otherwise [LocalKeySigner].
TokenSigner selectTokenSigner({
  required String privateKeyPem,
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final keyId = env['AWS_KMS_KEY_ID'];
  if (keyId != null && keyId.isNotEmpty) {
    return KmsSigner(
      keyId: keyId,
      region: env['AWS_KMS_REGION'] ?? 'us-east-1',
      accessKeyId: env['AWS_ACCESS_KEY_ID'] ?? '',
      secretAccessKey: env['AWS_SECRET_ACCESS_KEY'] ?? '',
      sessionToken: env['AWS_SESSION_TOKEN'],
    );
  }
  return LocalKeySigner(privateKeyPem: privateKeyPem);
}

class TokenSignerException implements Exception {
  const TokenSignerException(this.message);
  final String message;
  @override
  String toString() => 'TokenSignerException: $message';
}
