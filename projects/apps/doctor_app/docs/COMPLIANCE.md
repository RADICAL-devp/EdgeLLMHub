# Compliance: HIPAA/GDPR for EdgeLLMHub with Qwen 3 0.6B

## Model Details

| Spec | Value |
|------|-------|
| **Base Model** | Qwen 3 0.6B |
| **Quantization** | 4-bit (Q4_K_M) |
| **Size** | 180-190MB |
| **Context Length** | 2048 tokens |
| **Specialties** | 3+ (Cardiology, Neurology, Pediatrics) |
| **License** | Apache 2.0 |

## On-Device Inference Guarantees

- **PHI never leaves the device**: All inference happens on-device via MLC-LLM (Metal GPU on iOS, Vulkan on Android)
- **No cloud API calls for medical data**: `cloudLlmEnabled` defaults to `false` and must be explicitly enabled via `--dart-define=CLOUD_LLM_ENABLED=true`
- **3-tier fallback**: Native MLC → Stub (offline), no cloud tier

## PHI Handling Procedures

### Encryption
- All medical data fields encrypted with **AES-256-GCM** (field-level)
- Key derivation via **PBKDF2** (100,000 iterations)
- Encryption keys sourced from environment variables only (no hardcoded keys)

### Fields Requiring Encryption
```dart
class MedicalField {
  static const List<String> encryptedFields = [
    'patient_name',
    'patient_id',
    'doctor_notes',
    'raw_transcript',
    'structured_summary',
  ];
}
```

### PHI Redaction in Audit Logs
- All audit logs use `PhiRedactor` to redact SSN, DOB, names, addresses
- `AuditService.logMedicalQuery()` automatically redacts PHI before logging
- Audit trail maintained for all medical LLM queries

## Audit Trail Requirements

1. **All medical LLM queries are logged** with:
   - Timestamp (UTC)
   - User ID (hashed)
   - Model ID
   - Specialty
   - Query length, response length
   - Redacted query and response

2. **Audit entries are immutable** once written to the database

3. **Audit retention**: Configurable policy (default: 7 years for HIPAA)

## HIPAA/GDPR Compliance Checklist

- ✅ **PHI Encryption**: AES-256-GCM field-level encryption
- ✅ **Key Derivation**: PBKDF2 (100k iterations)
- ✅ **Audit Trail**: All medical LLM queries logged (redacted)
- ✅ **No hardcoded keys**: All keys from environment variables
- ✅ **On-device only**: PHI never leaves the device
- ✅ **User consent**: Explicit model download required
- ✅ **Data retention**: Configurable policies
- ✅ **STRIDE threat model**: Documented

## STRIDE Threat Model

| Threat | Mitigation |
|--------|-----------|
| Spoofing | JWT auth, biometric login |
| Tampering | AES-256-GCM encryption, SHA-256 checksums |
| Repudiation | Audit trail with immutable logs |
| Information Disclosure | PHI encryption, no cloud egress |
| Denial of Service | Rate limiting, circuit breakers |
| Elevation of Privilege | Role-based access, key isolation |

## GDPR-Specific Provisions

1. **Right to be forgotten**: All user data and audit logs deletable on request
2. **Data portability**: Export structured summaries in JSON format
3. **Consent management**: Explicit consent for model download and data processing
4. **Data minimization**: Only collect necessary medical data

## Compliance Documentation

- Last updated: 2026-09-08
- Model: Qwen 3 0.6B (Q4_K_M)
- Framework: EdgeLLMHub Flutter app
- Compliance standards: HIPAA, GDPR
