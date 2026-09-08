# Threat Model — Clinical Intelligence Platform (STRIDE)

**Scope:** current production architecture as of Workstream 9 — on-device LLM
(MLC SmolLM-350M) primary, note sync to the Dart Frog backend, cloud LLM
deferred skeleton. Grounded in the actual codebase; file references inline.

---

## 1. Assets

| Asset | Description | Location |
|---|---|---|
| **Transcripts** | Raw + cleaned dictation | Local Drift `transcripts` (`lib/features/note_assist/data/local/local_database.dart`); backend `clinical_database.dart` |
| **Notes / PHI** | `rawText`, `richTextDelta` (Quill Delta), patientId, doctorId, extracted fields, patient recap | Local Drift `doctor_notes`; sync queue payloads (`sync_queue_entries.payloadJson`); backend `synced_doctor_notes` (AES-GCM encrypted) |
| **Summaries** | Structured summary / doctor note JSON | Local Drift `transcript_summaries`; backend `summary_bundles` |
| **Auth tokens (JWT)** | Bearer token for backend | In-memory only — `AuthTokenService._token` (`lib/core/auth/auth_token_service.dart`). **Not persisted anywhere.** |
| **Consent flags** | `phi_consent_granted`, `cloud_llm_enabled` | SharedPreferences plaintext (`settings_page.dart:13-14`) |
| **Model artifacts** | `SmolLM-350M-Instruct-q4f16_1-MLC` | App documents dir (`doctor_app` package); downloaded once |
| **Audit logs** | Backend compliance trail | Backend Drift `audit_logs` (PHI-redacted) |
| **Device log export** | Diagnostics file incl. consent audit trail | App documents dir; user-initiated share |

---

## 2. STRIDE analysis

### Spoofing (identity)

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| S1 | Attacker forges backend identity / MITM on sync or token mint | notes, PHI, tokens | Med / High | TLS on staging/prod (`EnvironmentConfig.apiBaseUrl` https); JWT RS256 verification (`JwtService`); **dev base URL is plaintext http://127.0.0.1 — local only** | W8: certificate pinning; Android network security config (no `networkSecurityConfig` in `AndroidManifest.xml` today). Dev keypair hardcoded in `routes/_middleware.dart:163` — dev-only, must come from env in prod. |
| S2 | Attacker impersonates a clinician (stolen/forged JWT) | notes, PHI, audit trail | Med / High | JWT RS256; single 401-retry in `AuthInterceptor`; `authMiddleware` exempts only `api/v1/auth/token` | Token mint endpoint is **unauthenticated** by design (dev identity provider). W8: real IdP / OAuth (OAuth client ID placeholder exists in `environment.dart:67`). |
| S3 | Malicious model artifact spoofed at download | model artifacts (device) | Med / High | **SHA-256 checksum verification** of downloads (`model_manager_cubit.dart:545`); file deleted on mismatch | ⚠ Verification is **skipped when no expected checksum is configured** (`modelChecksumSha256` empty → "skipping verification"). W8: enforce checksum in release builds + signed GCP bucket URL. |

### Tampering (integrity)

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| T1 | PHI modified in transit during sync | notes, PHI | Low / High | TLS (staging/prod) + AEAD integrity on backend storage (ChaCha20-Poly1305 tag); server-side JWT auth | Dev is http — tamperable on LAN in dev only. |
| T2 | PHI tampered at rest on backend | notes, PHI | Low / High | **AES-GCM AEAD** — ciphertext+tagn tamper-detectable (`aes_gcm_service.dart`; `drift_doctor_note_repository.dart` encrypts patientId, doctorId, rawText, richTextDelta, extractedFields, patientRecap) | Key mgmt: `AES_MASTER_KEY` env in prod; dev fallback key in source. W8: KMS rotation (rotate_keys tool exists). |
| T3 | Local Drift DB tampered / modified on device | notes, transcripts | Med / High | **✖ none — device DB is plaintext SQLite** | W8: SQLCipher device encryption. App restore/bundled-copy attacks possible on rooted/jailbroken devices. |
| T4 | Sync queue payload tampered (LWW conflict) | notes | Med / Low | LWW with conflict flag (`sync_queue_service.dart:95-126`); dead-letter with error capture | Conflict resolution is user-mediated (merge UI). |
| T5 | Consent audit trail forged | consent flags, audit trail | Low / Med | Trail emitted from in-memory record at export time (W9) | Device-side log; not a security boundary. Backend audit logs are the authoritative trail (W8: sync consent events to backend audit). |

### Repudiation

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| R1 | Clinician denies actions (note creation, sync, consent) | audit logs | Med / Med | Backend `AuditLogger` — buffered Drift `audit_logs` with userId, action, resource, outcome, **PHI-redacted metadata**, timestamp (`audit_logger.dart`); `auditMiddleware` on all routes | **Consent changes are only recorded in the device-local export trail (W9); not yet synced to the backend audit log** — W8 gap for full non-repudiation of consent. Audit log itself is append-oriented but **not write-protected** (DB file). |

### Information disclosure

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| I1 | PHI leaked from device storage | notes, transcripts, summaries | Med / High | **✖ local DB unencrypted**; consent flags in plaintext SharedPreferences | W8: SQLCipher + secure storage for flags. Biggest on-device risk. |
| I2 | PHI disclosed in transit | notes, PHI | Low / High (staging/prod) | TLS (staging/prod); **http in dev** | W8: pinning. |
| I3 | PHI disclosed at rest on backend | notes, PHI | Low / High | AES-GCM field encryption (see T2) | Encrypted fields list: patientId, doctorId, rawText, richTextDelta, extractedFields, patientRecap. `noteId`/`consultationId`/timestamps remain plaintext. |
| I4 | PHI in logs / diagnostics export | transcripts, notes | Med / Med | `PhiRedactor` on backend audit metadata; app diagnostics export is **user-initiated** and explicitly includes note content (`settings_page.dart:_exportLog`) | Export is intended for support; recipient controls sharing. W8: warn banner + redaction option in export. |
| I5 | Prompt leakage via cloud LLM (if enabled) | transcripts (PHI) | Low / High | Cloud tier **disabled in production** (Q5 deferred); `HybridLlmAdapter` skips tier when `cloudEnabled == false` and on `ComplianceException`; `ClinicalPrompts.sanitize` strips control chars | ⚠ `LlmPortFactory` gates on **compile-time flag**, not the consent toggle — consent UI is not wired to the LLM gate (documented in `docs/data_flow_diagram.md` §5). |
| I6 | Stub/mock STT returns canned text on simulators | n/a | n/a | `CloudSpeechService` is dev/simulator-only mock, no real audio | Not a production path. |
| I7 | CORS wildcard on backend | notes, PHI via API | Low / Med | JWT auth on all routes except token mint | `Access-Control-Allow-Origin: *` (`_middleware.dart:152`) — dev posture; W8: restrict origins in staging/prod. |

### Denial of service

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| D1 | Backend overwhelmed (token mint / sync flood) | backend, availability | Med / Med | Circuit breaker (`circuit_breaker.dart`), retry interceptor, sync-queue exponential backoff capped at 60s + jitter, max 5 retries → dead-letter | ⚠ No rate limiting on backend. W8: rate limits on `api/v1/auth/token` + sync. |
| D2 | LLM inference hangs | app availability | Med / Low | 20s generation timeout + stream cancel (`smol_llm_adapter.dart:26,132`); native engine init timeout 60s; stub tier always available | |
| D3 | Malicious audio / pathological input exhausts STT or LLM | app availability | Med / Low | STT listen timeout 30s, VAD 2s; `sanitize` limits input; stub fallback | |

### Elevation of privilege

| # | Threat | Assets | L / I | Mitigation (existing) | Notes |
|---|---|---|---|---|---|
| E1 | Doctor accesses another clinician's notes via backend | notes, PHI | Med / High | JWT-bound `doctorId`/`clinicId` in `AuthContext`; routes scoped by consultation | ⚠ No per-resource authorization check confirmed beyond JWT presence; no roles/RBAC. W8: row-level ownership checks (`require_auth.dart`), least-privilege scopes. |
| E2 | Cloud LLM used without consent (if enabled) | PHI | Low / High | `HybridLlmAdapter.cloudEnabled` gate + consent dialog in UI | Wire gap per I5 — same W8 item. |
| E3 | Local DB tampering escalates to PHI exfiltration on rooted device | notes, PHI | Low / High | **✖ none** | W8: device encryption + root/jailbreak detection. |

---

## 3. Ratings summary (likelihood / impact)

| Category | Highest-risk items |
|---|---|
| Spoofing | S1 (TLS only in prod), S3 (checksum optional) |
| Tampering | T3 (device DB unencrypted), T1 |
| Repudiation | R1 (consent not on backend audit) |
| Disclosure | I1 (device storage), I5 (cloud gate wiring) |
| DoS | D1 (no rate limiting) |
| Elevation | E1 (no per-resource authz) |

---

## 4. W8 planned hardening (not yet implemented)

1. **flutter_secure_storage for tokens** — today the JWT lives in memory only
   (`AuthTokenService`); move to Keychain/Keystore-backed storage.
2. **Android network security config** — no `networkSecurityConfig` in the
   manifest today; define cleartext policy (block cleartext outside dev).
3. **Certificate pinning** for staging/prod API + model download URLs.
4. **Device-side SQLite encryption (SQLCipher)** for `doctor_notes.sqlite`.
5. **Consent enforcement wiring** — `LlmPortFactory` reads persisted
   `phi_consent_granted` (not the compile-time flag) so the settings toggle
   actually gates the cloud tier; consent changes appended to the backend
   audit log for non-repudiation.
6. **Backend hardening** — real IdP/OAuth, rate limiting, CORS origin
   restriction, RBAC + per-resource authorization, KMS key rotation, enforce
   `AES_MASTER_KEY`/JWT keys from env in all non-dev environments.
7. **Retention & erasure** — retention policy for `synced_doctor_notes` /
   `transcript_summaries`; data-subject erasure API (GDPR Art. 17).
