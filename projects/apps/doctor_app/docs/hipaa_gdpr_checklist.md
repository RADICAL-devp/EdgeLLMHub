# HIPAA + GDPR Compliance Checklist

> **Context (accurate legal framing).** The Clinical Intelligence Platform is a
> **medical-device-style tool used by clinicians**. The app vendor is generally
> **not** a HIPAA Covered Entity (CE) — CEs are providers/health plans/clearing
> houses — and is only a **Business Associate (BA)** when it creates, receives,
> maintains, or transmits **PHI on behalf of a CE**.
>
> Under the **current Q5 architecture** almost all processing is **on-device**,
> which sharply reduces PHI handling. Two things still matter:
>
> 1. **Note sync transmits PHI** (patientId, rawText, etc.) to the Dart Frog
>    backend, where it is stored AES-GCM-encrypted. If a CE deploys this
>    system, the backend hosting arrangement requires a **BAA**, and GDPR
>    (if EEA data subjects are involved) requires a **DPIA**.
> 2. **Device-only processing is not "no PHI"** — the device holds transcripts,
>    notes, and summaries, so HIPAA's Security Rule (if in scope via a BAA)
>    still applies to the app's handling of PHI on the device.

Status legend: **DONE** · **PARTIAL** (partly implemented) · **TODO** (planned, W8) ·
**N/A** (not applicable under current architecture / legal status).

---

## 1. HIPAA

### Administrative safeguards

| # | Control | Status | Justification (grounded in codebase) |
|---|---|---|---|
| A1 | Business Associate Agreement with backend host / cloud provider | **PARTIAL → TODO** | Backend sync path transmits PHI (`note_sync_repository.dart` → `/api/v1/notes/sync`). No BAA artifacts exist in the repo. Required the moment a CE uses the hosted sync. Device-only mode (cloud LLM off, sync disabled) avoids BA status for processing, but hosting still needs a BAA. |
| A2 | Risk analysis / risk management plan | **PARTIAL** | `docs/threat_model.md` (W9) documents STRIDE risk analysis. No formalized risk management / acceptance plan or recurring review process in the repo. |
| A3 | Workforce / access training (minimum necessary) | **N/A** | No workforce — single-vendor dev tool. Covered-entity staff training is the CE's obligation, not the vendor's. |
| A4 | Contingency plan (backup, disaster recovery) | **TODO** | Device data is single-copy local (no backup flow); backend has no DR/backup documentation. W8: device export + backend backup/retention policy. |

### Physical / device safeguards

| # | Control | Status | Justification |
|---|---|---|---|
| P1 | Workstation/device use policy | **PARTIAL** | On-device-only processing (Q5) inherently reduces exposure surface. No remote wipe / MDM integration for the clinician device. |
| P2 | Device disposal / re-use | **TODO** | No secure-deletion flow for local Drift DB (`doctor_notes.sqlite`) or downloaded model artifacts. W8: `PRAGMA secure_delete` / erasure API. |

### Technical safeguards

| # | Control | Status | Justification |
|---|---|---|---|
| T1 | Access control (unique user IDs, auth) | **PARTIAL** | Backend: JWT RS256 auth on all routes except token mint (`auth_middleware`, `routes/_middleware.dart`). App: token in-memory only (`auth_token_service.dart`). No roles/per-resource authz (see threat model E1); no device biometric lock. |
| T2 | Encryption in transit | **PARTIAL** | TLS on staging/prod (`https://` in `environment.dart:38-39`); **dev is http://127.0.0.1 (local only)**. No cert pinning (W8). |
| T3 | Encryption at rest | **PARTIAL** | Backend `synced_doctor_notes`: **AES-GCM (ChaCha20-Poly1305) field-level encryption** for patientId, doctorId, rawText, richTextDelta, extractedFields, patientRecap (`aes_gcm_service.dart`, `drift_doctor_note_repository.dart`). **Device local DB is plaintext SQLite** — W8: SQLCipher. Consent flags in plaintext SharedPreferences. |
| T4 | Audit logging (who/what/when) | **PARTIAL** | Backend `AuditLogger` → Drift `audit_logs` with userId, action, resource, outcome, PHI-redacted metadata (`audit_logger.dart`, `phi_redactor.dart`). **Consent changes are only in the device-local export trail (W9); not yet on the backend audit log** (W8). |
| T5 | Integrity controls | **PARTIAL** | AEAD tamper detection at rest on backend; **SHA-256 checksum-verified model downloads** (`model_manager_cubit.dart:545`) — but verification is **skipped when no expected checksum is configured**. LWW conflict detection on sync queue. |
| T6 | Transmission security (integrity + auth) | **PARTIAL** | TLS + JWT + AEAD. See T2/T1. |
| T7 | Person/entity authentication to systems | **PARTIAL** | Token mint endpoint unauthenticated by design (dev IdP); real IdP/OAuth is W8. |

### Breach notification (HIPAA 60 days)

| # | Control | Status | Justification |
|---|---|---|---|
| B1 | Breach detection & response runbook | **TODO** | No incident-response documentation in the repo. As a BA (when in scope), vendor must report breaches to the CE **no later than 60 days** after discovery. |
| B2 | Breach log / tracking | **TODO** | `audit_logs` provide raw material; no breach register or severity triage. |

### BA-specific (when in scope)

| # | Control | Status | Justification |
|---|---|---|---|
| B3 | BAA terms covering PHI use/disclosure, return/destruction | **PARTIAL → TODO** | No BAA template in repo. Device-only mode minimizes PHI to the vendor; backend hosting requires BAA. |
| B4 | Subcontractor (sub-BA) oversight | **TODO** | No documented sub-processors (hosting provider, model CDN not specified). |
| B5 | PHI use limited to minimum necessary | **PARTIAL** | Device-only LLM keeps PHI local (Q5). **Sync queue transmits full note content** — only note-level data, no raw audio, but no field-level minimization. `ClinicalPrompts.sanitize` strips control chars before any LLM call. |
| B6 | Accounting of disclosures | **PARTIAL** | Backend audit log covers system actions; device has no disclosure accounting. The W9 consent audit trail is the seed for consent-based accounting. |

---

## 2. GDPR

| # | Requirement | Status | Justification |
|---|---|---|---|
| G1 | Lawful basis for processing | **PARTIAL** | Consent UX exists (`phi_consent_granted` toggle + explicit dialog in `settings_page.dart:85-109`). No consent record of **version/scope** (what was consented to), no withdrawal journey beyond the toggle. |
| G2 | **Consent audit trail** | **PARTIAL → DONE (W9)** | Settings export now emits timestamped `consent-changed: {granted: true/false}` entries (device-local). Not yet replicated to the backend audit log (W8). |
| G3 | Data Protection Impact Assessment (DPIA) | **TODO** | No DPIA in repo. Required if EEA clinicians process EEA patient data — on-device design reduces risk, but sync + (future) cloud LLM require it. |
| G4 | Breach notification — 72 hours | **TODO** | No runbook. Must be operational before production with personal data. |
| G5 | Data subject rights — **access (Art. 15)** | **PARTIAL** | Data is on the clinician's device / backend DB. No user-facing access/export API or UI. Diagnostics export covers the device log only. |
| G6 | Data subject rights — **erasure (Art. 17)** | **TODO** | No deletion/erasure flow for local DB, sync queue, or backend `synced_doctor_notes`. W8: erasure API + device secure delete. |
| G7 | Data subject rights — **portability (Art. 20)** | **PARTIAL** | Notes are JSON/Delta-structured (portable format); no automated portability export API. |
| G8 | Data minimization | **PARTIAL** | On-device processing (Q5) is the strongest minimization control. Sync transmits full `DoctorNote` payloads; no field-level minimization; device keeps transcripts+notes indefinitely (no retention). |
| G9 | Storage limitation / retention policy | **TODO** | No retention/deletion policy anywhere (device or backend). `AuditLogger` has no retention job. W8. |
| G10 | Security of processing (Art. 32) | **PARTIAL** | See HIPAA T1–T7: TLS (prod), JWT, AES-GCM at rest (backend), checksum-verified models. Device storage and consent flags unencrypted (W8). |
| G11 | Records of processing activities (Art. 30) | **PARTIAL** | This document + `docs/threat_model.md` + `docs/data_flow_diagram.md` form the seed. No formal ROPA register. |
| G12 | Data Protection Officer / EU representative | **N/A** | Vendor org decision; not a code-level requirement. |
| G13 | International transfers (Chapter V) | **N/A → PARTIAL** | Current processing is device-local; backend hosting region is unspecified — an EEA→US transfer assessment (SCCs/adequacy) is needed if deployed with EEA data. |
| G14 | Privacy notice / transparency (Art. 13-14) | **PARTIAL** | Consent dialog explains PHI transmission (`settings_page.dart:90-95`); no formal privacy notice or data-processing description UI. |
| G15 | Contract (Art. 28) for processors | **TODO** | Equivalent to BAA for the backend hosting processor. |

---

## 3. Summary of statuses

| Status | Count | Items |
|---|---|---|
| **DONE** | 1 | G2 (consent audit trail — device-local, W9) |
| **PARTIAL** | 17 | A1, A2, P1, T1, T2, T3, T4, T5, T6, T7, B5, B6, G1, G5, G7, G8, G10, G11, G13, G14 |
| **TODO** | 10 | A4, P2, B1, B2, B3, B4, G3, G4, G6, G9, G15 |
| **N/A** | 2 | A3 (workforce training), G12 (DPO) |

> Device-only processing (Q5) does not by itself remove HIPAA/GDPR obligations —
> it shrinks the PHI surface and the number of processing steps, which lowers
> likelihood and impact ratings in `docs/threat_model.md` — but the **sync path
> still transmits PHI**, so BAAs, DPIAs, retention, erasure, and breach
> notification remain the gating items before production deployment.
