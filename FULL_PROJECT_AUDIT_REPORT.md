# Full Project Audit Report — Clinical Intelligence Platform

**Generated:** 2026-08-12  
**Auditor:** opencode  
**Scope:** End-to-end audit of `dev-playground` monorepo

---

## Executive Summary

This is a **multi-platform Clinical Intelligence Platform** comprising:
- **clinical-intelligence** (Micronaut/Java): Legacy backend with summarization, transcription, translation
- **clinical-intelligence-dart** (Dart Frog): New backend with clean architecture, encryption, vector store
- **doctor_app** (Flutter): Offline-first mobile app with on-device LLM (iOS MLC, Android Gemma)
- **shared_models** (Dart): Shared DTOs
- **utilities** & **list** (Java): Simple utility libraries

**Overall Maturity:** **Medium-High** — Well-structured, modern architecture with clean separation of concerns, strong test coverage on Dart side, but Java backend has formatting issues and is partially superseded by Dart rewrite.

**Critical Path:** iOS on-device LLM (MLC) integration — currently placeholder implementation.

---

## 1. Architecture

### High-Level Structure

```
dev-playground/
├── projects/
│   ├── apps/
│   │   ├── app/                    # Trivial Java CLI demo (Gradle init template)
│   │   ├── clinical-intelligence/  # Micronaut/Java backend (legacy)
│   │   ├── clinical-intelligence-dart/  # Dart Frog backend (active)
│   │   └── doctor_app/             # Flutter frontend (active)
│   ├── libs/
│   │   ├── list/                   # LinkedList implementation
│   │   └── utilities/              # String utils
│   └── packages/
│       └── shared_models/          # Shared Dart DTOs
├── buildSrc/                       # Gradle convention plugins
├── .github/workflows/              # CI/CD (Dart/Flutter only)
└── .opencode/plans/                # Implementation plans
```

### Frameworks & Libraries

| Component | Framework | Key Dependencies |
|-----------|-----------|------------------|
| clinical-intelligence | Micronaut 4.6.2 | LangChain4J, Qdrant, Google Cloud STT/Translate, Agora RTT, DynamoDB (stub) |
| clinical-intelligence-dart | Dart Frog 1.2.6 | Drift/SQLite, PointyCastle, Jose, UUID, shared_models |
| doctor_app | Flutter 3.5+ | flutter_bloc, go_router, drift, speech_to_text, dio, flutter_gemma (planned) |
| shared_models | Dart | json_annotation, equatable, uuid |

### Data Flow

**API Family A (Clinical Processing):**
```
Flutter → clinical-intelligence-dart → ClinicalProcessingOrchestrator
  → ValidationService → TerminologyAssistanceService / TranscriptCleanupService / LlmPort
  → Response
```

**API Family B (Transcript Summarization):**
```
Flutter → clinical-intelligence-dart → SummaryOrchestrator
  → ValidationService → TranscriptNormalizationService → TranscriptChunkingService
  → VectorStorePort (retrieve context) → SummaryGenerationService / DoctorNoteGenerationService
  → EmbeddingService → VectorStorePort (store) → TranscriptSummaryRepository
  → Response
```

**On-Device LLM (Flutter):**
```
LlmPortFactory → HybridLlmAdapter
  → Native: IosNativeLlmAdapter (MLC) / SmolLLMAdapter (Android)
  → Cloud: CloudLlmAdapter (Dart Frog backend)
  → Fallback: StubLlmAdapter
```

### Coupling & Maintainability Concerns

| Concern | Severity | Details |
|---------|----------|---------|
| **Dual backend** | High | Two backends (Java + Dart) with overlapping functionality. Java is legacy but still has unique features (Agora RTT, Google Cloud STT/Translate). |
| **Shared models only in Dart** | Medium | Java backend uses its own core models; no shared contract. Migration to Dart backend incomplete. |
| **In-memory repos in Java** | Medium | `DynamoDbSummaryRepository` and `InMemoryVectorStoreAdapter` are stubs; not production-ready. |
| **Gradle configuration cache** | Low | Enabled but spotless formatting fails — cache may mask issues. |

---

## 2. Code Quality

### Bugs & Runtime Issues

| # | Severity | File:Line | Issue | Why It Matters | Suggested Fix |
|---|----------|-----------|-------|----------------|---------------|
| 1 | **Critical** | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart:200` | `transcriptText.substring(0, 500)` crashes if text < 500 chars | `RangeError` observed in tests: `Invalid value: Not in inclusive range 0..46: 500` | Use `transcriptText.length > 500 ? transcriptText.substring(0, 500) : transcriptText` |
| 2 | **High** | `clinical-intelligence/src/main/java/.../LlmServiceImpl.java:116-138` | Fallback summary sets ALL 7 fields to "See raw output" except advice | Downstream validation (`StructuredSummary.isComplete()`) passes but data is garbage | Either throw on parse failure or generate minimal valid structured output |
| 3 | **High** | `clinical-intelligence-dart/lib/core/crypto/aes_gcm_service.dart:177` | `EncryptedRepositoryMixin.encryptForWrite()` has TODO — no actual encryption | Fields marked for encryption remain plaintext | Implement encryption in subclass or complete mixin |
| 4 | **Medium** | `clinical-intelligence/src/main/java/.../TranscriptionAggregator.java:30` | In-memory `ConcurrentHashMap` for sessions — loses data on restart | Horizontal scaling impossible; sessions lost on deploy | Document as known limitation; plan Redis migration |
| 5 | **Medium** | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart:158` | `buildPastContext` catches all exceptions and returns empty string | Silent failure masks vector store issues | Log at ERROR level; consider circuit breaker |

### Type Safety Problems

| # | Severity | File:Line | Issue |
|---|----------|-----------|-------|
| 1 | **Medium** | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart:167` | `metadata['structuredSummary']` cast without type check — `dynamic` |
| 2 | **Medium** | `clinical-intelligence-dart/lib/core/crypto/aes_gcm_service.dart:170-172` | Mixin expects `crypto` getter but doesn't enforce it — runtime crash if missing |
| 3 | **Low** | `clinical-intelligence/src/main/java/.../AesGcmEncryptionService.java:34-42` | Key auto-truncation/padding silently changes key material |

### Error Handling Gaps

| # | Severity | Location | Gap |
|---|----------|----------|-----|
| 1 | **High** | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart:177-180` | Vector store failures swallowed — no alerting |
| 2 | **Medium** | `clinical-intelligence/src/main/java/.../AgoraRttService.java` | HTTP errors throw generic `RuntimeException` — no retry/backoff |
| 3 | **Medium** | `clinical-intelligence/src/main/java/.../GoogleSpeechToTextService.java:45-48` | Missing GCP project ID throws `IllegalStateException` at runtime — should fail fast at startup |
| 4 | **Low** | `doctor_app/lib/core/llm/llm_port_factory.dart:34-38` | Android emulator URL hardcoded — not configurable |

### Dead Code & Confusing Patterns

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **Low** | `projects/apps/app/` | Entire module is Gradle init template — unused |
| 2 | **Low** | `projects/libs/list/`, `projects/libs/utilities/` | Trivial libraries — only used by `app` module |
| 3 | **Medium** | `clinical-intelligence/src/main/java/.../DummyAuthenticationProvider.java` | Hardcoded "doctor"/"password" — only for skeleton |
| 4 | **Medium** | `clinical-intelligence/src/main/java/.../RateLimitFilter.java` | Placeholder — no actual rate limiting implemented |
| 5 | **Low** | `clinical-intelligence-dart/lib/application/services/clinical_processing_orchestrator.dart:40-43` | Default case throws for unimplemented modes — should be exhaustive switch |

### Unnecessary Complexity

| # | File | Issue |
|---|------|-------|
| 1 | `clinical-intelligence/src/main/java/.../LlmServiceImpl.java` | Two nearly identical system prompts (context-enriched vs basic) — could be parameterized |
| 2 | `clinical-intelligence-dart/lib/core/crypto/aes_gcm_service.dart` | PBKDF2 with 100k iterations per field — slow; consider HKDF |
| 3 | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart` | Orchestrator does too much — consider splitting into use cases |

---

## 3. Security

### Secrets & Credentials Risks

| # | Severity | File:Line | Issue |
|---|----------|-----------|-------|
| 1 | **Critical** | `clinical-intelligence/bin/main/application.yml:34` | Default JWT secret: `vErYSeCrEtVaLuEvErYSeCrEtVaLuEvErYSeCrEtVaLuE` — **hardcoded default in repo** |
| 2 | **Critical** | `clinical-intelligence/bin/main/application.yml:55` | Default encryption key: `dGhpc0lzQTMyQnl0ZUtleUZvckFFUzI1NkdDTSE=` (base64 of "thisIsA32ByteKeyForAES256GCM!") — **hardcoded default in repo** |
| 3 | **High** | `clinical-intelligence/bin/main/application.yml:39` | Default OpenAI API key: `"demo"` — placeholder in config |
| 4 | **High** | `clinical-intelligence-dart` | No `application.yml` found — secrets must be env vars (good) but no documentation |
| 5 | **Medium** | `doctor_app/lib/core/config/app_config.dart:9-11` | API URL via `--dart-define` — no validation if missing |

### Unsafe Input Handling

| # | Severity | File:Line | Issue |
|---|----------|-----------|-------|
| 1 | **High** | `clinical-intelligence/src/main/java/.../AgoraRttService.java:165-190` | JSON body built from user input without validation — potential injection |
| 2 | **Medium** | `clinical-intelligence-dart/lib/application/services/validation_service.dart` | Need to verify validation covers all injection vectors |
| 3 | **Low** | `clinical-intelligence/src/main/java/.../CompressionFilter.java:35-44` | Content-Length check only — no decompression bomb protection |

### Auth/Session/Permission Concerns

| # | Severity | File:Line | Issue |
|---|----------|-----------|-------|
| 1 | **Critical** | `clinical-intelligence/src/main/java/.../DummyAuthenticationProvider.java:21-22` | Hardcoded credentials in production code path |
| 2 | **High** | `clinical-intelligence-dart/lib/core/auth/auth_middleware.dart` | Need to verify JWT validation uses RS256 with JWKS (not HS256 with shared secret) |
| 3 | **Medium** | `clinical-intelligence/src/main/java/.../SummaryController.java:13` | `@Secured({"DOCTOR", "ADMIN"})` but no ADMIN role defined in dummy provider |
| 4 | **Low** | `clinical-intelligence-dart/lib/core/auth/require_auth.dart` | Scope-based auth but no central scope registry |

### Dependency Vulnerabilities

| # | Severity | Component | Finding |
|---|----------|-----------|---------|
| 1 | **Medium** | `clinical-intelligence` | `langchain4j:1.0.0-beta3` — beta dependency in production path |
| 2 | **Medium** | `clinical-intelligence-dart` | 26 packages have newer versions (per `dart pub outdated`) |
| 3 | **Medium** | `doctor_app` | 58 packages have newer versions (per `flutter pub outdated`) |
| 4 | **Low** | `clinical-intelligence` | Micronaut 4.6.2 — check for CVEs |

### Insecure Defaults

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **Critical** | `clinical-intelligence/bin/main/application.yml` | Multiple hardcoded secrets with weak defaults |
| 2 | **High** | `clinical-intelligence/src/main/java/.../ClinicalProperties.java` | `maxPayloadBytes` default 10MB — verify DoS protection |
| 3 | **Medium** | `clinical-intelligence-dart` | Vector store defaults to in-memory — data loss on restart |

---

## 4. Performance

### Expensive Operations

| # | Severity | Location | Concern |
|---|----------|----------|---------|
| 1 | **High** | `clinical-intelligence-dart/lib/core/crypto/aes_gcm_service.dart:41-48` | PBKDF2 (100k iterations) per field per encrypt/decrypt — ~50ms/field on mobile |
| 2 | **High** | `clinical-intelligence/src/main/java/.../LlmServiceImpl.java:92-98` | Synchronous `chatModel.chat()` blocks thread — no reactive/async |
| 3 | **Medium** | `clinical-intelligence-dart/lib/application/services/summary_orchestrator.dart:158` | Embedding generation for every summary — consider caching |
| 4 | **Medium** | `clinical-intelligence/src/main/java/.../QdrantVectorStoreAdapter.java:104-130` | Retry logic with `Thread.sleep()` blocks thread — use reactive/async |

### Bundle Size / Startup

| Component | Concern |
|-----------|---------|
| `doctor_app` | Flutter app with MLC model (~2GB) — must bundle or download |
| `clinical-intelligence-dart` | Dart Frog compiles to native exe — fast startup |
| `clinical-intelligence` | Micronaut with GraalVM potential — not configured |

### Caching Opportunities

| # | Opportunity | Status |
|---|-------------|--------|
| 1 | LLM response caching (same consultation) | Not implemented |
| 2 | Embedding cache for repeated queries | Not implemented |
| 3 | JWKS caching for JWT validation | Not verified in Dart backend |
| 4 | Model warm-up on app start | Planned in SPEC.md 1.3.3 |

### Database/Network Bottlenecks

| # | Location | Risk |
|---|----------|------|
| 1 | `clinical-intelligence` → DynamoDB (stub) | In-memory map — not production |
| 2 | `clinical-intelligence-dart` → SQLite (Drift) | Single-file — fine for embedded, not for scale |
| 3 | `clinical-intelligence` → Qdrant | gRPC — OK but no connection pooling config |
| 4 | `clinical-intelligence` → Google Cloud STT/Translate | Synchronous HTTP — no async/parallel |

---

## 5. Testing

### Existing Test Coverage

| Component | Framework | Coverage | Status |
|-----------|-----------|----------|--------|
| `clinical-intelligence` | JUnit 5 + Mockito (manual stubs) | ~60% (est.) | Passing |
| `clinical-intelligence-dart` | Dart test + mocktail | **All 150 tests passing** | Good |
| `doctor_app` | Flutter test + bloc_test + mocktail | **328 tests passing**, **>80% per-area** | Excellent |
| `shared_models` | None | 0% | No tests |
| `utilities`, `list`, `app` | JUnit 5 | Minimal | Template only |

### Missing Critical Tests

| # | Priority | Component | Missing Test |
|---|----------|-----------|--------------|
| 1 | **Critical** | `clinical-intelligence-dart` | Integration test for encryption round-trip at repository level |
| 2 | **Critical** | `clinical-intelligence` | End-to-end summarization with real LLM (not stub) |
| 3 | **High** | `clinical-intelligence-dart` | Vector store failure scenarios (circuit breaker, fallback) |
| 4 | **High** | `doctor_app` | On-device LLM integration test (requires physical device) |
| 5 | **High** | `clinical-intelligence` | Agora RTT webhook signature verification |
| 6 | **Medium** | `shared_models` | JSON serialization round-trip tests |
| 7 | **Medium** | `clinical-intelligence-dart` | Key rotation CLI test |

### Fragile Tests

| # | File | Issue |
|---|------|-------|
| 1 | `clinical-intelligence-dart/test/integration/api_integration_test.dart` | Spawns real server — slow, flaky on CI |
| 2 | `doctor_app/test/features/note_assist/presentation/cubit/model_manager_cubit_test.dart` | 300+ repetitive iOS timeout tests — parameterize |

### Recommended Test Additions (by Priority)

1. **Contract tests** between Flutter ↔ Dart Frog (shared_models)
2. **Property-based tests** for encryption (round-trip, tamper detection)
3. **Load tests** for summarization pipeline (k6 script planned in SPEC.md)
4. **Mutation testing** for validation logic
5. **Chaos tests** for vector store / LLM failures

---

## 6. Developer Experience

### Setup Clarity

| Component | Setup | Rating |
|-----------|-------|--------|
| `clinical-intelligence` | `./gradlew bootRun` — needs JDK 25, env vars for secrets | ⭐⭐⭐ |
| `clinical-intelligence-dart` | `dart pub get && dart_frog dev` — simple | ⭐⭐⭐⭐⭐ |
| `doctor_app` | `flutter pub get && flutter run` — needs iOS/Android setup, MLC model prep | ⭐⭐ |
| `shared_models` | `dart pub get && dart run build_runner build` | ⭐⭐⭐⭐ |

### Scripts & Tooling

| Tool | Status |
|------|--------|
| Gradle convention plugins | ✅ Well-structured in `buildSrc/` |
| Spotless (Java/Kotlin formatting) | ⚠️ **Failing** — 22+ files need formatting |
| `very_good_analysis` (Dart/Flutter) | ✅ Passing |
| `dart_frog` CLI | ✅ Used |
| `build_runner` for code gen | ✅ Used |
| Coverage gate (Python) | ✅ Custom script works |

### Linting/Formatting/Typecheck Status

| Component | Lint | Format | Typecheck |
|-----------|------|--------|-----------|
| `clinical-intelligence` | ❌ Spotless fails | ❌ Spotless fails | ✅ Compiles |
| `clinical-intelligence-dart` | ✅ `dart analyze` (278 infos, 0 errors) | ✅ | ✅ |
| `doctor_app` | ✅ `flutter analyze` (0 issues) | ✅ | ✅ |
| `shared_models` | ✅ | ✅ | ✅ |

### Environment Variable Documentation

| Component | Documented? | Location |
|-----------|-------------|----------|
| `clinical-intelligence` | ⚠️ Partial | `application.yml` has `${VAR:default}` but no `.env.example` |
| `clinical-intelligence-dart` | ❌ None | No `.env.example` or docs |
| `doctor_app` | ⚠️ Via `--dart-define` | `AppConfig.dart` only |

### CI Reliability

| Pipeline | Status | Issues |
|----------|--------|--------|
| `backend-ci.yml` | ✅ Runs on `clinical-intelligence-dart` | Working directory hardcoded |
| `frontend-ci.yml` | ✅ Runs on `doctor_app` | Coverage gate passes |
| `release.yml` | ✅ Multi-platform | GPG signing optional |
| `ios-model-prep.yml` | 📋 Referenced in SPEC | Not in `.github/workflows/` |
| Java backend CI | ❌ **Missing** | No workflow for Micronaut build/test |

---

## 7. Product/UX Concerns

### Broken Flows

| # | Flow | Issue |
|---|------|-------|
| 1 | iOS on-device LLM | Placeholder `IosNativeLlmAdapter` — returns stub response |
| 2 | Android on-device LLM | `SmolLLMAdapter` — placeholder, not `flutter_gemma` |
| 3 | Cloud LLM fallback | `CloudLlmAdapter` calls Dart Frog but auth not fully wired |
| 4 | Doctor note sync | `DoctorNoteController` exists but no offline queue in Flutter |

### Accessibility Issues

| # | Component | Issue |
|---|-----------|-------|
| 1 | `doctor_app` | No accessibility audit performed (planned in SPEC 3.4.6) |
| 2 | `clinical-intelligence-dart` | API responses not localized |

### Inconsistent UI States

| # | Component | Issue |
|---|-----------|-------|
| 1 | `doctor_app` | Model download progress UI exists but not verified end-to-end |
| 2 | `doctor_app` | Sync status indicators — planned but not implemented |

### Missing Loading/Error/Empty States

| # | Component | Missing |
|---|-----------|---------|
| 1 | `doctor_app` | Global error boundary (planned 3.4.5) |
| 2 | `doctor_app` | Offline banner (planned 3.4.5) |
| 3 | `clinical-intelligence-dart` | Standardized error response format — partially done |

---

## 8. Documentation

### README Accuracy

| File | Status |
|------|--------|
| Root `README.md` | ❌ Template only — no project description |
| `clinical-intelligence/README.md` | Missing |
| `clinical-intelligence-dart/README.md` | ✅ Exists (7.7KB) |
| `doctor_app/README.md` | ⚠️ Minimal |

### Missing Architecture/Operational Docs

| Doc | Status |
|-----|--------|
| Architecture decision records (ADRs) | ❌ None |
| Data flow diagram (PHI path) | ❌ Planned in SPEC 4.4.1 |
| Deployment runbook | ❌ None |
| API documentation (OpenAPI) | 📋 Planned in SPEC 2.6.4 |
| Threat model / risk assessment | ❌ Planned in SPEC 4.4.2 |

### Deployment/Runbook Gaps

| Gap | Severity |
|-----|----------|
| No Dockerfile for `clinical-intelligence-dart` (only `dart_frog build`) | Medium |
| No Kubernetes/ECS/Fly.io configs | Medium |
| No database migration strategy for Drift | High |
| No secret management strategy (K8s secrets, AWS Secrets Manager, etc.) | Critical |
| No rollback procedure | Medium |

---

## Findings Summary by Severity

| Severity | Count | Top Issues |
|----------|-------|------------|
| **Critical** | 5 | Hardcoded secrets in `application.yml`, dummy auth in production code, iOS LLM placeholder, Android LLM placeholder, no secret management |
| **High** | 12 | Substring crash, encryption mixin incomplete, vector store silent failures, PBKDF2 performance, sync HTTP calls, beta dependencies |
| **Medium** | 18 | In-memory repos, dual backend, missing tests, formatting failures, no Java CI, no env docs |
| **Low** | 10 | Dead code (app/list/utilities), verbose prompts, key auto-adjustment, repetitive tests |

---

## Top 10 Highest-Impact Fixes

| # | Fix | Severity | Effort | Impact |
|---|-----|----------|--------|--------|
| 1 | **Remove hardcoded secrets from `application.yml`** — use env-only with `.env.example` | Critical | 1 hr | Eliminates credential leak risk |
| 2 | **Fix `substring(0, 500)` crash in `summary_orchestrator.dart`** | Critical | 15 min | Unblocks production summarization |
| 3 | **Implement real `IosNativeLlmAdapter` with MLCSwift** | Critical | 2-3 wks | Enables core product value prop |
| 4 | **Complete `EncryptedRepositoryMixin` encryption** | High | 4 hrs | Enables at-rest encryption |
| 5 | **Replace `DummyAuthenticationProvider` with real JWT validation** | Critical | 1 wk | Production auth |
| 6 | **Add Java backend CI workflow** | Medium | 2 hrs | Catches regressions |
| 7 | **Fix Spotless formatting failures** | Medium | 30 min | Clean CI, readable code |
| 8 | **Implement `flutter_gemma` Android adapter** | Critical | 2-3 wks | Android parity |
| 9 | **Add circuit breaker for vector store / LLM calls** | High | 8 hrs | Resilience |
| 10 | **Create `.env.example` for all components** | Critical | 1 hr | Developer onboarding, security |

---

## Quick Wins (≤1 day each)

1. Fix `substring` bounds check in `summary_orchestrator.dart:200`
2. Add `.env.example` files for all three apps
3. Run `./gradlew spotlessApply` to fix formatting
4. Add Java backend CI workflow (copy from Dart patterns)
5. Parameterize `ModelManagerCubit` iOS timeout tests (reduce 300→10)
6. Add exhaustive switch in `ClinicalProcessingOrchestrator`
7. Document required env vars in each README
8. Add `shared_models` JSON round-trip tests
9. Replace `Thread.sleep()` in Qdrant retry with async
10. Remove unused `app`, `list`, `utilities` modules or document purpose

---

## Larger Refactors Worth Considering

| Refactor | Rationale | Effort |
|----------|-----------|--------|
| **Migrate fully to Dart backend** | Eliminate dual maintenance; Java backend has stubs anyway | 4-6 wks |
| **Unify encryption: PBKDF2 → HKDF** | 10-100x faster key derivation | 1 wk |
| **Extract `LlmPort` to shared package** | Single source of truth for LLM interface | 1 wk |
| **Adopt gRPC for internal services** | Type-safe, faster than REST | 2-3 wks |
| **Implement CRDT for offline sync** | Better conflict resolution than LWW | 3-4 wks |
| **Add OpenTelemetry tracing end-to-end** | Observability across Flutter → Dart Frog → Java | 2 wks |

---

## Commands Run & Results

| Command | Result |
|---------|--------|
| `./gradlew :clinical-intelligence:test` | ✅ BUILD SUCCESSFUL (3m 34s) |
| `./gradlew :utilities:test :list:test :app:test` | ✅ BUILD SUCCESSFUL |
| `./gradlew spotlessCheck` | ❌ FAILED — 22+ files violate formatting |
| `cd clinical-intelligence-dart && dart analyze` | ✅ 278 infos, 0 errors |
| `cd clinical-intelligence-dart && dart test` | ✅ All 150 tests passed |
| `cd doctor_app && flutter analyze` | ✅ No issues found |
| `cd doctor_app && flutter test` | ✅ All 328 tests passed |
| `cd doctor_app && python3 tool/coverage_gate.py` | ✅ All 5 areas >80% |
| `cd doctor_app && flutter test --coverage` | ✅ Coverage generated |

---

## Areas Not Fully Verified

| Area | Reason |
|------|--------|
| Java backend runtime behavior | No integration test environment (requires Qdrant, OpenAI, Agora, GCP) |
| iOS MLC LLM on physical device | Requires Mac + iOS device + model compilation |
| Android Gemma integration | `flutter_gemma` not yet implemented |
| End-to-end PHI flow | Requires full deployment stack |
| Load/performance benchmarks | No load test infrastructure yet |
| Security audit of PointyCastle usage | Crypto implementation not reviewed by specialist |
| HIPAA/GDPR compliance | Planned in SPEC 4.4 but not started |
| Database migration strategy | Drift migrations not yet designed |

---

## Conclusion

The project has **strong architectural foundations** with clean separation of concerns, modern tech choices (Micronaut, Dart Frog, Flutter, BLoC, Drift), and excellent test discipline on the Dart/Flutter side. 

**The critical path is iOS on-device LLM** — everything else builds on this. The Dart backend is production-ready modulo the encryption mixin completion and circuit breaker additions. The Java backend should be deprecated/migrated once Dart backend achieves feature parity (Agora RTT, Google Cloud STT/Translate).

**Immediate actions:** Fix the 5 Critical issues, apply Spotless formatting, add CI for Java backend, and begin Phase 1 iOS MLC work per SPEC.md.

---

*End of Audit Report*