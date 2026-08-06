import 'dart:convert';
import 'package:jose/jose.dart';

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

    final payload = JsonWebToken.unregistered({
      ...claims,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
    });

    final builder = JsonWebSignatureBuilder()
      ..jsonContent = payload
      ..addRecipient(
        JsonWebKey.fromPem(_privateKey),
        algorithm: 'RS256',
        protectedHeader: {'alg': 'RS256', 'typ': 'JWT'},
      );

    final jws = builder.build();
    return jws.toCompactSerialization();
  }

  /// Verify a JWT and return the claims.
  JwtClaims verify(String token) {
    try {
      final jws = JsonWebSignature.fromCompactSerialization(token);
      final verified = jws.verify(
        JsonWebKey.fromPem(_publicKey),
        algorithms: ['RS256'],
      );
      if (!verified) {
        throw JwtException('Signature verification failed');
      }
      final payload = jws.payload as Map<String, dynamic>;
      return JwtClaims.fromJson(payload);
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
          'kid': jwk.thumbprint,
          'n': base64UrlEncode(jwk.n!),
          'e': base64UrlEncode(jwk.e!),
        }
      ]
    };

    _jwksCache = jwks;
    _jwksCachedAt = DateTime.now();
    return jwks;
  }

  String base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

/// Parsed JWT claims.
class JwtClaims {
  JwtClaims.fromJson(Map<String, dynamic> json) : _claims = json;

  final Map<String, dynamic> _claims;

  String get subject => _claims['sub'] as String;
  String get clinicId => _claims['org'] as String? ?? '';
  List<String> get roles => List<String>.from(_claims['roles'] ?? []);
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
