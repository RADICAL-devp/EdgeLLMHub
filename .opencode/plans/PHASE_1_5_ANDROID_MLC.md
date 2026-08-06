# Phase 1.5 Execution Plan: Android Native LLM (SmolLM-350M)

**Objective:** Implement Android native LLM using MLC Android runtime via MethodChannel, matching iOS implementation.

**Dependencies:** Phase 1.1 complete (model config), Phase 1.2 complete (iOS handler pattern)

---

## 1.5.1: Add MLC Android Runtime Dependency

**File:** `projects/apps/doctor_app/android/app/build.gradle.kts` (or `.gradle`)

```kotlin
dependencies {
    // ... existing
    implementation("org.mlc.llm:mlc-android:1.4.0")  // Check latest on Maven Central
    // Or if using local AAR:
    // implementation(files("libs/mlc-android.aar"))
}
```

**Notes:**
- Verify MLC Android version matches iOS MLCSwift version
- Add to `android/settings.gradle.kts` if using local AAR

---

## 1.5.2: Create MLCLLMHandler.kt

**File:** `projects/apps/doctor_app/android/app/src/main/kotlin/com/omoyari/greentech/doctor_app/MLCLLMHandler.kt` (NEW)

**Requirements:**
- Same MethodChannel contract as iOS: `com.example.clinical/llm` + `com.example.clinical/llm_stream`
- Use MLC Android `MLCEngine` API
- Model loaded from assets: `SmolLM-350M-Instruct-q4f16_1-MLC`
- Implement: `isAvailable`, `getModelInfo`, `initialize`, `generate`, `generateStream`, `warmUp`, `cancel`
- Stream tokens via EventChannel, end with `[DONE]` sentinel
- Handle cancellation via coroutine scope

**Kotlin Structure:**
```kotlin
class MLCLLMHandler(
    private val context: Context,
    private val messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    // ... implementation mirroring iOS MLCLLMHandler
}
```

---

## 1.5.3: Register Handler in MainActivity

**File:** `projects/apps/doctor_app/android/app/src/main/kotlin/com/omoyari/greentech/doctor_app/MainActivity.kt` (MODIFY)

```kotlin
class MainActivity : FlutterActivity() {
    private var mlcHandler: MLCLLMHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mlcHandler = MLCLLMHandler(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
```

---

## 1.5.4: Bundle Model in Assets

**Steps:**
1. Run `ios/scripts/setup_ios_mlc.sh` to generate `SmolLM-350M-Instruct-q4f16_1-MLC` directory
2. Copy model directory to `android/app/src/main/assets/SmolLM-350M-Instruct-q4f16_1-MLC/`
3. Generate SHA256 checksums → `android/app/src/main/assets/checksums.sha256`

---

## 1.5.5: Update Dart Adapter

**File:** `projects/apps/doctor_app/lib/core/llm/smol_llm_adapter.dart` (REPLACE `android_native_llm_adapter.dart`)

**Changes:**
- Rename class to `SmolLLMAdapter`
- Replace `flutter_gemma` calls with MethodChannel calls matching iOS contract
- Use `StandardMethodCodec` for binary efficiency
- Implement `getModelInfo()`, `warmUp()`, `cancelActiveGeneration()`
- Add checksum verification on first run

---

## 1.5.6: Update Factory

**File:** `projects/apps/doctor_app/lib/core/llm/llm_port_factory.dart` (MODIFY)

- Instantiate `SmolLLMAdapter` on Android
- Remove `flutter_gemma` dependency from `pubspec.yaml`

---

## 1.5.7: Update Model Manager

**File:** `projects/apps/doctor_app/lib/features/note_assist/presentation/cubit/model_manager_cubit.dart` (MODIFY)

- Update `_checkAndroidModel()` to use `getModelInfo()` + checksum verification
- Add warm-up inference call

---

## 1.5.8: Remove flutter_gemma

**File:** `projects/apps/doctor_app/pubspec.yaml` (MODIFY)

```yaml
# Remove:
# flutter_gemma: ^0.2.4
```

---

## Success Criteria

| Check | Pass Condition |
|-------|----------------|
| Build | `flutter build apk --release` succeeds |
| Runtime | App launches on Android device (API 24+, 6GB+ RAM) |
| `isAvailable` | Returns `true` after `initialize()` |
| `generate` | Returns response < 20s for ~100 token prompt |
| `generateStream` | Tokens emitted via EventChannel, ends with `[DONE]` |
| `warmUp` | Completes without error |
| `cancel` | Stops active generation |
| Checksum | Model checksum verified on first run |

---

## Estimated Time

| Step | Duration |
|------|----------|
| Dependency + Handler | 4-6 hours |
| Model bundling | 1 hour |
| Dart adapter + factory | 2 hours |
| Model manager updates | 1 hour |
| Testing | 2 hours |
| **Total** | **~10-12 hours** |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| MLC Android API differs from iOS | Check `org.mlc.llm` docs; use same `MLCEngine` pattern |
| Model too large for assets | Use `bundle_weight: true` in config; consider split APKs |
| Asset loading slow on first run | Load model async on app start; show progress |
| ProGuard strips MLC classes | Add `-keep class org.mlc.llm.** { *; }` to `proguard-rules.pro` |