# Clinical Intelligence Platform — Improvement Specification

**Version:** 1.0  
**Date:** 2026-08-05  
**Status:** Draft — For Review & Planning  

---

## 🎯 Executive Summary

This specification outlines a phased improvement plan for the Clinical Intelligence platform comprising:
- **clinical-intelligence-dart**: Dart Frog backend (clinical text processing APIs)
- **doctor_app**: Flutter frontend (offline-first clinical note-taking with on-device LLM)

**Primary Goal:** Production-ready, compliant clinical AI system with working iOS native LLM (MLC LLM) and hardened backend/frontend.

---

## 📋 Phase 1: iOS Native LLM — Make It Work (Critical Path)

### 1.1 Prerequisites & Environment Setup

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 1.1.1 | Verify Mac build environment | `cmake >= 3.24`, `git-lfs`, `rustc`, `python3`, `mlc_llm` pip package installed |
| 1.1.2 | Run `ios/scripts/prepare_model.sh` | Model artifacts generated at `ios/mlc-llm/` with `MLCSwift` package |
| 1.1.3 | Add MLCSwift as local Swift Package in Xcode | `File → Add Package Dependencies → Add Local → ios/mlc-llm/MLCSwift` succeeds |
| 1.1.4 | Verify model in Copy Bundle Resources | `Llama-3.2-3B-Instruct-q4f16_1-MLC` appears in Build Phases → Copy Bundle Resources |
| 1.1.5 | Build & run on physical iOS device (A15+, 6GB+ RAM) | App launches without MLCSwift linking errors |

### 1.2 Replace Placeholder Implementation with Real MLCSwift API

**File:** `ios/Runner/AppDelegate.swift` (embedded `MLCLLMHandler` class)

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 1.2.1 | Extract `MLCLLMHandler` to separate `MLCLLMHandler.swift` | New file created; AppDelegate imports and instantiates it |
| 1.2.2 | Add `import MLCSwift` and type `engine` as `MLCEngine` | No more `Any` type; compile-time safety |
| 1.2.3 | Implement `initializeEngine()` with real API | `MLCEngine().reload(modelPath:..., modelLib:...)` works |
| 1.2.4 | Implement `generateNonStreaming()` with real API | `engine.chat.completions.create(messages:...)` returns response |
| 1.2.5 | Implement `generateStreaming()` with real streaming API | Tokens emitted via EventChannel; `[DONE]` sentinel sent |
| 1.2.6 | Add proper error handling for all MLCSwift calls | Structured `MLCError` types propagated to Dart |
| 1.2.7 | Add `deinit` to release engine resources | No memory leaks on handler deallocation |

### 1.3 Model Verification & Health Checks

**File:** `lib/features/note_assist/presentation/cubit/model_manager_cubit.dart`

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 1.3.1 | Enhance `_checkIosModel()` to test full pipeline | Sample inference "Hello" → valid response within 30s |
| 1.3.2 | Add model version/checksum verification | Detect corrupted/incomplete model bundles |
| 1.3.3 | Add warm-up inference on app start | First user request doesn't include cold-start latency |
| 1.3.4 | Surface detailed error messages to UI | User sees actionable error (e.g., "Model not bundled — run prepare_model.sh") |

### 1.4 Dart-Swift Channel Contract Hardening

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 1.4.1 | Define channel protocol in shared documentation | `CHANNEL_CONTRACT.md` with method signatures, types, error codes |
| 1.4.2 | Add request/response timeouts on Dart side | Configurable timeouts; proper `TimeoutException` handling |
| 1.4.3 | Implement streaming cancellation | User can cancel generation mid-stream |
| 1.4.4 | Add binary message support for large payloads | Optional: use `StandardMethodCodec` for efficiency |

---

## 📋 Phase 2: Backend Hardening — clinical-intelligence-dart

### 2.1 Persistence Layer (Replace In-Memory)

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.1.1 | Add Drift + SQLite dependencies | `pubspec.yaml` updated; `drift_dev` build runner configured |
| 2.1.2 | Define Drift schema for transcripts & summaries | Tables: `transcripts`, `summary_bundles`, `processed_outputs` |
| 2.1.3 | Implement `DriftTranscriptRepository` | Implements `TranscriptRepository` port; CRUD + query by consultationId |
| 2.1.4 | Implement `DriftSummaryRepository` | Implements `TranscriptSummaryRepository` port |
| 2.1.5 | Implement `DriftProcessedOutputRepository` | Implements `ProcessedOutputRepository` port |
| 2.1.6 | Add migration strategy | Versioned migrations; backward compatibility |
| 2.1.7 | Update `_middleware.dart` to use Drift repos | Replace `InMemory*Repository` with Drift implementations |
| 2.1.8 | Add integration tests for persistence | Test save/load/find across restarts |

### 2.2 Authentication & Authorization

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.2.1 | Design JWT token structure | Claims: `sub` (doctorId), `roles`, `exp`, `iat`, `scope` |
| 2.2.2 | Add `AuthMiddleware` in Dart Frog | Validates JWT on protected routes; extracts claims |
| 2.2.3 | Port Java backend's token validation logic | RS256 verification; JWKS caching |
| 2.2.4 | Add role-based access control | Scopes: `clinical:read`, `clinical:write`, `summary:read`, `summary:write` |
| 2.2.5 | Add optional API key support for service-to-service | Header `X-API-Key` with rate limiting |
| 2.2.6 | Update route handlers to use auth context | `context.read<AuthContext>()` for current user |

### 2.3 Audit Logging & Compliance

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.3.1 | Define audit event schema | `AuditEvent { id, timestamp, userId, action, resource, outcome, metadata }` |
| 2.3.2 | Implement `AuditLogger` service | Async, buffered writes; structured JSON output |
| 2.3.3 | Add audit middleware | Logs all API requests with PHI redaction |
| 2.3.4 | Implement PHI detection/redaction | Regex-based PHI patterns; configurable |
| 2.3.5 | Add log retention & export | Configurable retention; GDPR/HIPAA export format |

### 2.4 Encryption at Rest (Port from Java)

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.4.1 | Add AES-GCM encryption service | 256-bit keys; per-field encryption |
| 2.4.2 | Integrate with Drift repositories | Transparent encryption/decryption on save/load |
| 2.4.3 | Key management strategy | Master key in iOS Keychain / Android Keystore; DEK rotation |
| 2.4.4 | Add key rotation CLI | `dart run bin/rotate_keys.dart` |

### 2.5 Vector Store for Context-Enriched Summaries

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.5.1 | Evaluate embedding models | Local: `sentence-transformers` via Python; Cloud: OpenAI/Cohere |
| 2.5.2 | Implement in-memory vector index (MVP) | HNSW or flat index; cosine similarity |
| 2.5.3 | Add `VectorStorePort` and implementation | `add(embedding, metadata)`, `search(query, k)` |
| 2.5.4 | Integrate into `SummaryOrchestrator` | Fetch relevant past consults for context-enriched summary |

### 2.6 API Enhancements & Testing

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 2.6.1 | Implement missing processing modes | `SUMMARIZE`, `GENERATE_DOCTOR_NOTE`, `FULL_BUNDLE` in `ClinicalProcessingOrchestrator` |
| 2.6.2 | Complete transcript summary routes | `POST /regenerate` implementation |
| 2.6.3 | Add request/response validation middleware | Shared validation; consistent error format |
| 2.6.4 | Add OpenAPI/Swagger documentation | `dart_frog_openapi` package; auto-generated |
| 2.6.5 | Add integration test suite | Test all routes with real LLM adapters (stub + Ollama) |
| 2.6.6 | Add load testing script | `k6` or `dart:benchmark` for throughput baselines |

---

## 📋 Phase 3: Frontend Polish — doctor_app

### 3.1 Android Native LLM (Gemma via flutter_gemma)

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 3.1.1 | Complete `_FlutterGemmaProxy` implementation | Real `FlutterGemmaPlugin.instance.init()` + `getResponse()` |
| 3.1.2 | Add model download with progress | Signed URL from backend; resume support; integrity check |
| 3.1.3 | Implement `_checkAndroidModel()` with real verification | Sample inference test like iOS |
| 3.1.4 | Add Gemma model version management | Check for updates; migrate on version change |
| 3.1.5 | Handle GPU/CPU fallback gracefully | Detect device capabilities; log selected backend |

### 3.2 Sync Queue & Offline-First Enhancements

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 3.2.1 | Implement conflict resolution | Last-write-wins + manual merge UI for notes |
| 3.2.2 | Add exponential backoff retry | Configurable max retries; dead letter queue |
| 3.2.3 | Add sync status UI | Per-note sync indicator; pull-to-refresh |
| 3.2.4 | Implement background sync | `workmanager` / `background_fetch` for periodic sync |
| 3.2.5 | Add offline queue persistence | Drift table for pending operations; survives app kill |

### 3.3 Speech-to-Text Service

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 3.3.1 | Unify `SpeechService` implementations | Single interface; platform-specific adapters |
| 3.3.2 | Add on-device speech (iOS: Speech.framework, Android: RecognizerIntent) | No cloud dependency for dictation |
| 3.3.3 | Add punctuation & formatting | Medical terminology awareness |
| 3.3.4 | Add voice activity detection | Auto-stop on silence; configurable timeout |
| 3.3.5 | Implement speaker diarization (stretch) | Separate doctor/patient segments |

### 3.4 UI/UX Improvements

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 3.4.1 | Consultation list page | Search, filter, infinite scroll |
| 3.4.2 | Note editor enhancements | Rich text; voice input button; AI assist panel |
| 3.4.3 | Model manager page | Show model info (version, size, device); download progress |
| 3.4.4 | Settings page | Cloud fallback toggle; PHI consent; log export |
| 3.4.5 | Error boundary & recovery UI | Global error handler; retry actions; offline banner |
| 3.4.6 | Accessibility audit | VoiceOver/TalkBack support; dynamic type |

### 3.5 Testing & Quality

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 3.5.1 | Unit test coverage > 80% | `flutter test --coverage`; focus on cubits, services |
| 3.5.2 | Widget test key flows | Model download → editor → sync |
| 3.5.3 | Integration test on device | Full consultation create → dictate → AI assist → sync |
| 3.5.4 | Golden tests for UI | `flutter test --update-goldens` |
| 3.5.5 | Performance profiling | `flutter run --profile`; frame timing; memory leaks |

---

## 📋 Phase 4: Production Readiness & Observability

### 4.1 CI/CD Pipelines

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 4.1.1 | Backend CI (GitHub Actions) | `dart analyze`, `dart test`, `dart_frog build` on PR |
| 4.1.2 | Frontend CI (GitHub Actions) | `flutter analyze`, `flutter test`, `flutter build ios/android` |
| 4.1.3 | iOS model preparation automation | CI job runs `prepare_model.sh` on tag; uploads artifacts |
| 4.1.4 | Release automation | Tag-based releases; changelog generation; TestFlight/Play Console deploy |

### 4.2 Observability Stack

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 4.2.1 | Structured logging (backend) | JSON logs; correlation IDs; log levels |
| 4.2.2 | Structured logging (frontend) | `dart:developer` + platform loggers; user consent |
| 4.2.3 | Metrics collection | Prometheus endpoint (backend); custom events (frontend) |
| 4.2.4 | Distributed tracing | W3C TraceContext; propagate through Flutter → Dart Frog |
| 4.2.5 | Alerting rules | Error rate > 5%; latency p99 > 5s; model load failures |

### 4.3 Security Hardening

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 4.3.1 | Certificate pinning (backend) | Pin Dart Frog TLS cert in Flutter app |
| 4.3.2 | Certificate pinning (MLC model) | Verify model bundle integrity on load |
| 4.3.3 | Secure storage audit | iOS Keychain / Android Keystore for all secrets |
| 4.3.4 | Network security config | Cleartext traffic blocked; HSTS |
| 4.3.5 | Dependency scanning | `dart pub outdated`; `flutter pub outdated`; Snyk/Dependabot |

### 4.4 Compliance Documentation

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| 4.4.1 | Data flow diagram | PHI path: device → (optional) cloud → storage |
| 4.4.2 | Risk assessment | Threat model; mitigations documented |
| 4.4.3 | HIPAA/GDPR compliance checklist | BAAs; DPIA; breach notification procedure |
| 4.4.4 | User consent flow | In-app consent for cloud processing; audit trail |

---

## 🔗 Cross-Cutting Technical Decisions

### Architecture Patterns
- **Backend:** Clean Architecture (Ports & Adapters) — already established
- **Frontend:** BLoC + Repository + UseCase — already established
- **Communication:** REST + JSON (current); consider gRPC for internal services later

### Data Models
- **Shared DTOs:** Consider `protobuf` or `json_serializable` with shared package for type safety across Dart/Flutter
- **Versioning:** API version in URL (`/api/v1/`); DTO version in `Content-Type` header

### LLM Provider Abstraction
- **Current:** `LlmPort` interface with 3 implementations (Native, Cloud, Stub)
- **Future:** Add provider registry for dynamic model selection (Llama, Gemma, Mistral, etc.)

### Error Handling Strategy
```
Domain Errors (ValidationException, ComplianceException) → 400/403
Infrastructure Errors (NetworkException, LlmException) → 503/500
Unknown Errors → 500 with correlation ID for debugging
```

---

## 📅 Timeline Estimate (Sequential Phases)

| Phase | Duration | Key Dependencies |
|-------|----------|------------------|
| Phase 1: iOS Native LLM | 2-3 weeks | Physical iOS device; Mac with prerequisites |
| Phase 2: Backend Hardening | 3-4 weeks | Phase 1 complete (for integration testing) |
| Phase 3: Frontend Polish | 3-4 weeks | Phase 1 complete; Phase 2 API stable |
| Phase 4: Production Readiness | 2-3 weeks | All prior phases complete |
| **Total** | **10-14 weeks** | — |

**Parallelization Opportunities:**
- Phase 2.1 (Persistence) can start before Phase 1 complete
- Phase 3.1 (Android Gemma) independent of iOS work
- Phase 4.1 (CI/CD) can start early

---

## ❓ Open Questions & Decisions Needed

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | **iOS Model Distribution** | Bundle in app (~2GB) vs. Download on first run | Bundle for offline-first; add OTA update later |
| 2 | **Cloud LLM Provider** | Ollama (self-hosted) vs. Managed (OpenAI, Anthropic, Vertex) | Ollama for compliance; managed for dev/staging |
| 3 | **Vector Store** | In-memory (MVP) vs. SQLite-vec vs. pgvector vs. Qdrant | SQLite-vec for embedded; Qdrant for scale |
| 4 | **Auth Provider** | Custom JWT vs. Firebase Auth vs. Auth0 vs. Keycloak | Keycloak for self-hosted control |
| 5 | **Real-time Sync** | Polling (current) vs. WebSocket vs. Server-Sent Events | SSE for simplicity; WebSocket if collaborative editing |
| 6 | **Multi-tenant** | Single-tenant per doctor vs. Clinic-level tenancy | Clinic-level with role-based access |
| 7 | **Offline-First Conflict Resolution** | LWW + manual merge vs. CRDT (Automerge/Yjs) | LWW + manual for v1; CRDT for v2 |

---

## 📦 Deliverables Checklist

### Phase 1 Deliverables
- [ ] Working iOS MLC LLM inference on physical device
- [ ] `MLCLLMHandler.swift` extracted and documented
- [ ] Channel contract documented (`CHANNEL_CONTRACT.md`)
- [ ] Model verification in `ModelManagerCubit` passes

### Phase 2 Deliverables
- [ ] Drift persistence with migrations
- [ ] JWT auth middleware on all routes
- [ ] Audit logging with PHI redaction
- [ ] AES-GCM encryption at rest
- [ ] Vector store integration (MVP)
- [ ] OpenAPI docs + integration tests

### Phase 3 Deliverables
- [ ] Working Android Gemma inference
- [ ] Real model download with progress
- [ ] Conflict-resolving sync queue
- [ ] Unified speech-to-text service
- [ ] Consultation list + editor UI
- [ ] >80% test coverage

### Phase 4 Deliverables
- [ ] CI/CD pipelines passing
- [ ] Observability stack deployed
- [ ] Security audit complete
- [ ] Compliance documentation package

---

## 🛠 Tooling & Scripts to Create

| Script | Purpose | Location |
|--------|---------|----------|
| `scripts/setup_ios_mlc.sh` | Automate Phase 1.1-1.2 | `doctor_app/ios/scripts/` |
| `scripts/rotate_keys.dart` | Encryption key rotation | `clinical-intelligence-dart/bin/` |
| `scripts/load_test.k6.js` | Backend load testing | `clinical-intelligence-dart/` |
| `scripts/generate_openapi.dart` | API docs generation | `clinical-intelligence-dart/bin/` |
| `scripts/verify_model.dart` | Model integrity check | `doctor_app/bin/` |

---

## 📚 Reference Documents

- `clinical-intelligence-dart/README.md` — Backend architecture
- `doctor_app/ios/Runner/AppDelegate.swift` — MLCSwift integration point
- `doctor_app/lib/core/llm/ios_native_llm_adapter.dart` — Dart side of channel
- `doctor_app/lib/core/llm/hybrid_llm_adapter.dart` — Fallback logic
- `doctor_app/ios/scripts/prepare_model.sh` — Model compilation script
- `doctor_app/ios/mlc-package-config.json` — MLC model configuration

---

## ✅ Next Steps

1. **Review this SPEC.md** — Confirm priorities, timeline, open questions
2. **Decide on open questions** — Especially #1 (model distribution), #2 (cloud provider), #4 (auth)
3. **Assign ownership** — Backend vs. Frontend vs. DevOps
4. **Create GitHub Issues/Epics** — One per major task group
5. **Start Phase 1.1** — Environment verification on Mac

---

*End of Specification*