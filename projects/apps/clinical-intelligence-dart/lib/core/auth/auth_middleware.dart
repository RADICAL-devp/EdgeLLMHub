import 'package:dart_frog/dart_frog.dart';
import 'package:clinical_intelligence_dart/core/auth/jwt_service.dart';
import 'package:clinical_intelligence_dart/core/auth/auth_context.dart';

/// Middleware that validates Bearer JWT and provides [AuthContext].
Middleware authMiddleware(JwtService jwtService) {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: 'Missing or invalid Authorization header',
        );
      }

      final token = authHeader.substring(7).trim();
      if (token.isEmpty) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: 'Empty Bearer token',
        );
      }

      try {
        final claims = jwtService.verify(token);
        if (claims.isExpired) {
          return Response(
            statusCode: HttpStatus.unauthorized,
            body: 'Token expired',
          );
        }
        final authContext = AuthContext.fromClaims(claims);
        return handler(context.provide<AuthContext>(authContext));
      } on JwtException catch (e) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: e.message,
        );
      } catch (e) {
        return Response(
          statusCode: HttpStatus.unauthorized,
          body: 'Token validation failed: $e',
        );
      }
    };
  };
}
