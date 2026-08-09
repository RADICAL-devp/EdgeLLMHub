import 'dart:convert';
import 'dart:typed_data';
import 'package:jose/jose.dart';
import 'package:pointycastle/digests/sha256.dart';

/// RS256 JWT sign/verify with JWKS caching.
class JwtService {
  JwtService({
    required String privateKeyPem,
    required String publicKeyPem,
    Duration jwksCacheTtl = const Duration(minutes: 5),
  })  : _privateKey = privateKeyPem,
        _publicKey = publicKeyPem,
        _jwksCacheTtl = jwksCacheTtl;

  final String _privateKey;
  final String _publicKey;
  final Duration _jwksCacheTtl;

  DateTime? _jwksCachedAt;
  Map<String, dynamic>? _jwksCache;

  /// Sign a JWT with the given claims.
  String sign({
    required Map<String, dynamic> claims,
    Duration expiresIn = const Duration(hours: 1),
  }) {
    final now = DateTime.now().toUtc();
    final exp = now.add(expiresIn);

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = {
        ...claims,
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
      }
      ..setProtectedHeader('typ', 'JWT')
      ..addRecipient(
        JsonWebKey.fromPem(_privateKey),
        algorithm: 'RS256',
      );

    final jws = builder.build();
    return jws.toCompactSerialization();
  }

  /// Verify a JWT and return the claims.
  Future<JwtClaims> verify(String token) async {
    try {
      final store = JsonWebKeyStore()..addKey(JsonWebKey.fromPem(_publicKey));
      final jwt = await JsonWebToken.decodeAndVerify(
        token,
        store,
        allowedArguments: ['RS256'],
      );
      if (jwt.isVerified != true) {
        throw JwtException('Signature verification failed');
      }
      return JwtClaims.fromJson(jwt.claims.toJson());
    } catch (e) {
      if (e is JwtException) rethrow;
      throw JwtException('Invalid token: $e');
    }
  }

  /// Get JWKS for public endpoint.
  Map<String, dynamic> getJwks() {
    final now = DateTime.now();
    if (_jwksCache != null &&
        _jwksCachedAt != null &&
        now.difference(_jwksCachedAt!) < _jwksCacheTtl) {
      return _jwksCache!;
    }

    final jwk = JsonWebKey.fromPem(_publicKey);
    final jwks = {
      'keys': [
        {
          'kty': 'RSA',
          'use': 'sig',
          'alg': 'RS256',
          'kid': _computeThumbprint(jwk),
          'n': jwk['n'],
          'e': jwk['e'],
        }
      ]
    };

    _jwksCache = jwks;
    _jwksCachedAt = DateTime.now();
    return jwks;
  }

  /// RFC 7638 SHA-256 thumbprint of the public key.
  String _computeThumbprint(JsonWebKey jwk) {
    final canonical = jsonEncode({
      'e': jwk['e'],
      'kty': 'RSA',
      'n': jwk['n'],
    });
    final digest = _sha256(utf8.encode(canonical));
    return base64Url.encode(digest).replaceAll('=', '');
  }

  static List<int> _sha256(List<int> input) {
    final digest = SHA256Digest();
    return digest.process(Uint8List.fromList(input));
  }
}

/// Parsed JWT claims.
class JwtClaims {
  JwtClaims.fromJson(Map<String, dynamic> json) : _claims = json;

  final Map<String, dynamic> _claims;

  String get subject => _claims['sub'] as String;
  String get clinicId => _claims['org'] as String? ?? '';
  List<String> get roles => List<String>.from(_claims['roles'] as List? ?? []);
  List<String> get scopes =>
      (_claims['scope'] as String? ?? '').split(' ').where((s) => s.isNotEmpty).toList();
  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch((_claims['exp'] as int) * 1000, isUtc: true);
  DateTime get issuedAt => DateTime.fromMillisecondsSinceEpoch((_claims['iat'] as int) * 1000, isUtc: true);

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool hasScope(String scope) => scopes.contains(scope);
  bool hasAllScopes(List<String> required) => required.every((s) => scopes.contains(s));
}

class JwtException implements Exception {
  const JwtException(this.message);
  final String message;
  @override
  String toString() => 'JwtException: $message';
}
