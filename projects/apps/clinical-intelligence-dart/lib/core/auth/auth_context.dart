import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';

/// Authentication context extracted from validated JWT.
class AuthContext {
  AuthContext({
    required this.doctorId,
    required this.clinicId,
    required this.roles,
    required this.scopes,
    required this.expiresAt,
    required this.issuedAt,
  });

  factory AuthContext.fromClaims(JwtClaims claims) {
    return AuthContext(
      doctorId: claims.subject,
      clinicId: claims.clinicId,
      roles: claims.roles,
      scopes: claims.scopes,
      expiresAt: claims.expiresAt,
      issuedAt: claims.issuedAt,
    );
  }

  final String doctorId;
  final String clinicId;
  final List<String> roles;
  final List<String> scopes;
  final DateTime expiresAt;
  final DateTime issuedAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool hasScope(String scope) => scopes.contains(scope);
  bool hasAllScopes(List<String> required) => required.every((s) => scopes.contains(s));
  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(List<String> roles) => roles.any((r) => this.roles.contains(r));
}
