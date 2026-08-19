# Security Architecture

A complete account of EdgeLLMHub's security posture: what's protected well today, what isn't protected at all, and the priority order for closing the gap. This document does not soften findings — a security document that hides its own weaknesses is worse than no security document.

---

## Table of Contents

- [Threat Model](#threat-model)
- [Assets](#assets)
- [Attack Surface](#attack-surface)
- [PHI Handling](#phi-handling)
- [Compliance](#compliance)
- [Privacy-First Design](#privacy-first-design)
- [The Compliance Gate](#the-compliance-gate)
- [Offline Security](#offline-security)
- [Authentication Roadmap](#authentication-roadmap)
- [Authorization Roadmap](#authorization-roadmap)
- [Encryption](#encryption)
- [Prompt Injection](#prompt-injection)
- [SQLCipher](#sqlcipher)
- [Certificate Pinning](#certificate-pinning)
- [Future Zero Trust](#future-zero-trust)
- [OWASP Alignment](#owasp-alignment)
- [Risk Assessment](#risk-assessment)
- [Security Roadmap](#security-roadmap)

---

## Threat Model

Building the threat model starts from what's actually being protected and who could realistically want it:

- **Asset**: patient consultation transcripts, structured clinical summaries, doctor notes — all PHI.
- **Adversary classes**: (1) an unauthenticated network attacker who discovers the backend's address and enumerates `consultationId` values; (2) a party with physical access to a lost/stolen device; (3) a malicious or compromised input source attempting prompt injection through transcript text; (4) a curious insider with backend access exploiting the total absence of access control.
- **Trust boundary**: the mobile device is currently the strongest-protected boundary in the system (on-device inference means PHI often never crosses it). The backend is, by contrast, currently **the weakest boundary in the entire platform** — see [Attack Surface](#attack-surface).

## Assets

| Asset | Where it lives | Current protection |
|---|---|---|
| Consultation transcripts | Drift (mobile), in-memory (backend) | None at rest (mobile); none at rest, none in transit-authenticated (backend) |
| Structured clinical summaries | Drift (mobile), in-memory (backend) | Same as above |
| LLM prompts/responses | Transient, in adapter calls | Low-temperature generation reduces hallucination risk; no output-side verification |
| Doctor identity / session | Not currently modeled at all on the backend | **No authentication exists** |

## Attack Surface

The backend (`clinical-intelligence-dart`) exposes REST routes with **no authentication or authorization whatsoever**. Any client that can reach the server can read any doctor's data by guessing or enumerating a `consultationId` — a direct instance of **Broken Object Level Authorization (BOLA)**, OWASP's #1-ranked API vulnerability class. This is the single highest-severity finding across every architecture review in this repository's history, and it is unresolved as of the current documentation.

Secondary attack surface: the backend has no dedicated prompt-injection filtering distinct from what the mobile app applies before a request is sent (see [Prompt Injection](#prompt-injection)) — meaning a client that bypasses the mobile app entirely (trivial, given no auth) also bypasses that validation layer.

## PHI Handling

The platform's founding design principle is that PHI defaults to on-device processing via the [hybrid LLM adapter](architecture.md#llm-flow), with cloud processing as an explicit, gated fallback rather than the default path. This principle is sound. Its enforcement mechanism — the compliance gate — currently has a real gap; see [The Compliance Gate](#the-compliance-gate).

## Compliance

No formal compliance certification (HIPAA, SOC 2, or equivalent) is documented as achieved or in progress. The architecture's design intent is compatible with HIPAA-style requirements (data minimization, on-device-by-default processing, explicit consent for cloud transmission), but intent is not certification, and the current authentication gap alone would fail most compliance audits outright.

## Privacy-First Design

- On-device inference by default (MLC on iOS, Gemma on Android) — PHI stays local unless all native tiers fail.
- Explicit `cloudLlmEnabled` gate before any cloud fallback is attempted.
- Structured summaries and clinical notes are generated with conservative, low-temperature prompts (0.1) constrained against invention.
- Speech-to-text happens exclusively on the mobile device — audio itself is never sent to the backend.

## The Compliance Gate

`cloudLlmEnabled` is the single flag that determines whether the `HybridLlmAdapter` is permitted to fall back to the cloud tier at all. **Two pieces of source material disagree about its default value**: one architectural deep-dive states the default is `false` (safe); the platform's own prioritized critique identifies the actual default as `isDebug` — meaning it can be silently `true` in any debug build, with no error, log, or alert when that happens. This documentation treats the **`isDebug` default as the current, authoritative state**, because it is identified as an active P0 finding in the platform's own prioritized issue list, not as a historical or superseded description.

**Why this matters disproportionately for a one-line bug**: a build-config mistake here doesn't fail loudly — it silently sends PHI to the cloud tier with no observable signal to the doctor or the team. The fix is a fail-closed constant with no debug fallback — genuinely small effort, genuinely large blast radius if left unfixed.

## Offline Security

Offline operation is a deliberate availability-over-consistency choice (see [`architecture.md`](architecture.md#design-decisions)), but it currently has a security-relevant side effect: data written while offline sits unencrypted in Drift for however long the device stays offline, with no compensating control beyond normal OS-level app sandboxing. A lost or stolen phone in this state exposes every locally cached transcript in plaintext. See [Encryption](#encryption).

## Authentication Roadmap

Today: **none**, on any backend route. The documented fix, staged as three layers rather than one:

1. **Middleware-level token verification** — wire OIDC token verification into the backend's request middleware, rejecting unauthenticated requests before they reach any orchestrator.
2. **Object-level authorization inside the orchestrator** — verify the authenticated identity is actually permitted to access the specific `consultationId` being requested, not just that *a* valid token was presented.
3. **Push authorization down into the query itself**, once a real database exists — scope every repository query by authenticated `doctor_id` at the data-access layer, so authorization isn't solely an application-logic concern that a future refactor could accidentally bypass.

Each layer closes a gap the one above it can't: middleware-only auth stops anonymous access but not a valid doctor reading *another* doctor's data; orchestrator-level checks stop that but rely on every code path remembering to check; query-level scoping makes the unauthorized read structurally impossible regardless of what the application layer does.

## Authorization Roadmap

See above — authorization is treated as inseparable from authentication in this system's roadmap, specifically because BOLA (unauthorized *access to a specific object*, not just unauthenticated *access to the API*) is the named top risk, not generic unauthenticated access.

## Encryption

| Layer | Current state | Planned |
|---|---|---|
| In transit | Not confirmed as enforced (no certificate pinning implemented — see below) | HTTPS with certificate pinning |
| At rest — mobile (Drift/SQLite) | **None** | SQLCipher or platform Keystore/Keychain-wrapped keys |
| At rest — backend | Not applicable (in-memory only; a future Postgres migration should encrypt at rest) | To be defined alongside the Postgres migration |
| Secrets/config | Not detailed in available source material beyond noting it as an open area | Documented secrets management (Part A.6 of the platform's security review) is referenced but not detailed here |

## Prompt Injection

Current defense is **weaker than it looks**: the backend calls Ollama via `/api/generate`, which has no structural separation between trusted system instructions and untrusted transcript text — everything is one flat prompt string. There is no real trust boundary baked into the request format itself. The mobile app's `InputValidator` does apply length limits, charset sanitization, and pattern-based injection detection — with specific care taken to avoid false-positives on legitimate clinical language (a real tension: clinical text often contains phrasing that naively resembles instruction-like language) — but this runs client-side, before a request is sent, and does not protect the backend from a client that bypasses the mobile app entirely.

The documented fix: switch to Ollama's roles-based `/api/chat` endpoint (giving system and user content actual structural separation) and add output-side plausibility checks — verifying the model's output is consistent with what a clinical summary should contain, not just trusting whatever comes back.

## SQLCipher

Recommended, not yet implemented, for local Drift/SQLite encryption at rest. The alternative considered alongside it is platform-native key wrapping (iOS Keychain / Android Keystore) to protect a database encryption key rather than encrypting the database file directly — both close the same gap (a lost or stolen phone exposing plaintext transcripts); the tradeoff between them is not detailed further in available source material.

## Certificate Pinning

Identified as a recommended control for all backend HTTP traffic, alongside general HTTPS enforcement. No confirmation exists in available source material that this is currently implemented in `doctor_app`'s Dio configuration.

## Future Zero Trust

No zero-trust architecture is documented as implemented or actively planned in detail. Given the authentication/authorization roadmap above — moving from no auth, to token verification, to object-level checks, to query-level scoping — the natural next step in that direction is treating every internal call (not just external client requests) as requiring verification, including calls between the backend and Ollama, and eventually between this backend and any future Postgres instance. This is a reasonable extrapolation of the stated roadmap, not a committed architectural decision — flagged here as **forward-looking**, not current or planned in the source material.

## OWASP Alignment

The platform's single largest documented risk (missing authentication/authorization, enabling BOLA) maps directly to **OWASP API Security Top 10, #1**. No broader OWASP Top 10 (web) or ASVS-level assessment is documented as having been performed across the rest of the attack surface — this document reflects the specific, named findings from the platform's own reviews, not an independent audit against the full OWASP framework.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Unauthenticated access to any doctor's data (BOLA) | Certain today | Critical | Auth/authz roadmap above |
| Compliance gate defaults unsafe in debug builds | Medium (build-config dependent) | High | Fail-closed constant, no debug fallback |
| Lost/stolen device exposes plaintext local data | Low–Medium | High | SQLCipher or Keychain/Keystore-wrapped encryption |
| Prompt injection via transcript text | Medium | Medium–High (clinical safety) | `/api/chat` migration, output-side plausibility checks |
| In-memory backend data loss on restart | Certain on any deploy/crash | High (data loss, not just confidentiality) | Postgres migration |
| No rate limiting — one client degrades service for all | Medium (requires concurrent load) | Medium | Per-doctor request quotas |

## Security Roadmap

**Now (blocks real users):**
1. Fail-closed `cloudLlmEnabled` — remove the `isDebug` fallback entirely.
2. Authentication + object-level authorization on every backend route.
3. Migrate off in-memory backend persistence (also a data-loss issue, not purely a security one).
4. Persist the mobile sync queue durably.

**Next (blocks meaningful growth):**
5. Switch Ollama integration to `/api/chat`; strengthen prompt-injection defenses with output-side checks.
6. Add local at-rest encryption (SQLCipher or Keychain/Keystore-backed keys).
7. Add rate limiting and per-doctor quotas.

**Later:**
8. Formal compliance assessment (HIPAA or equivalent) once the above are closed.
9. Certificate pinning verification and enforcement audit.
10. Evaluate zero-trust patterns for internal service-to-service calls as the system grows beyond a single backend instance.

