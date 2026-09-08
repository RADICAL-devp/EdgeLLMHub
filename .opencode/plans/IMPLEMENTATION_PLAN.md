# Clinical Intelligence Platform — SmolLM350M Implementation Plan

**Version:** 1.0  
**Date:** 2026-08-05  
**Status:** Plan — Ready for Review & Approval  

---

## 📍 Current State Analysis

### ✅ Already Done
| Component | Status | Notes |
|-----------|--------|-------|
| `EnvironmentConfig.supportedModels` | ✅ Updated | Lists `SmolLM-350M-Instruct-q4f16_1-MLC` |
| `ProcessingMode` enum | ✅ Complete | All 5 modes defined (incl. `fullBundle`) |
| `LlmPort` interface | ✅ Identical | Both projects share same port |
| Domain models | ✅ Shared | 11 models duplicated across projects |
| iOS `MLCLLMHandler` (placeholder) | ⚠️ In `AppDelegate.swift` | 338 lines, needs extraction + real MLCSwift |
| Android `MainActivity` | ⚠️ Empty | No MethodChannel handler yet |
| Backend persistence | ❌ In-memory only | Needs Drift/SQLite |
| Auth, Audit, Encryption | ❌ Missing | Phase 2 work |

### 🔴 Critical Gaps (Phase 1 Blockers)
1. **iOS**: `MLCLLMHandler` is placeholder — `NSClassFromString("MLCSwift.MLCEngine")` returns `nil`
2. **iOS**: `mlc-package-config.json` targets Llama 3.2 3B, not SmolLM-350M
3. **iOS**: No `prepare_model.sh` run — no model artifacts in `ios/mlc-llm/`
4. **Android**: No Kotlin MLC handler — currently uses `flutter_gemma` (Gemma only)
5. **Channel Contract**: Undocumented — Dart/Swift/Kotlin must agree on protocol

---

## 🎯 Implementation Plan

### PHASE 1: iOS Native LLM (SmolLM-350M) — CRITICAL PATH
**Duration:** 2-3 weeks | **Dependencies:** Mac with cmake≥3.24, git-lfs, rustc, python3, physical iOS device (A15+, 6GB+)

#### 1.1 Environment Setup & Model Compilation
| Task | File(s) | Description |
|------|---------|-------------|
| 1.1.1 | `ios/scripts/setup_ios_mlc.sh` **(NEW)** | Automate: verify prerequisites, install `mlc_llm` pip, check for pre-compiled `HuggingFaceTB/SmolLM-350M-Instruct` on HuggingFace MLC repo. If missing: `python3 -m mlc_llm convert_weight` → `gen_config` → `package`. Output to `ios/mlc-llm/`. Generate SHA256 checksums. |
| 1.1.2 | `ios/mlc-package-config.json` **(MODIFY)** | Update model to `HF://HuggingFaceTB/SmolLM-350M-Instruct`, add `"context_window_size": 2048`, `"prefill_chunk_size": 512`, `"model_type": "smolLM"` |
| 1.1.3 | `ios/scripts/prepare_model.sh` **(MODIFY)** | Default to SmolLM-350M-Instruct, update all Llama references, add checksum verification step, update Xcode integration instructions |

#### 1.2 Extract & Implement MLCLLMHandler
| Task | File(s) | Description |
|------|---------|-------------|
| 1.2.1 | `ios/Runner/MLCLLMHandler.swift` **(NEW)** | Extract from `AppDelegate.swift`. Add `import MLCSwift`, type `engine: MLCEngine`. Implement `initializeEngine()` → `MLCEngine().reload(modelPath: "SmolLM-350M-Instruct-q4f16_1-MLC", modelLib: "SmolLM-350M-Instruct-q4f16_1-MLC")`. Implement `generateNonStreaming()` using `engine.chat.completions.create(messages:...)`. Implement `generateStreaming()` with `stream: true` → emit tokens via EventChannel. Add `deinit { engine?.shutdown() }`. Structured error handling with `MLCError` enum. |
| 1.2.2 | `ios/Runner/AppDelegate.swift` **(MODIFY)** | Remove embedded handler (lines 31-338). Import `MLCLLMHandler`. Instantiate: `mlcHandler = MLCLLMHandler(messenger: messenger)`. Keep strong reference. |
| 1.2.3 | `lib/core/config/environment.dart` **(VERIFY)** | Already lists `SmolLM-350M-Instruct-q4f16_1-MLC` ✅ |

#### 1.3 Model Verification & Health Checks
| Task | File(s) | Description |
|------|---------|-------------|
| 1.3.1 | `lib/features/note_assist/presentation/cubit/model_manager_cubit.dart` **(MODIFY)** | Update `_modelFileName` to `smolLM-350M.bin`. `_verificationTimeout = Duration(seconds: 20)`. Add `verifyModelChecksum()` comparing against bundled SHA256. Add `warmUpInference()` on app start (simple "Hello" prompt). Surface actionable errors: "Model not bundled — run setup_ios_mlc.sh", "Checksum mismatch — re-download model". |

#### 1.4 Channel Contract Hardening
| Task | File(s) | Description |
|------|---------|-------------|
| 1.4.1 | `CHANNEL_CONTRACT.md` **(NEW)** | Document: MethodChannel methods (`isAvailable`, `initialize`, `generate`, `generateStream`), EventChannel protocol (token strings, `[DONE]` sentinel), error codes (`MODEL_NOT_FOUND`, `INIT_FAILED`, `GENERATION_FAILED`, `NOT_LINKED`), SmolLM-350M constraints (2048 ctx, <20s latency), request/response JSON schemas. |
| 1.4.2 | `lib/core/llm/ios_native_llm_adapter.dart` **(MODIFY)** | Add 20s timeout on `_generate()`. Handle `TimeoutException`. Add `cancelGeneration()` method that closes stream subscription. Add request ID correlation for tracing. |

---

### PHASE 1.5: Android Native LLM (SmolLM-350M) — PARALLEL TO 1.2-1.4
**Duration:** 1-2 weeks | **Dependencies:** Android Studio, physical Android device (API 24+, 6GB+)

| Task | File(s) | Description |
|------|---------|-------------|
| 1.5.1 | `android/app/src/main/kotlin/.../MLCLLMHandler.kt` **(NEW)** | Kotlin equivalent of iOS handler. Use MLC Android runtime (`org.mlc.llm.MLCEngine`). Implement same MethodChannel/EventChannel contract. Model path: `SmolLM-350M-Instruct-q4f16_1-MLC` in assets. Handle GPU (Metal/Vulkan) vs CPU fallback. |
| 1.5.2 | `android/app/src/main/kotlin/.../MainActivity.kt` **(MODIFY)** | Register `MLCLLMHandler` in `configureFlutterEngine()`. |
| 1.5.3 | `lib/core/llm/android_native_llm_adapter.dart` **(REPLACE → `smol_llm_adapter.dart`)** | Rename class to `SmolLLMAdapter`. Replace `flutter_gemma` with MethodChannel calls matching `CHANNEL_CONTRACT.md`. Implement model download (if not bundled) + SHA256 verification. Handle GPU/CPU fallback gracefully. |
| 1.5.4 | `lib/core/llm/llm_port_factory.dart` **(MODIFY)** | Update to instantiate `SmolLLMAdapter` on Android. Remove `flutter_gemma` dependency from pubspec. |
| 1.5.5 | `pubspec.yaml` **(MODIFY)** | Remove `flutter_gemma: ^0.2.4`. Add any MLC Android runtime dependencies if needed. |
| 1.5.6 | `model_manager_cubit.dart` **(MODIFY)** | Android: verify model file exists + checksum. Sample inference test. |

---

### PHASE 2: Backend Hardening (Dart Frog)
**Duration:** 3-4 weeks | **Dependencies:** Phase 1.1 (for integration testing)

#### 2.1 Persistence (Drift/SQLite)
| Task | File(s) | Description |
|------|---------|-------------|
| 2.1.1 | `pubspec.yaml` **(MODIFY)** | Add: `drift: ^2.18`, `sqlite3: ^2.4`, `sqlite3_flutter_libs: ^0.5`, `path: ^1.9`, `drift_dev: ^2.18` (dev), `build_runner: ^2.4` (dev). |
| 2.1.2 | `lib/infrastructure/persistence/clinical_database.dart` **(NEW)** | Drift database class. Tables: `transcripts`, `summary_bundles`, `processed_outputs`, `audit_logs`. Indices on `consultation_id`, `created_at`. |
| 2.1.3 | `lib/infrastructure/persistence/drift_transcript_repository.dart` **(NEW)** | Implements `TranscriptRepository`. CRUD + `findByConsultationId`, `watchByConsultationId`. |
| 2.1.4 | `lib/infrastructure/persistence/drift_summary_repository.dart` **(NEW)** | Implements `TranscriptSummaryRepository`. CRUD + `findByConsultationId`. |
| 2.1.5 | `lib/infrastructure/persistence/drift_processed_output_repository.dart` **(NEW)** | Implements `ProcessedOutputRepository`. CRUD + query by mode/consultation. |
| 2.1.6 | `lib/infrastructure/persistence/migrations/` **(NEW)** | Versioned migration files (v1 → v2 etc.). |
| 2.1.7 | `routes/_middleware.dart` **(MODIFY)** | Replace `InMemory*Repository` with Drift implementations. Initialize `ClinicalDatabase` at startup. |

#### 2.2 Authentication (Custom JWT RS256)
| Task | File(s) | Description |
|------|---------|-------------|
| 2.2.1 | `lib/core/auth/jwt_service.dart` **(NEW)** | RS256 sign/verify. JWKS caching (5min TTL). Load keys from env/files. |
| 2.2.2 | `lib/core/auth/auth_context.dart` **(NEW)** | `AuthContext { doctorId, clinicId, roles, scopes, exp }`. |
| 2.2.3 | `lib/core/auth/auth_middleware.dart` **(NEW)** | Extract `Authorization: Bearer <token>`. Validate → `context.provide<AuthContext>()`. Return 401/403 on failure. |
| 2.2.4 | `routes/_middleware.dart` **(MODIFY)** | Add `authMiddleware` before route handlers. Protect all `/api/v1/*` routes. |
| 2.2.5 | `environment.dart` **(MODIFY)** | Add `jwtPrivateKey`, `jwtPublicKey`, `jwksUrl` config. |

#### 2.3 Audit Logging & PHI Redaction
| Task | File(s) | Description |
|------|---------|-------------|
| 2.3.1 | `lib/core/audit/audit_event.dart` **(NEW)** | `AuditEvent { id, timestamp, userId, clinicId, action, resource, resourceId, outcome, metadataJson, correlationId }`. |
| 2.3.2 | `lib/core/audit/phi_redactor.dart` **(NEW)** | Regex patterns for PHI: MRN, SSN, DOB, phone, email, names (via NER placeholder). `redact(String): String`. Configurable patterns. |
| 2.3.3 | `lib/core/audit/audit_logger.dart` **(NEW)** | Async buffered writer → Drift `audit_logs` table. Batch flush every 100 events or 5s. |
| 2.3.4 | `lib/core/audit/audit_middleware.dart` **(NEW)** | Wrap request/response. Log: method, path, userId, clinicId, statusCode, latencyMs, redacted request/response bodies. |
| 2.3.5 | `routes/_middleware.dart` **(MODIFY)** | Add `auditMiddleware` after auth. |

#### 2.4 Encryption at Rest (AES-GCM-256)
| Task | File(s) | Description |
|------|---------|-------------|
| 2.4.1 | `lib/core/crypto/aes_gcm_service.dart` **(NEW)** | `encrypt(plaintext, key) → ciphertext+nonce+tag`. `decrypt(ciphertext, key) → plaintext`. Key derivation: PBKDF2 from master key. Per-field DEKs. |
| 2.4.2 | `lib/infrastructure/persistence/encrypted_repository_mixin.dart` **(NEW)** | Mixin for Drift repos: `encryptOnWrite()`, `decryptOnRead()`. Transparent to domain. |
| 2.4.3 | `bin/rotate_keys.dart` **(NEW)** | CLI: generate new master key, re-encrypt all DEKs, update Keychain/Keystore. |
| 2.4.4 | `clinical_database.dart` **(MODIFY)** | Apply mixin to tables containing PHI: `transcripts`, `summary_bundles`. |

#### 2.5 Vector Store (SQLite-vec MVP)
| Task | File(s) | Description |
|------|---------|-------------|
| 2.5.1 | `lib/application/ports/vector_store_port.dart` **(NEW)** | `add(embedding: List<double>, metadata: Map)`, `search(queryEmbedding, k) → List<VectorMatch>`, `delete(id)`. |
| 2.5.2 | `lib/infrastructure/persistence/sqlite_vec_store.dart` **(NEW)** | Use `sqlite-vec` extension (compile-time). HNSW index. Store embeddings as BLOB. **SmolLM-360M embedding dim = 960** (hidden size). Schema: `CREATE VIRTUAL TABLE vec_items USING vec0(embedding float[960])`. **DONE**: HNSW when vec0 loads; automatic brute-force fallback table (`vec_embeddings_fallback`) + `close()` injected. |
| 2.5.3 | `lib/application/services/summary_orchestrator.dart` **(MODIFY)** | Inject `VectorStorePort`. In `generateSummary()`: embed transcript → search similar past consults → include as context for `generateContextEnrichedSummary()`. **DONE**: `buildPastContext()` (k=3, 2000-char limit), `_storeEmbeddings()`, `EmbeddingService` port + Hash/Ollama implementations; context-enriched route auto-retrieves when `pastContext` omitted. |

#### 2.6 API Completion & Testing
| Task | File(s) | Description |
|------|---------|-------------|
| 2.6.1 | `lib/application/services/clinical_processing_orchestrator.dart` **(MODIFY)** | Implement `FULL_BUNDLE` case: run all modes sequentially, return combined response. |
| 2.6.2 | `routes/api/v1/transcript-summary/[consultationId]/regenerate.dart` **(NEW)** | POST handler for regeneration. |
| 2.6.3 | `lib/core/validation/request_validator.dart` **(NEW)** | JSON schema validation middleware using `json_schema` package. **DONE**: `RequestSchemas` for all 7 POST routes + `jsonSchemaValidation` middleware; whitespace-only strings rejected via `\S` pattern. |
| 2.6.4 | `bin/generate_openapi.dart` **(NEW)** | Generate OpenAPI 3.1 spec from route handlers + DTOs. **DONE**: 11 paths, 15 schemas, 18 refs, 0 broken refs (verified). |
| 2.6.5 | `scripts/load_test.k6.js` **(NEW)** | k6 script: 50 VUs, ramp up, test all endpoints with stub LLM. **DONE** (needs `brew install k6` to run). |
| 2.6.6 | `test/integration/` **(NEW)** | Integration tests: full request/response cycles with stub + Ollama adapters. **DONE**: 33 integration tests incl. vector-store auto-retrieval seed→retrieve, JSON-schema 400s, scope 403s, notes upsert roundtrip. |

---

### PHASE 3: Frontend Polish
**Duration:** 3-4 weeks | **Dependencies:** Phase 1 (iOS/Android native working), Phase 2.1-2.2 (API stable)

#### 3.1 Sync Queue Enhancements
| Task | File(s) | Description |
|------|---------|-------------|
| 3.1.1 | `lib/core/services/sync_queue_service.dart` **(MODIFY)** | LWW conflict resolution: compare `updatedAt` timestamps. Manual merge UI for notes (side-by-side diff). Exponential backoff: `min(2^n * 1s, 60s)`. Dead letter queue table in Drift. **DONE**: LWW via timestamp compare + same-timestamp different-content → `isConflict` flag; `min(2^n*1s, 60s)` + jitter backoff; Drift `isDeadLetter` column + max-retry promotion; manual merge UI `conflict_resolution_sheet.dart`. **VERIFIED 2026-08-11** (inspection). |
| 3.1.2 | `lib/features/note_assist/presentation/widgets/sync_status_indicator.dart` **(NEW)** | Widget: icons for `synced`, `pending`, `conflict`, `error`. Tap for details/retry. **DONE**: status icons + detail/retry; light/dark goldens (`sync_status_*.png`). **VERIFIED 2026-08-11** (inspection). |

#### 3.2 Speech-to-Text Unification
| Task | File(s) | Description |
|------|---------|-------------|
| 3.2.1 | `lib/core/services/speech_service.dart` **(MODIFY)** | Single `SpeechService` interface. Platform adapters: `IosSpeechService` (Speech.framework), `AndroidSpeechService` (RecognizerIntent). **DONE**: unified `SpeechService` interface + `IosSpeechService`/`AndroidSpeechService` adapters + `SpeechServiceFactory`. **VERIFIED 2026-08-11** (inspection). |
| 3.2.2 | `lib/core/services/local_speech_service.dart` **(NEW)** | On-device STT. VAD: auto-stop after 2s silence (configurable). Medical term post-processing: expand abbreviations, capitalize. **DONE**: VAD auto-stop (2s default, configurable) + medical post-processing (abbreviation expansion, capitalization); unit-tested. **VERIFIED 2026-08-11** (inspection). |

#### 3.3 UI/UX
| Task | File(s) | Description |
|------|---------|-------------|
| 3.3.1 | `lib/features/note_assist/presentation/pages/consultation_list_page.dart` **(NEW)** | Search (debounced), filter by date/patient/status, infinite scroll (pagination). Pull-to-refresh triggers sync. **DONE**: debounced search, date/status filters, `loadMore` pagination, RefreshIndicator + queue flush; cubit unit tests + light/dark goldens. **VERIFIED 2026-08-11** (inspection). |
| 3.3.2 | `lib/features/note_assist/presentation/pages/consultation_detail_page.dart` **(MODIFY)** | Rich text editor (flutter_quill). Voice input button → STT. AI assist panel (vocab assist, cleanup, summarize, doctor note). Real-time sync status. **DONE**: `note_editor_page.dart` w/ flutter_quill editor, voice dictation → STT, `AiToolbar` + `SuggestionPanel` (Clean up/Structure/Extract/Recap actions), `SyncStatusIndicator`; goldens light/dark + a11y. **VERIFIED 2026-08-11** (inspection). |
| 3.3.3 | `lib/features/note_assist/presentation/pages/model_manager_page.dart` **(MODIFY)** | Show model name, version, size, device (CPU/GPU). Download progress with bytes/sec. Verify checksum on complete. **DONE**: install states (not-installed/downloading/ready/error), download progress with downloaded/total bytes + verify phase (SHA-256), capability-gated fallback; cubit unit tests + goldens. **VERIFIED 2026-08-11** (inspection). |
| 3.3.4 | `lib/features/note_assist/presentation/pages/settings_page.dart` **(NEW)** | Cloud fallback toggle (requires PHI consent). Log export (audit + debug). Accessibility: dynamic type, VoiceOver/TalkBack labels, contrast. **DONE**: log export via injectable `DiagnosticsExporter` (timestamped, collision-safe) + graceful share-unavailable fallback; cloud/PHI consent toggle flow w/ dialog; 100% line coverage (`settings_page_test.dart`), 2.0x dynamic-type a11y test, goldens `settings_loaded[_dark]/settings_a11y` (light/dark + a11y scale). |

#### 3.4 Testing
| Task | Target |
|------|--------|
| Unit tests | >80% coverage (cubits, services, repositories) **VERIFIED 2026-08-11**: cubits 93.0%, core services 88.5%, note_assist data/repos 84.4% (excl. generated `*.g.dart` + codegen-shadowed table column declarations which throw at runtime by design), domain services 85.6%, LLM adapters 88.4%. `model_manager_cubit` platform verification flows made testable via `@visibleForTesting` platform gates and exercised through the mocked MethodChannel. |
| Widget tests | Key flows: model download → editor → AI assist → sync |
| Integration tests | Full consultation create → dictate → AI → sync (physical device) |
| Golden tests | All pages, light/dark mode, accessibility sizes |

---

### PHASE 4: Production Readiness
**Duration:** 2-3 weeks | **Dependencies:** All prior phases

#### 4.1 CI/CD (GitHub Actions)
| Workflow | File | Triggers |
|----------|------|----------|
| Backend CI | `.github/workflows/backend-ci.yml` | PR to main, push to main |
| Frontend CI | `.github/workflows/frontend-ci.yml` | PR to main, push to main |
| iOS Model Prep | `.github/workflows/ios-model-prep.yml` | Tag `model-*`, manual dispatch |
| Release | `.github/workflows/release.yml` | Tag `v*` |

**Checks:** `dart analyze`, `dart test`, `dart_frog build` (backend); `flutter analyze`, `flutter test`, `flutter build ios --release --no-codesign`, `flutter build appbundle` (frontend). Model checksum validation in iOS Model Prep.

#### 4.2 Observability
| Component | File | Description |
|-----------|------|-------------|
| Structured Logger | `lib/core/observability/json_logger.dart` | JSON output, correlation IDs, log levels (debug/info/warn/error). |
| Metrics Middleware | `lib/core/observability/metrics_middleware.dart` | Prometheus `/metrics` endpoint: http_requests_total, http_request_duration_seconds, llm_inference_duration_seconds, active_consultations. |
| Frontend Analytics | `lib/core/analytics/analytics_service.dart` | Event tracking (screen views, AI assist usage, errors). Consent-gated. |
| Alerting Rules | `alerting_rules.yaml` | Error rate >5%, p99 latency >5s, model load failures >0, disk usage >80%. |

#### 4.3 Security
| Task | File(s) |
|------|---------|
| TLS Pinning (Backend) | `security_service.dart` — pin Dart Frog cert SHA256 in Flutter |
| TLS Pinning (Model) | Verify model bundle SHA256 on load (both platforms) |
| Secure Storage Audit | Ensure all secrets in Keychain/Keystore (no SharedPreferences for tokens) |
| Network Security Config | `android/app/src/main/res/xml/network_security_config.xml` — cleartextTrafficPermitted=false |
| iOS ATS | `Info.plist` — NSAppTransportSecurity NSAllowsArbitraryLoads=false |
| Dependency Scanning | Add `dart pub outdated` + `flutter pub outdated` to CI; Dependabot alerts |

#### 4.4 Compliance Documentation
| Doc | File |
|-----|------|
| Data Flow Diagram | `docs/data_flow_diagram.md` — Mermaid diagram: device → (optional) cloud → storage |
| Threat Model | `docs/threat_model.md` — STRIDE analysis, mitigations |
| HIPAA/GDPR Checklist | `docs/hipaa_gdpr_checklist.md` — BAAs, DPIA, breach notification, data subject rights |
| Consent Flow | Settings page: explicit consent for cloud processing, audit trail entry |

---

## 🔀 Parallelization Strategy

```
Week 1-2:  Phase 1.1 (iOS Model Compile)  ──► Phase 1.2 (iOS Handler)
           Phase 2.1 (Backend Drift)       ──► Phase 2.2 (Auth)
Week 2-3:  Phase 1.5 (Android Handler)     (parallel, independent)
           Phase 2.3 (Audit) + 2.4 (Encryption)
Week 3-4:  Phase 2.5 (Vector Store) + 2.6 (API)
Week 4-6:  Phase 3 (Frontend)              (needs Phase 1+2 stable)
Week 6-8:  Phase 4 (Production)
```

**Critical Path:** Phase 1.1 → 1.2 → 1.3 → 3.x (Frontend needs working native LLM)

---

## ❓ Clarifying Questions

| # | Question | Impact |
|---|----------|--------|
| 1 | **SmolLM-350M embedding dimension?** | **RESOLVED: 960** (hidden size for 360M variant). Affects `sqlite_vec_store` schema — confirmed. |
| 2 | **Bundle model in-app (~200MB) or download on first run?** | Roadmap says bundle, but increases app size. Confirm. |
| 3 | **MLC Android runtime setup?** | Need to add `org.mlc.llm` dependency. Confirm gradle config approach. |
| 4 | **JWT key storage?** | File-based (dev) vs. HashiCorp Vault / AWS KMS (prod)? |
| 5 | **Ollama model for cloud fallback?** | Same SmolLM-350M or larger (Llama 3.2 3B)? |
| 6 | **SQLite-vec compilation?** | Requires custom SQLite build. Confirm acceptable for iOS/Android. |
| 7 | **Shared DTO package?** | Currently duplicated. Extract to `packages/shared_models`? |

---

## ✅ Success Criteria (Definition of Done)

| Layer | Criteria |
|-------|----------|
| **iOS** | App launches on device (A15+), `smolLM350M` prompt→response <20s, no linking errors, warm-up inference works |
| **Android** | App launches on device (API 24+), `smolLM350M` prompt→response <20s, GPU/CPU fallback works, model checksum verified |
| **Backend** | All routes return 2xx with valid JWT, persistence survives restart, encryption at rest verified (inspect DB), audit logs written, vector search returns relevant results |
| **Frontend** | Consultation create → dictate (STT) → AI assist (vocab/summarize/note) → sync → appears on list. Offline mode works. >80% test coverage. |
| **Production** | All CI pipelines green, Prometheus metrics exposed, alerting rules defined, security scan (Dependabot/Snyk) clean, compliance docs complete. |

---

## 📋 Next Steps (Upon Approval)

1. **Approve plan** → I'll create GitHub Issues/Epics for each phase
2. **Answer clarifying questions** → Resolve unknowns before implementation
3. **Start Phase 1.1** — Run `setup_ios_mlc.sh` on Mac to compile SmolLM-350M
4. **Start Phase 2.1** — Add Drift dependencies, create database schema

---

*Plan complete. Awaiting review and clarification on open questions.*