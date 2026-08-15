# Native LLM Channel Contract (iOS)

Contract between the Flutter app (`doctor_app`) and the native MLC LLM bridge.
This is the single source of truth for the MethodChannel/EventChannel protocol —
the Dart adapter (`lib/core/llm/ios_native_llm_adapter.dart`) and the Swift
handler (`ios/Runner/MLCLLMHandler.swift`) MUST stay in sync with this document.

## Channels

| Channel | Type | Direction | Owner |
|---------|------|-----------|-------|
| `com.example.clinical/llm` | `FlutterMethodChannel` | Dart → Swift | `MLCLLMHandler` |
| `com.example.clinical/llm_stream` | `FlutterEventChannel` | Swift → Dart | `MLCLLMHandler` |

Both channels use `StandardMethodCodec`.

## MethodChannel Methods

All methods take no arguments unless stated. All return values are listed
per method. A `FlutterError` is returned on failure (see Error Codes).

### `isAvailable`
- Returns: `bool` — whether the engine is loaded and ready.
- Never throws. Returns `false` until `initialize` succeeds.

### `getModelInfo`
- Returns: `Map<String, Object?>`:
  - `modelId` (String) — bundle name, e.g. `SmolLM-350M-Instruct-q4f16_1-MLC`
  - `modelLib` (String) — library name (same value)
  - `modelPath` (String) — resolved model directory path (empty if not installed)
  - `installed` (bool) — model directory found (Documents dir on iOS, files dir on Android)
  - `ready` (bool) — engine initialized
  - `contextWindowTokens` (int) — `2048`
  - `checksumSha256` (String) — first line of bundle `checksums.sha256`, if present
  - `runtime` (String) — `"MLCSwift"`

### `initialize`
- Args: none.
- Returns: `null` on success.
- Idempotent: no-op if already initialized.
- Errors: `MODEL_NOT_FOUND` if the model directory is not installed (download via the Model Manager screen first).

### `generate`
- Args: `{"prompt": String}` — prompt must be non-empty (whitespace trimmed).
- Returns: `String` — the full generated completion (non-streaming).
- Errors: `INVALID_ARGS`, `ENGINE_NOT_READY`, `GENERATION_FAILED`, `CANCELLED`.

### `generateStream`
- Args: `{"prompt": String}` (same validation as `generate`).
- Returns: `null` immediately; tokens are emitted on the EventChannel,
  terminated by the `[DONE]` sentinel.
- A new call cancels any in-flight streaming generation first.
- Errors: `INVALID_ARGS`, `ENGINE_NOT_READY`, `GENERATION_FAILED`, `CANCELLED`.

### `warmUp`
- Runs a short `"Hello"` generation to load weights and reduce first-request
  latency.
- Returns: `"OK"` (String) on success.
- Errors: same as `generate`.

### `cancel`
- Cancels the active generation task (if any).
- Returns: `null`. Best-effort; never throws.

## EventChannel Protocol

On `generateStream`, the native side emits:

1. Zero or more `String` events — one per generated token (or delta).
2. Exactly one final `[DONE]` sentinel String, then the stream ends.

Cancellation (`cancel`, a new `generateStream`, or stream `onCancel`) stops
emission without a `[DONE]` sentinel; the Dart side must treat stream close
without `[DONE]` as a completed (possibly truncated) result.

## Error Codes

`FlutterError.code` values produced by the native handler:

| Code | Meaning | Recoverable |
|------|---------|-------------|
| `INVALID_ARGS` | Missing/non-empty `prompt` argument | No (fix caller) |
| `MODEL_NOT_FOUND` | Model directory not installed — run `ios/scripts/setup_ios_mlc.sh` for dev builds, or download via the Model Manager screen | Yes (download) |
| `ENGINE_NOT_READY` | `generate` called before `initialize` succeeded | Yes (initialize first) |
| `STREAM_NOT_LISTENING` | `generateStream` with no active EventChannel listener | Yes (subscribe first) |
| `CANCELLED` | Generation cancelled via `cancel`/re-entrant call | Yes (expected) |
| `GENERATION_FAILED` | Generic engine/generation failure (also wraps non-bridge errors) | Yes (retry) |

`MissingPluginException` (Dart) indicates the handler was not registered —
`MLCLLMHandler` is created in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.

## Model Constraints (SmolLM-350M)

- Context window: **2048 tokens** (`mlc-package-config.json` override).
- Prefill chunk: **512 tokens**.
- Quantization: `q4f16_1`.
- Target first-token latency: < 2s; full generation budget: **20s**.
- The Dart adapter enforces a 20s timeout on `generate`/`initialize` and
  cancels the native task on timeout.

## Model Distribution

1. **First-run download (production):** the Dart `ModelManagerCubit` downloads
   the model archive (`smolLM-350M-Instruct-q4f16_1-MLC.zip`), verifies its
   SHA-256 against the configured checksum, and extracts it into the app
   Documents dir (iOS: `Documents/`, Android: `files/` via
   `getApplicationDocumentsDirectory`). The native handlers resolve the model
   directory there — this is the single source of truth on both platforms.
2. **Dev/CI:** `ios/scripts/setup_ios_mlc.sh` — verifies prerequisites, runs
   `python3 -m mlc_llm package` (downloads + compiles the model), writes
   `ios/mlc-llm/SHA256SUMS.txt` and `ios/Runner/checksums.sha256`.
   `ios-model-prep.yml` uploads the compiled artifacts to S3 + CloudFront for
   the in-app download URL (`EnvironmentConfig.modelDownloadUrl`).
3. The model is NOT bundled in either app package. A legacy bundle lookup is
   kept in the native handlers for local dev builds only.
4. `MLCSwift` Swift Package: add from local path `ios/mlc-llm/MLCSwift`
   (File → Add Package Dependencies → Add Local).
