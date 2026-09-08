# Local LLM Engine — Production Readiness Implementation Plan

**Generated:** 2026-08-12  
**Based on:** Current codebase audit  
**Scope:** iOS (MLC Swift) + Android (MLC Android) on-device inference

---

## Executive Summary

The codebase has **well-architected Dart-side infrastructure** for local LLM:
- ✅ `HybridLlmAdapter` — 3-tier fallback (native → cloud → stub)
- ✅ `IosNativeLlmAdapter` / `SmolLLMAdapter` — Platform channels with streaming
- ✅ `ModelManagerCubit` — Download, verify, warm-up, verify inference
- ✅ `DeviceCapabilityService` — Simulator detection, execution mode routing

**The Swift/Kotlin native handlers are implemented but uncompilable** — they require:
1. MLCSwift Swift Package added to Xcode project
2. MLC Android AAR dependency in Gradle
3. Model compilation via `setup_ios_mlc.sh` (requires Mac + HF token)
4. Model download URL + checksum for production

**Bottom line:** **Local LLM will NOT run in production today** — the native code is gated behind `#if canImport(MLCSwift)` / `org.mlc.llm` imports that don't resolve.

---

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        HybridLlmAdapter                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Native    │  │   Cloud     │  │    Stub     │             │
│  │  (Tier 1)   │──▶│  (Tier 2)   │──▶│  (Tier 3)   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│       │               │               │                          │
│       ▼               ▼               ▼                          │
│  IosNativeLlmAdapter  CloudLlmAdapter  StubLlmAdapter           │
│  SmolLLMAdapter                                              │
│       │                                                          │
│       ▼                                                          │
│  MethodChannel/EventChannel                                      │
│       │                                                          │
│  ┌─────────────┐          ┌─────────────┐                       │
│  │   iOS       │          │  Android    │                       │
│  │ MLCLLMHandler│         │ MLCLLMHandler│                       │
│  │ (MLCSwift)  │         │ (MLC Android)│                       │
│  └─────────────┘          └─────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: iOS — Make MLCSwift Compile & Run (Critical Path)

### 1.1 Prerequisites Verification (Mac Required)

| Tool | Minimum Version | Check Command |
|------|-----------------|---------------|
| macOS | 13+ (Ventura) | `sw_vers` |
| Xcode | 15+ | `xcodebuild -version` |
| cmake | 3.24+ | `cmake --version` |
| git-lfs | 3.0+ | `git lfs version` |
| rustc | 1.70+ | `rustc --version` |
| python3 | 3.11+ | `python3 --version` |
| mlc_llm | 0.20.0 (CPU wheels) | See setup script |

**Run:** `./ios/scripts/setup_ios_mlc.sh` — this validates ALL prerequisites.

### 1.2 Add MLCSwift to Xcode Project

1. Open `ios/Runner.xcworkspace` in Xcode
2. File → Add Package Dependencies → Add Local
3. Select: `ios/mlc-llm/MLCSwift`
4. **Critical:** Add `SmolLM-350M-Instruct-q4f16_1-MLC` to **Copy Bundle Resources** build phase

### 1.3 Model Compilation

```bash
# Requires HF_TOKEN with read access to HuggingFaceTB/SmolLM-350M-Instruct
export HF_TOKEN=hf_xxxxxxxxxxxxxxxx
cd projects/apps/doctor_app
./ios/scripts/prepare_model.sh
# Or with custom model:
# ./ios/scripts/prepare_model.sh --model HF://HuggingFaceTB/SmolLM-350M-Instruct --quant q4f16_1
```

This produces:
- `ios/mlc-llm/SmolLM-350M-Instruct-q4f16_1-MLC/` — model artifacts
- `ios/Runner/checksums.sha256` — bundle checksum for runtime verification

### 1.4 Build & Test on Physical Device

| Requirement | Spec |
|-------------|------|
| Device | iPhone 13+ (A15 Bionic or newer) |
| RAM | 6 GB minimum (8 GB recommended) |
| iOS | 17+ |
| Build | `flutter run --release` on physical device |

**Simulator:** Will NOT work — no Metal GPU, insufficient RAM allocation. `DeviceCapabilityService` correctly detects this and routes to cloud/stub.

### 1.5 Verify End-to-End

1. App launches → `ModelManagerCubit.checkModelExists()`
2. Detects physical device → calls `MLCLLMHandler.getModelInfo()`
3. Finds bundled model → `initialize()` → `warmUp()` → `generate("Hello")`
4. Emits `ModelManagerReady(executionMode: 'local')`
5. UI shows "Local LLM Ready"

---

## Phase 2: Android — MLC Android Runtime

### 2.1 Add MLC Android Dependency

**File:** `android/app/build.gradle.kts` (needs creation/update)

```kotlin
dependencies {
    // MLC Android runtime (check latest version at https://github.com/mlc-ai/mlc-llm)
    implementation("org.mlc.llm:mlc-android:0.20.0")  // Update version
}
```

### 2.2 Model Distribution Strategy

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **Bundle in APK** | Offline-first, no download | +200 MB app size | ✅ For offline-first |
| **Download on first run** | Smaller initial install | Needs network, signed URL | Phase 2+ |
| **Dynamic delivery (Play Asset Delivery)** | On-demand, Google-hosted | Complex setup | Future |

**Current code expects:** Download → verify SHA-256 → extract to `filesDir/SmolLM-350M-Instruct-q4f16_1-MLC/`

### 2.3 Production Model Hosting

1. Run `setup_ios_mlc.sh` to generate Android-compatible artifacts (same model)
2. Upload `SmolLM-350M-Instruct-q4f16_1-MLC.zip` to GCP bucket / CDN
3. Generate signed URL with expiry
4. Configure via `--dart-define`:
   ```bash
   flutter build apk --release \
     --dart-define=MODEL_DOWNLOAD_URL=https://storage.googleapis.com/.../smolLM-350M-Instruct-q4f16_1-MLC.zip \
     --dart-define=MODEL_CHECKSUM_SHA256=<sha256-of-zip>
   ```

---

## Phase 3: Production Hardening (Both Platforms)

### 3.1 Model Integrity & Security

| Check | Implementation | Status |
|-------|----------------|--------|
| SHA-256 verification at download | `ModelManagerCubit._verifyChecksum()` | ✅ Done |
| Constant-time comparison | `_constantTimeEquals()` | ✅ Done |
| Bundle checksum at runtime | `MLCLLMHandler.bundleChecksum()` / `computeChecksum()` | ✅ Done |
| Corrupt file auto-delete | On mismatch | ✅ Done |
| Code signing (iOS) | Xcode handles | ⚠️ Verify |
| macOS 26 ad-hoc re-sign | `setup_ios_mlc.sh` step | ✅ Done |

### 3.2 Performance Optimization

| Optimization | iOS | Android | Priority |
|--------------|-----|---------|----------|
| Warm-up on app start | `warmUp()` in `checkModelExists()` | Same | High |
| Metal GPU (iOS) / Vulkan (Android) | Auto-detected | Auto-detected | High |
| Context window tuning | 2048 tokens (configurable) | Same | Medium |
| Prefill chunk size | 512 (configurable) | Same | Medium |
| Quantization | q4f16_1 (4-bit) | Same | ✅ Done |

### 3.3 Memory Management

| Concern | Mitigation |
|---------|------------|
| Model ~350 MB RAM | Only load on physical devices with 6 GB+ |
| Engine unload on background | `deinit` / `onDestroy` → `engine.unload()` |
| Generation cancellation | `cancelActiveGeneration()` / `generationJob?.cancel()` |
| Streaming backpressure | EventChannel buffers tokens |

---

## Phase 4: Cloud Fallback & Compliance

### 4.1 Compliance Gate (PHI Protection)

```dart
// In LlmPortFactory.create()
final cloudEnabled = EnvironmentConfig.cloudLlmEnabled;  // --dart-define=CLOUD_LLM_ENABLED=true
```

| Environment | `cloudLlmEnabled` | Behavior |
|-------------|-------------------|----------|
| Dev (debug) | `true` | Cloud allowed for testing |
| Staging | `false` (explicit) | PHI never leaves device |
| Prod | `false` (explicit) | PHI never leaves device |

**To enable cloud in prod:** Requires explicit compliance approval + BAAs + `--dart-define=CLOUD_LLM_ENABLED=true`

### 4.2 Cloud Adapter (`CloudLlmAdapter`)

- Calls Dart Frog backend (`clinical-intelligence-dart`)
- Requires valid JWT with `clinical:write` scope
- Backend uses OpenAI / Ollama / Vertex AI
- **Audit logging** on every cloud request (PHI redaction)

---

## Phase 5: CI/CD Automation

### 5.1 iOS Model Preparation (GitHub Actions)

```yaml
# .github/workflows/ios-model-prep.yml
name: iOS Model Preparation
on:
  workflow_dispatch:
  push:
    tags: ['v*']
jobs:
  prepare-model:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup prerequisites
        run: |
          # Install cmake, git-lfs, rust, python
          # Create venv, install mlc_llm from MLC wheels
      - name: Compile model
        env:
          HF_TOKEN: ${{ secrets.HF_TOKEN }}
        run: ./projects/apps/doctor_app/ios/scripts/prepare_model.sh
      - name: Upload model artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ios-mlc-model
          path: projects/apps/doctor_app/ios/mlc-llm/
```

### 5.2 Android Model Artifact

Same workflow, upload zip to GCP bucket via `gsutil`.

### 5.3 Release Build

```yaml
# In release.yml
- name: Build iOS with bundled model
  run: |
    # Download model artifact from previous job
    # flutter build ios --release --no-codesign
```

---

## Configuration Reference

### Dart Defines (Build Time)

| Define | Description | Default |
|--------|-------------|---------|
| `ENV` | `dev` \| `staging` \| `prod` | `dev` |
| `API_URL` | Backend base URL | Per-env default |
| `CLOUD_LLM_ENABLED` | Allow cloud fallback | `true` in dev, `false` otherwise |
| `MODEL_DOWNLOAD_URL` | Signed model download URL | Empty |
| `MODEL_CHECKSUM_SHA256` | SHA-256 of model zip | Empty |
| `OAUTH_CLIENT_ID` | Cloud auth client ID | Empty |

### Environment-Specific Build Commands

```bash
# Development (local backend, cloud allowed)
flutter run --dart-define=ENV=dev --dart-define=API_URL=http://192.168.1.x:8080

# Staging (cloud disabled, signed model URL)
flutter build ios --release \
  --dart-define=ENV=staging \
  --dart-define=CLOUD_LLM_ENABLED=false \
  --dart-define=MODEL_DOWNLOAD_URL=https://... \
  --dart-define=MODEL_CHECKSUM_SHA256=abc123...

# Production (same as staging, different API URL)
flutter build ios --release \
  --dart-define=ENV=prod \
  --dart-define=CLOUD_LLM_ENABLED=false \
  --dart-define=MODEL_DOWNLOAD_URL=https://... \
  --dart-define=MODEL_CHECKSUM_SHA256=abc123...
```

---

## Testing Checklist

| Test | iOS | Android |
|------|-----|---------|
| Physical device inference | ✅ Required | ✅ Required |
| Simulator → cloud fallback | ✅ Auto | ✅ Auto |
| Model download + verify | ✅ Manual | ✅ Manual |
| Warm-up reduces first latency | ✅ Verify | ✅ Verify |
| Generation cancellation | ✅ Test | ✅ Test |
| Streaming tokens received | ✅ Test | ✅ Test |
| Structured summary parsing | ✅ Test | ✅ Test |
| Context-enriched summary | ✅ Test | ✅ Test |
| Low memory warning handling | ⚠️ TODO | ⚠️ TODO |
| Background/foreground engine lifecycle | ⚠️ TODO | ⚠️ TODO |

---

## Open Questions for Your Production App

| # | Question | Decision Needed |
|---|----------|-----------------|
| 1 | **Model size vs. capability** | SmolLM-350M (current) vs. Llama-3.2-3B (better quality, ~2 GB RAM) |
| 2 | **Model distribution** | Bundle in app (offline-first) vs. Download on first run |
| 3 | **Android runtime** | MLC Android (current) vs. `flutter_gemma` (Google's Gemma) |
| 4 | **Cloud provider** | Ollama (self-hosted) vs. OpenAI vs. Vertex AI vs. Azure |
| 5 | **Quantization** | q4f16_1 (current) vs. q8_0 (better quality) vs. q4_k_m |
| 6 | **Multi-model support** | Single model vs. model selector (summary vs. vocab vs. note) |
| 7 | **Telemetry** | What local LLM metrics to collect (latency, tokens/s, errors) |

---

## Quick Start for Your Team

```bash
# 1. On Mac: Verify prerequisites
cd projects/apps/doctor_app
./ios/scripts/setup_ios_mlc.sh  # Will tell you what's missing

# 2. Get HF token
export HF_TOKEN=hf_...

# 3. Compile model
./ios/scripts/prepare_model.sh

# 4. Open Xcode, add MLCSwift package, add model to Copy Bundle Resources

# 5. Build & run on physical iPhone 13+
flutter run --release --dart-define=ENV=dev

# 6. Verify: ModelManager screen shows "Local LLM Ready"
```

---

## Integration with Your Live App

Since you mentioned "the real app is similar to this UI UX and all the configurations are same":

1. **Copy these Dart files** to your live app:
   - `lib/core/llm/*.dart` (adapters, factory, parsing, prompts)
   - `lib/core/ports/llm_port.dart`
   - `lib/features/note_assist/presentation/cubit/model_manager_cubit.dart`
   - `lib/core/services/device_capability_service.dart`
   - `lib/core/config/environment.dart`
   - `lib/core/exceptions/app_exceptions.dart`

2. **Copy native handlers**:
   - `ios/Runner/MLCLLMHandler.swift` → your iOS project
   - `android/app/src/main/kotlin/.../MLCLLMHandler.kt` → your Android project
   - Register in `AppDelegate.swift` / `MainActivity.kt`

3. **Copy model prep scripts**:
   - `ios/scripts/setup_ios_mlc.sh`
   - `ios/scripts/prepare_model.sh`

4. **Configure your build** with the same `--dart-define` flags

5. **Run model prep** on your CI/CD Mac runner

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| MLCSwift version incompatibility | Medium | High | Pin version in `setup_ios_mlc.sh`; test on each Xcode update |
| Model too slow on older devices | Medium | Medium | Device capability check; fallback to cloud |
| macOS codesigning breaks load | High (macOS 26) | Critical | `setup_ios_mlc.sh` re-signs; verify on target OS |
| Android MLC AAR not on MavenCentral | Medium | High | Build from source or use GitHub Packages |
| PHI leakage via cloud fallback | Low | Critical | `CLOUD_LLM_ENABLED=false` in prod; audit logs |
| Model corruption in transit | Low | High | SHA-256 verification + constant-time compare |

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| iOS Prerequisites & Compile | 1-2 days | Mac, HF token |
| Xcode Integration & Test | 1 day | Physical iOS device |
| Android Dependency & Test | 1-2 days | Physical Android device |
| Model Hosting & Download Flow | 1 day | GCP bucket / CDN |
| CI/CD Automation | 1-2 days | GitHub Actions + Mac runner |
| Production Hardening | 1-2 days | Security review |
| **Total** | **1-2 weeks** | — |

---

## Next Steps for You

1. **Run `./ios/scripts/setup_ios_mlc.sh`** on your Mac — it will tell you exactly what's missing
2. **Decide on model distribution** (bundle vs. download) — affects app size & offline capability
3. **Provision model hosting** (GCP bucket + signed URLs) for Android download flow
4. **Run compliance review** on `CLOUD_LLM_ENABLED` default for your prod environment
5. **Copy the Dart/native files** to your live app repository
6. **Add CI workflow** for automated model prep on tag push

The infrastructure is **production-architected** — it just needs the native compilation step and model hosting to go live.