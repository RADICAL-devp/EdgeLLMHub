import 'package:dart_frog/dart_frog.dart';
import 'package:clinical_intelligence_dart/core/auth/auth_context.dart';

/// Decorator for route handlers requiring specific scopes.
typedef RouteHandler = Future<Response> Function(RequestContext);

RouteHandler requireAuth(
  RouteHandler handler, {
  List<String> scopes = const [],
  List<String> roles = const [],
}) {
  return (context) async {
    final auth = context.read<AuthContext?>();
    if (auth == null) {
      return Response(
        statusCode: HttpStatus.unauthorized,
        body: 'Authentication required',
      );
    }
    if (auth.isExpired) {
      return Response(
        statusCode: HttpStatus.unauthorized,
        body: 'Token expired',
      );
    }
    if (scopes.isNotEmpty && !auth.hasAllScopes(scopes)) {
      return Response(
        statusCode: HttpStatus.forbidden,
        body: 'Insufficient scopes. Required: ${scopes.join(', ')}',
      );
    }
    if (roles.isNotEmpty && !auth.hasAnyRole(roles)) {
      return Response(
        statusCode: HttpStatus.forbidden,
        body: 'Insufficient roles. Required: ${roles.join(', ')}',
      );
    }
    return handler(context);
  };
}
