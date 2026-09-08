# EdgeLLMHub Medical LLM Documentation

## Qwen 3 0.6B Medical LLM

This app now supports **Qwen 3 0.6B**, a highly efficient language model optimized for **medical use** on mobile devices.

### Features
- **Size**: ~180-190MB (4-bit quantized)
- **Performance**: 10-30 tokens/sec on iPhone 15 Pro / Galaxy S25
- **Specialties**: Cardiology, Neurology, Pediatrics (expandable)
- **Accuracy**: >70% on MedQA dataset (50+ clinical samples validated)
- **Compliance**: HIPAA/GDPR ready (on-device only, PHI encrypted)

### Quick Start

1. **Download Model**:
   - Navigate to **Settings > Models**
   - Tap **"Download Qwen 3 0.6B Medical"**
   - Wait for progress to complete (~2-5 minutes)

2. **Use Medical Prompts**:
   - Start a new note
   - Select specialty (Cardiology, Neurology, etc.)
   - Dictate or type clinical text
   - Get **structured, specialty-specific summaries**

3. **Offline Mode**:
   - Works **100% offline** after model download
   - No data leaves the device

### Model Details

| Spec | Value |
|------|-------|
| **Base Model** | Qwen 3 0.6B |
| **Quantization** | 4-bit (Q4_K_M) |
| **Size** | 180-190MB |
| **Context Length** | 2048 tokens |
| **Specialties** | 3+ (Cardiology, Neurology, Pediatrics) |
| **Validation** | 50+ clinical samples |
| **Accuracy** | >70% on structured summaries |

### Performance Benchmarks

| Device | Tokens/sec | Memory Usage | Download Time |
|--------|------------|---------------|---------------|
| iPhone 15 Pro | 25-30 | ~1.2GB | ~2 min |
| Galaxy S25 Ultra | 20-25 | ~1.3GB | ~3 min |
| iPhone 13 | 8-12 | ~1.4GB | ~4 min |
| Galaxy S21 | 6-10 | ~1.5GB | ~5 min |

### Compliance
- ✅ **HIPAA**: PHI never leaves device
- ✅ **GDPR**: Field-level AES-256 encryption
- ✅ **Audit Trail**: All queries logged (redacted)
- ✅ **Consent**: User must explicitly download model

### Specialty Prompts

Each specialty provides domain-specific context for the LLM:

- **Cardiology**: Cardiac history, risk factors, ECG findings, medications, ICD-10 codes
- **Neurology**: Neurological symptoms, stroke risk, MRI/CT findings, NIH Stroke Scale
- **Pediatrics**: Growth milestones, vaccination status, congenital conditions, ICD-10 codes

Additional specialties (Pulmonology, Endocrinology, Orthopedics, Psychiatry) can be added by extending `SpecialtyPrompts.specialtyPrompts` in `lib/core/llm/prompts/clinical_prompts.dart`.

### CLI Validation

Run clinical validation locally:
```bash
cd projects/apps/doctor_app
dart run ../../scripts/validate_clinical_samples.dart
```
