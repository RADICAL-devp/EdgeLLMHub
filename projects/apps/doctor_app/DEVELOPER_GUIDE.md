# Doctor App - Developer Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DOCTOR APP (Flutter)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                 │
│  │   UI Layer   │───▶│  Cubit/BLoC  │───▶│  Services    │                 │
│  │  (Pages,     │    │  (State      │    │  (LLM,       │                 │
│  │   Widgets)   │    │   Mgmt)      │    │   Speech,    │                 │
│  └──────────────┘    └──────────────┘    │   Sync)      │                 │
│                                            └──────┬───────┘                 │
│                                                   ▼                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                 │
│  │  Repositories│◀───│  Domain      │───▶│  Data        │                 │
│  │  (Abstract)  │    │  Models      │    │  Sources     │                 │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                 │
│                                                   ▼                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         PLATFORM CHANNELS                             │  │
│  │  ┌─────────────────────┐           ┌─────────────────────────────┐   │  │
│  │  │      iOS            │           │          Android              │   │  │
│  │  │  MLCSwift + MLCEngine│         │    MLC Android + MLCEngine    │   │  │
│  │  │  (Metal GPU)        │           │    (Vulkan GPU)             │   │  │
│  │  └─────────────────────┘           └─────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Core Principles

1. **On-Device First** — All PHI stays on device. Cloud is never used.
2. **Offline-First** — App works fully offline; sync is best-effort.
3. **Privacy by Design** — Encryption at rest, no telemetry without consent.
4. **Enterprise Grade** — Structured logging, metrics, error boundaries, tests.

---

## Module Guide

### 1. LLM System (`lib/core/llm/`)

**Key Files:**
- `llm_port.dart` — Interface for all LLM operations
- `hybrid_llm_adapter.dart` — 2-tier fallback: Native → Stub
- `ios_native_llm_adapter.dart` — iOS MethodChannel bridge
- `smol_llm_adapter.dart` — Android MethodChannel bridge
- `llm_port_factory.dart` — DI factory selecting platform adapter
- `prompts/clinical_prompts.dart` — Medical prompt templates
- `native_llm_parsing.dart` — Response parsing utilities

**Native Handlers:**
- `ios/Runner/MLCLLMHandler.swift` — iOS MLC LLM handler
- `android/app/src/main/kotlin/.../MLCLLMHandler.kt` — Android MLC LLM handler

**Model Manager:**
- `features/note_assist/presentation/cubit/model_manager_cubit.dart` — Download, verify, warm-up, version check

### 2. Speech-to-Text (`lib/core/services/speech_service.dart`)

- `local_speech_service.dart` — Native STT (speech_to_text pkg)
- `cloud_speech_service.dart` — Fallback for simulators
- `speech_service_factory.dart` — Platform-aware factory

### 3. Note Management (`features/note_assist/`)

**Domain:**
- `note_assist_service.dart` — Cleanup, structure, extract, recap
- `doctor_note.dart` — Core note model with status enum

**Data:**
- `local_database.dart` — Drift/SQLite with SQLCipher encryption
- `note_local_repository.dart` — Local persistence
- `note_remote_datasource.dart` — API sync
- `note_sync_repository.dart` — Coordinates local + remote
- `sync_queue_service.dart` — Offline queue with retry/backoff
- `conflict_resolution_service.dart` — Auto/merge/manual conflict handling

**Presentation:**
- `note_editor_cubit.dart` — Editor state, auto-save, sync trigger
- `ai_assist_cubit.dart` — AI generation streaming
- `model_manager_page.dart` — Model download UI

### 4. Agora RTT Integration (`features/note_assist/data/services/agora_rtt_service.dart`)

- `AgoraRttService` — Start/stop/query transcription agents
- `AgoraWebhookHandler` — Parse transcript segments from webhook
- `AgoraTranscriptionSession` — Session metadata

### 5. Observability (`lib/core/observability/`)

- `json_logger.dart` — Structured JSON logging with correlation IDs
- `metrics_collector.dart` — Counters, gauges, histograms, timers
- `error_boundary.dart` — Widget and async error boundaries

### 6. Security (`lib/core/crypto/`)

- `phi_encryption_service.dart` — AES-256-GCM encryption for PHI
- `encrypted_database.dart` — SQLCipher transparent DB encryption

---

## Build & Run

### Prerequisites

```bash
# iOS (Mac only)
# - Xcode 15+
# - cmake 3.24+, git-lfs, rustc 1.70+, python3.11+
# - HF_TOKEN for model compilation
# - Physical iPhone 13+ (A15+, 6GB+, iOS 17+)

# Android
# - Android Studio with NDK
# - Physical device with Vulkan GPU, 6GB+ RAM
```

### iOS Model Compilation

```bash
cd projects/apps/doctor_app

# 1. Verify toolchain
./ios/scripts/setup_ios_mlc.sh

# 2. Compile model (requires HF token)
export HF_TOKEN=hf_xxxxxxxxxxxx
./ios/scripts/prepare_model.sh

# 3. Open Xcode
open ios/Runner.xcworkspace
# → Add MLCSwift package: File → Add Package Dependencies → Add Local → ios/mlc-llm/MLCSwift
# → Add model to Copy Bundle Resources: SmolLM-360M-Instruct-q4f16_1-MLC folder

# 4. Build & run
flutter run --release
```

### Android Build

```bash
cd projects/apps/doctor_app

# Sync Gradle (downloads MLC Android AAR)
flutter pub get
cd android && ./gradlew clean assembleRelease

# Or from Flutter
flutter build apk --release
flutter run --release
```

### Development Commands

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze

# Generate Drift database code
flutter pub run build_runner build --delete-conflicting-outputs

# Generate JSON serialization
flutter pub run build_runner build
```

---

## Configuration

### Environment Variables (dart-define)

| Variable | Description | Required |
|----------|-------------|----------|
| `ENV` | `dev`, `staging`, `prod` | Yes |
| `API_URL` | Backend base URL | No (has defaults) |
| `MODEL_DOWNLOAD_URL` | Signed model artifact URL | Prod |
| `MODEL_CHECKSUM_SHA256` | Model artifact checksum | Prod |
| `AGORA_APP_ID` | Agora app ID | For video calls |
| `AGORA_APP_CERTIFICATE` | Agora app certificate | For video calls |
| `OAUTH_CLIENT_ID` | OAuth client ID | For auth |

### Build Commands

```bash
# Development
flutter run --dart-define=ENV=dev

# Staging
flutter build ios --release --dart-define=ENV=staging \
  --dart-define=MODEL_DOWNLOAD_URL=https://... \
  --dart-define=MODEL_CHECKSUM_SHA256=...

# Production
flutter build ios --release --dart-define=ENV=prod \
  --dart-define=MODEL_DOWNLOAD_URL=https://... \
  --dart-define=MODEL_CHECKSUM_SHA256=... \
  --dart-define=AGORA_APP_ID=... \
  --dart-define=AGORA_APP_CERTIFICATE=...
```

---

## Model Distribution Pipeline

### 1. Compile Model (CI/CD)

```bash
# On Mac runner
export HF_TOKEN=${{ secrets.HF_TOKEN }}
cd projects/apps/doctor_app
./ios/scripts/prepare_model.sh
```

### 2. Upload Artifact

```bash
# Create release artifact
cd ios/mlc-llm
zip -r SmolLM-360M-Instruct-q4f16_1-MLC.zip SmolLM-360M-Instruct-q4f16_1-MLC/

# Generate checksum
sha256sum SmolLM-360M-Instruct-q4f16_1-MLC.zip > SHA256SUMS.txt

# Upload to GCP/AWS bucket with signed URL
gsutil cp SmolLM-360M-Instruct-q4f16_1-MLC.zip gs://doctorapp-prod/models/
```

### 3. Update CI/CD Variables

```yaml
# .github/workflows/release.yml
env:
  MODEL_DOWNLOAD_URL: "https://storage.googleapis.com/doctorapp-prod/models/SmolLM-360M-Instruct-q4f16_1-MLC.zip"
  MODEL_CHECKSUM_SHA256: "<from SHA256SUMS.txt>"
```

---

## Testing

### Unit Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/core/llm/hybrid_llm_adapter_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Integration Tests

```bash
# Requires device
flutter test integration_test/
```

### Test Structure

```
test/
├── core/
│   ├── llm/
│   │   ├── hybrid_llm_adapter_test.dart
│   │   └── model_manager_cubit_test.dart
│   ├── crypto/
│   │   └── phi_encryption_service_test.dart
│   └── observability/
│       └── metrics_collector_test.dart
├── features/
│   └── note_assist/
│       └── data/
│           └── services/
│               └── agora_rtt_service_test.dart
└── integration/
    └── app_test.dart
```

---

## Common Issues & Fixes

### iOS Build Fails: "MLCSwift not found"

```bash
# 1. Ensure MLCSwift package is added in Xcode
# 2. Clean build folder: Product → Clean Build Folder
# 3. Re-run: flutter clean && flutter pub get && flutter build ios
```

### Android Build Fails: "MLC Android AAR not found"

```bash
# Check Gradle dependencies
cd android && ./gradlew --refresh-dependencies
# Verify org.mlc:llm-android:0.20.0 exists on Maven
```

### Model Verification Fails

```bash
# Check model path in MLCLLMHandler.swift
# Ensure model is in Copy Bundle Resources
# Verify checksums.sha256 exists in Runner/
```

### Simulator Shows "Offline Mode"

- Expected behavior — simulator has no Metal GPU
- Test on physical device only

---

## Security Checklist

- [ ] `cloudLlmEnabled` is `false` in all builds
- [ ] Model checksums verified on download
- [ ] Database encrypted with SQLCipher
- [ ] PHI fields encrypted at rest (AES-256-GCM)
- [ ] Certificate pinning enabled for API calls
- [ ] No PHI in logs (use `JsonLogger` with PHI redaction)
- [ ] Secure storage for keys (Keychain/Keystore)
- [ ] Biometric auth for app access (recommended)

---

## Monitoring & Debugging

### Structured Logs

```dart
// All logs are JSON with:
// timestamp, level, logger, correlationId, message, error, stackTrace
final logger = JsonLogger(name: 'MyFeature');
logger.info('Processing started', correlationId: 'req-123');
```

### Metrics

```dart
// Auto-recorded for LLM, speech, sync, DB, network
MetricsCollector.instance.recordLlmInference(1500, model: 'SmolLM', tier: 'local');
```

### Error Boundaries

```dart
// Wrap any widget subtree
ErrorBoundary(
  child: MyWidget(),
  fallbackBuilder: (context, error, stack) => ErrorView(error: error),
)
```

---

## Release Process

1. **Version bump** — `pubspec.yaml` version
2. **Model compile** — Run `prepare_model.sh` on Mac
3. **Upload model** — CI uploads to bucket, sets checksum
4. **Build release** — `flutter build ios --release` + `flutter build apk --release`
5. **Test on devices** — Physical iOS + Android
6. **Archive & distribute** — TestFlight / Play Console
7. **Monitor** — Check metrics, crash reports

---

## Resources

- [MLC LLM Documentation](https://llm.mlc.ai/)
- [Drift Database](https://drift.simonbinder.eu/)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Agora RTT API](https://docs.agora.io/en/real-time-transcription/)
- [SQLCipher](https://www.zetetic.net/sqlcipher/)