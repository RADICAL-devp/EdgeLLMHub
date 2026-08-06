# Phase 2.2 Execution Plan: Backend Authentication (JWT RS256)

**Objective:** Add JWT RS256 authentication with RBAC to `clinical-intelligence-dart` backend.

**Dependencies:** Phase 2.1 complete (Drift persistence)

---

## 2.2.1: JWT Service

**File:** `projects/apps/clinical-intelligence-dart/lib/core/auth/jwt_service.dart` (NEW)

```dart
/// RS256 JWT sign/verify with JWKS caching.
class JwtService {
  JwtService({required this.privateKey, required this.publicKey, this.jwksCacheTtl = const Duration(minutes: 5)});

  final String privateKey;  // PEM format
  final String publicKey;   // PEM format
  final Duration jwksCacheTtl;

  String sign({required Map<String, dynamic> claims, Duration? expiresIn});
  JwtClaims verify(String token);  // throws JwtException
  Map<String, dynamic> getJwks();  // for public endpoint
}
```

**Dependencies:** `package:jose/jose.dart` or `dart_jsonwebtoken`

---

## 2.2.2: Auth Context & Claims

**File:** `projects/apps/clinical-intelligence-dart/lib/core/auth/auth_context.dart` (NEW)

```dart
class AuthContext {
  final String doctorId;      // JWT 'sub'
  final String clinicId;      // JWT 'org'
  final List<String> roles;   // JWT 'roles'
  final List<String> scopes;  // JWT 'scope' (space-separated)
  final DateTime expiresAt;   // JWT 'exp'
}
```

**Scopes (RBAC):**
- `clinical:read` — GET clinical processing, summaries
- `clinical:write` — POST clinical processing, summaries
- `admin:read` — Audit logs, system health
- `admin:write` — Key rotation, user management

---

## 2.2.3: Auth Middleware

**File:** `projects/apps/clinical-intelligence-dart/lib/core/auth/auth_middleware.dart` (NEW)

```dart
Middleware authMiddleware(JwtService jwtService) {
  return (handler) => (context) async {
    final authHeader = context.request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(statusCode: 401, body: 'Missing Bearer token');
    }
    final token = authHeader.substring(7);
    try {
      final claims = jwtService.verify(token);
      final authContext = AuthContext.fromClaims(claims);
      return handler(context.provide<AuthContext>(authContext));
    } on JwtException catch (e) {
      return Response(statusCode: 401, body: 'Invalid token: ${e.message}');
    }
  };
}
```

---

## 2.2.4: RequireAuth Helper

**File:** `projects/apps/clinical-intelligence-dart/lib/core/auth/require_auth.dart` (NEW)

```dart
/// Decorator for route handlers requiring specific scopes.
typedef RouteHandler = Future<Response> Function(RequestContext);

RouteHandler requireAuth(RouteHandler handler, {List<String> scopes = const []}) {
  return (context) async {
    final auth = context.read<AuthContext?>();
    if (auth == null) return Response(statusCode: 401, body: 'Unauthorized');
    if (scopes.isNotEmpty && !scopes.every((s) => auth.scopes.contains(s))) {
      return Response(statusCode: 403, body: 'Insufficient scope');
    }
    return handler(context);
  };
}
```

---

## 2.2.5: Update Middleware Chain

**File:** `projects/apps/clinical-intelligence-dart/routes/_middleware.dart` (MODIFY)

```dart
Handler middleware(Handler handler) {
  // ... existing DI ...
  
  final jwtService = JwtService(
    privateKey: Platform.environment['JWT_PRIVATE_KEY']!,
    publicKey: Platform.environment['JWT_PUBLIC_KEY']!,
  );

  return handler
      .use(provider<JwtService>((_) => jwtService))
      .use(provider<AuthContext>((_) => throw StateError('Auth required')))
      .use(authMiddleware(jwtService))  // NEW: validates Bearer token
      .use(_corsMiddleware());
}
```

---

## 2.2.6: Protect Routes

**Files:** All route handlers in `routes/api/v1/**/*.dart` (MODIFY)

```dart
// Before:
Future<Response> onRequest(RequestContext context) async { ... }

// After:
Future<Response> onRequest(RequestContext context) async {
  return requireAuth((ctx) async {
    // ... original handler logic
  }, scopes: ['clinical:write'])(context);
}
```

**Scope Mapping:**
| Route | Required Scopes |
|-------|-----------------|
| POST `/api/v1/clinical-processing/process` | `clinical:write` |
| POST `/api/v1/transcript-summary/generate` | `clinical:write` |
| GET `/api/v1/transcript-summary/{id}` | `clinical:read` |
| POST `/api/v1/transcript-summary/{id}/regenerate` | `clinical:write` |
| GET `/api/v1/health` | (none — public) |

---

## 2.2.7: Environment Config

**File:** `projects/apps/clinical-intelligence-dart/lib/core/config/environment.dart` (NEW or extend)

```dart
class EnvironmentConfig {
  static String get jwtPrivateKey => 
      Platform.environment['JWT_PRIVATE_KEY'] ?? _devPrivateKey;
  static String get jwtPublicKey => 
      Platform.environment['JWT_PUBLIC_KEY'] ?? _devPublicKey;
  static String get jwksUrl => 
      Platform.environment['JWKS_URL'] ?? 'http://localhost:8080/.well-known/jwks.json';
}
```

**Dev Keys:** Generate RSA keypair for development:
```bash
openssl genrsa -out dev_private.pem 2048
openssl rsa -in dev_private.pem -pubout -out dev_public.pem
```

---

## 2.2.8: JWKS Endpoint (Optional)

**File:** `routes/.well-known/jwks.dart` (NEW)

```dart
// GET /.well-known/jwks.json
Future<Response> onRequest(RequestContext context) async {
  final jwtService = context.read<JwtService>();
  return Response.json(body: jwtService.getJwks());
}
```

---

## 2.2.9: Update Frontend Token Handling

**File:** `projects/apps/doctor_app/lib/core/network/retry_interceptor.dart` (MODIFY)

- Add `Authorization: Bearer <token>` header
- Handle 401 → token refresh → retry
- Store tokens securely (FlutterSecureStorage)

---

## 2.2.10: Tests

**Files:** `test/core/auth/` (NEW)
- `jwt_service_test.dart` — sign/verify, expiration, invalid tokens
- `auth_middleware_test.dart` — valid/invalid/expired tokens, scope checks
- `auth_integration_test.dart` — full request flow with valid JWT

---

## Success Criteria

| Check | Pass Condition |
|-------|----------------|
| `dart analyze` | No errors |
| `dart test` | All auth tests pass |
| Valid JWT | Request with valid token → 200 |
| Expired JWT | Request with expired token → 401 |
| Invalid sig | Request with tampered token → 401 |
| Missing auth | Request without header → 401 |
| Scope check | `clinical:read` token on write endpoint → 403 |
| JWKS | `GET /.well-known/jwks.json` returns valid JWKS |

---

## Estimated Time

| Step | Duration |
|------|----------|
| JWT service + claims | 2 hours |
| Auth middleware + context | 2 hours |
| Protect all routes | 2 hours |
| Environment config + dev keys | 1 hour |
| Frontend token handling | 2 hours |
| Tests | 2 hours |
| **Total** | **~11 hours** |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Clock skew between services | Accept 30s leeway in `verify()` |
| Key rotation | Implement `/admin/keys/rotate` endpoint; support multiple active keys |
| Token size (many scopes) | Use short scope names; consider opaque tokens for large claims |
| Dev vs prod key management | Never commit real keys; use `.env` + `Platform.environment` |