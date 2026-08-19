# Mobile — `doctor_app`

The doctor-facing Flutter client. This document covers its internal structure, the hybrid LLM subsystem, native platform integrations, dependency injection, testing, and known performance and reliability characteristics.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Clean Architecture](#clean-architecture)
- [Feature Modules](#feature-modules)
- [Presentation Layer](#presentation-layer)
- [Cubits](#cubits)
- [Repositories](#repositories)
- [Use Cases](#use-cases)
- [Drift (Local Database)](#drift-local-database)
- [Offline-First](#offline-first)
- [Speech Pipeline](#speech-pipeline)
- [Hybrid LLM Adapter](#hybrid-llm-adapter)
- [Native iOS Integration](#native-ios-integration)
- [Native Android Integration](#native-android-integration)
- [MethodChannels and EventChannels](#methodchannels-and-eventchannels)
- [Dependency Injection](#dependency-injection)
- [Testing](#testing)
- [Performance](#performance)
- [Future Improvements](#future-improvements)

---

## Project Structure

```
doctor_app/
├── lib/
│   ├── core/
│   │   ├── llm/
│   │   │   ├── ios_native_llm_adapter.dart
│   │   │   ├── android_native_llm_adapter.dart
│   │   │   ├── cloud_llm_adapter.dart
│   │   │   ├── hybrid_llm_adapter.dart
│   │   │   ├── stub_llm_adapter.dart
│   │   │   ├── llm_port_factory.dart
│   │   │   └── prompts/clinical_prompts.dart
│   │   ├── ports/
│   │   │   ├── llm_port.dart
│   │   │   └── transcript_repository.dart
│   │   ├── application_services/
│   │   │   ├── clinical_processing_orchestrator.dart
│   │   │   ├── summary_generation_service.dart
│   │   │   ├── doctor_note_generation_service.dart
│   │   │   └── transcript_chunking_service.dart
│   │   ├── models/
│   │   │   ├── structured_summary.dart
│   │   │   └── processing_mode.dart
│   │   ├── network/
│   │   │   ├── retry_interceptor.dart
│   │   │   ├── circuit_breaker.dart
│   │   │   └── dio_error_handler.dart
│   │   ├── validation/input_validator.dart
│   │   ├── exceptions/app_exceptions.dart
│   │   ├── services/speech_service*.dart
│   │   └── config/{environment.dart, app_config.dart}
│   └── features/note_assist/
│       ├── presentation/
│       │   ├── cubit/{note_editor_cubit, ai_assist_cubit, model_manager_cubit}.dart
│       │   ├── pages/{consultation_detail_page, model_manager_page}.dart
│       │   └── widgets/{ai_toolbar, suggestion_panel}.dart
│       ├── domain/
│       │   ├── services/note_assist_service.dart
│       │   └── models/doctor_note.dart
│       └── data/
│           ├── services/{on_device_llm_service, mock_note_assist_service}.dart
│           ├── local/local_database.dart
│           └── repositories/{note_local_repository, note_sync_repository}.dart
├── ios/Runner/{AppDelegate.swift, MLCLLMHandler.swift}
├── ios/mlc-llm/
├── android/                # Gemma integration
└── main.dart
```

## Clean Architecture

Each feature — currently just `note_assist` — is internally layered:

```
Presentation (Flutter UI + BLoC/Cubit)
        ↓
Domain (service interfaces, entities)
        ↓
Data (Drift local, Dio remote, LLM adapters)
```

Dependencies point inward. The domain layer defines `NoteAssistService` as an abstract interface; nothing in `domain/` imports Drift, Dio, or any LLM SDK. This is what makes `MockNoteAssistService` a legitimate substitute in tests — it satisfies the same interface the real `OnDeviceLlmService` does.

## Feature Modules

The codebase is feature-first at the top level (`lib/features/note_assist/`) with Clean Architecture layering inside each feature. Cross-feature concerns — LLM adapters, networking, exceptions, DI — live in `lib/core/` rather than inside any one feature, so a future second feature module (e.g., a patient-history feature) wouldn't need to duplicate the LLM plumbing.

## Presentation Layer

Built on `flutter_bloc`. Three Cubits carry the UI state for note-taking:

| Cubit | Responsibility |
|---|---|
| `NoteEditorCubit` | Note lifecycle: load/create, text updates, debounced autosave, debounced sync |
| `AiAssistCubit` | Streaming AI operations: cleanup, structuring, recap generation |
| `ModelManagerCubit` | On-device model availability/readiness state |

## Cubits

### `NoteEditorCubit` — the autosave race condition, and its fix

The original bug (documented in the mobile audit):

```dart
void _scheduleAutoSave(DoctorNote note) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(seconds: 2), () {
    _saveNote(note);  // used the note captured at schedule time
  });
}
```

If `updateText()` fired multiple times in quick succession, the timer correctly debounced to a single save — but that save used whichever `note` value had been captured *when the timer was scheduled*, not necessarily the latest edit. The fix (confirmed in the implementation walkthrough) re-reads `state` **after** the debounce fires and after any async `saveNote()` call completes, specifically because further edits could have arrived during the write. This is a textbook "stale closure over async state" bug — worth recognizing in any Cubit that mixes debounced timers with async persistence.

Debounce timing: **2-second autosave**, **3-second sync** — separate timers, so a save always happens well before a sync is attempted.

### `AiAssistCubit` — subscription lifecycle

Holds a `StreamSubscription<String>? _generationSubscription` for streaming LLM output. The original bug: a window existed between starting a new generation stream and cancelling the previous subscription, during which **both were active** and could interleave output. `close()` now cancels the subscription; starting a new stream must cancel the old one *before* subscribing to the new one, not after.

### `ModelManagerCubit`

Reports whether the on-device model is ready. The original implementation short-circuited on iOS:

```dart
if (Platform.isIOS) {
  emit(const ModelManagerReady("Bundled MLC LLM"));
  return; // no verification the MethodChannel actually works
}
```

This gave false confidence — "ready" without checking that the MethodChannel can actually communicate, that model files exist in the bundle, or that a sample inference succeeds. Current implementation performs real verification with a timeout and platform-aware error handling.

## Repositories

- **`NoteLocalRepository`** — Drift-backed CRUD for `DoctorNote`.
- **`NoteRemoteDatasource`** — Dio-backed HTTP calls to `clinical-intelligence-dart`, using `DioErrorHandler` to convert `DioException` into the app's typed `NetworkException` hierarchy rather than a bare `Exception`.
- **`NoteSyncRepository`** — orchestrates the offline sync queue: typed exceptions, a bulk `syncAllPending()` operation, and a structured `SyncResult` rather than silent pass/fail.

## Use Cases

Application-level use cases live in `core/application_services/` rather than a dedicated `usecases/` folder — `ClinicalProcessingOrchestrator`, `SummaryGenerationService`, `DoctorNoteGenerationService`, and `TranscriptChunkingService` each encapsulate one clinical operation, called from the Cubits via `NoteAssistService`. This mirrors the backend's orchestrator/service split (see [`backend.md`](backend.md)) closely enough that the two could plausibly share logic if the packages were ever unified — see [`architecture.md`](architecture.md#future-architecture).

## Drift (Local Database)

Type-safe SQLite via Drift. Two known historical issues, both addressed in the post-audit implementation:

- **Schema version was hardcoded to `1`** with no migration path — any future schema change would either throw or silently wipe data. Fixed with a real v1→v2 migration (adding a `TranscriptSummaries` table) and a `beforeOpen` hook for schema-integrity validation.
- **Database registered as a GetIt singleton with no explicit `close()`** on app termination — a risk for leaked native file handles. Documented as an open item; a `DatabaseService` wrapper with explicit lifecycle management was proposed but its adoption status in the current codebase isn't confirmed by the available documentation.

No encryption at rest exists yet for the local Drift database — see [`security.md`](security.md).

## Offline-First

Writes always land in Drift first, synchronously from the UI's perspective. Sync to `clinical-intelligence-dart` is a background concern, debounced and retried, never a blocking one. This is a deliberate CAP-theorem choice: **availability and partition tolerance over strict consistency** — a doctor can always write a note, and the backend's view of the world may be briefly stale.

**Known gap**: the sync queue itself (`sync_queue_service.dart`) is implemented as an **in-memory list** (`final List<DoctorNote> _pendingNotes = []`). The notes are safe in Drift, but if the app is OS-killed while offline, the app forgets which notes still need syncing. This is a documented P0 item — see [`security.md`](security.md) and [`architecture.md`](architecture.md#future-architecture).

A related, lower-severity inefficiency: `_replayQueue()` syncs notes one at a time in a `for` loop rather than via a bulk endpoint — real, but a P2 concern relative to the queue-durability issue.

## Speech Pipeline

```
SpeechService (abstract)
├── LocalSpeechService   — speech_to_text plugin, native on-device
├── CloudSpeechService   — Dio-based HTTP STT
└── SpeechServiceFactory — local → cloud fallback
```

Speech-to-text happens **exclusively on the mobile app**, never the backend. A known platform gap: `SFSpeechRecognizer` does not support dictation on the iOS Simulator, and the original implementation only logged the resulting error (`onError: (error) => print('Error: $error')`) rather than propagating it — `isAvailable` silently returned `false` with no user-facing explanation.

## Hybrid LLM Adapter

The centerpiece of the mobile app's resilience design. `LlmPort` is the shared contract:

```dart
abstract class LlmPort {
  Future<String> processText(String input, ProcessingMode mode);
  Future<StructuredSummary> generateStructuredSummary(String transcriptText);
  Future<StructuredSummary> generateContextEnrichedSummary(String transcriptText, String pastContext);
  Future<String> generateExecutiveSummary(String transcriptText);
  Future<String> generateDoctorNote(String transcriptText);
}
```

`HybridLlmAdapter` implements it by trying three tiers in order, tracking per-tier availability so a permanently broken tier isn't retried every call:

```dart
Future<T> _withFallback<T>({
  required Future<T> Function() native,
  required Future<T> Function() cloud,
  required Future<T> Function() stub,
}) async {
  if (_nativeAvailable) {
    try {
      return await native();
    } on UnsupportedPlatformException { _nativeAvailable = false; }
    on LlmInitializationException { _nativeAvailable = false; }
    on LlmException { /* transient — don't disable */ }
    catch (e) { _nativeAvailable = false; }
  }
  if (cloudEnabled && _cloudAvailable) {
    try {
      return await cloud();
    } on ComplianceException { _cloudAvailable = false; }
    on NetworkException catch (e) { if (!e.isTransient) _cloudAvailable = false; }
    catch (e) { _cloudAvailable = false; }
  }
  return stub();
}
```

The distinction that matters: `LlmInitializationException` and `UnsupportedPlatformException` are **permanent** — the tier is disabled for the session. A bare `LlmException` during inference is treated as **transient** — the same tier is tried again next call. Conflating these would either retry a dead tier forever or permanently abandon a tier over one bad response.

`cloudEnabled` is the compliance gate — see [`security.md`](security.md) for why its default value matters more than it might look.

## Native iOS Integration

`IosNativeLlmAdapter` communicates with Swift via a `MethodChannel` for invocation and an `EventChannel` for streamed tokens:

```dart
class IosNativeLlmAdapter implements LlmPort {
  static const _methodChannel = MethodChannel('com.example.clinical/llm');
  static const _streamChannel = EventChannel('com.example.clinical/llm_stream');
  // invokeMethod('generateStream', {...}) → listen on _streamChannel until '[DONE]'
}
```

On the Swift side, `MLCLLMHandler.swift` implements `FlutterStreamHandler`, wraps an `MLCEngine` instance, and handles `isAvailable`, `initialize`, `generate`, and `generateStream`. `AppDelegate.swift` registers the handler against the Flutter engine's binary messenger.

**This integration was originally missing entirely** — the pre-fix state of the codebase had no MethodChannel registered at all, so any call from `NativeLlmAdapter._generate()` threw `MissingPluginException`. The fix (fully specified, step by step, including Podfile changes, bridging headers, and model-file bundling) is what the implementation walkthrough confirms was completed.

Requirements for real on-device inference: a **physical A15+ device with 6GB+ RAM** (Metal GPU is not available in the Simulator), MLCSwift added as a local Swift Package in Xcode, and the model compiled via `ios/scripts/prepare_model.sh`.

## Native Android Integration

`AndroidNativeLlmAdapter` uses the `flutter_gemma` plugin (Google AI Edge LiteRT-LM), running a Gemma 2B model in TFLite format:

```dart
class AndroidNativeLlmAdapter implements LlmPort {
  Future<String> _generate(String prompt) async {
    final gemma = await _getGemmaPlugin();
    final response = await gemma.getResponse(prompt: prompt);
    return response ?? '';
  }
}
```

This is a structurally different integration from iOS — different plugin, different model format, different initialization flow — which is the root cause of the platform fragmentation documented throughout the mobile audit. A unification proposal (MediaPipe GenAI via FFI) was written up in detail but is not confirmed adopted — see [`architecture.md`](architecture.md#alternatives-considered).

## MethodChannels and EventChannels

| Channel | Direction | Purpose |
|---|---|---|
| `com.example.clinical/llm` (MethodChannel) | Dart → Swift | Invoke `initialize`, `generate`, `generateStream` |
| `com.example.clinical/llm_stream` (EventChannel) | Swift → Dart | Stream generated tokens back until a `[DONE]` sentinel |

Android has no equivalent channel — `flutter_gemma` is a conventional plugin API, not a hand-rolled channel.

## Dependency Injection

**GetIt**, wired centrally in `main.dart`. `LlmPortFactory.create()` is the composition point for the hybrid adapter:

```dart
static Future<HybridLlmAdapter> create(DeviceCapabilityService capabilityService, {Dio? dio}) async {
  final isSimulator = await capabilityService.isSimulator;
  final cloudAdapter = CloudLlmAdapter(dioInstance);
  final stubAdapter = StubLlmAdapter();
  final nativeAdapter = Platform.isIOS ? IosNativeLlmAdapter() : AndroidNativeLlmAdapter();
  return HybridLlmAdapter(
    nativeAdapter: nativeAdapter,
    cloudAdapter: cloudAdapter,
    stubAdapter: stubAdapter,
    cloudEnabled: EnvironmentConfig.cloudLlmEnabled,
  );
}
```

**Known weaknesses**, documented consistently across the audit and later reviews:
- All singletons are globally reachable via `GetIt.I<T>()` — implicit dependencies, harder to test in isolation.
- No compile-time conditional binding by platform — platform checks happen as runtime `if` branches inside registration code, not as separate DI configurations.
- The backend base URL was originally hardcoded (`http://localhost:8080`), which does not resolve on a physical device and has no dev/staging/prod split — flagged as a High-severity configuration issue.

## Testing

53 passing unit tests as of the last confirmed implementation pass:

| Test file | Tests | Coverage |
|---|---|---|
| `app_exceptions_test.dart` | 12 | Exception hierarchy, metadata, defaults |
| `stub_llm_adapter_test.dart` | 7 | No-throw guarantee, offline-prefix behavior |
| `hybrid_llm_adapter_test.dart` | 10 | 3-tier fallback, availability tracking, compliance gate |
| `circuit_breaker_test.dart` | 9 | State machine (closed/open/half-open), threshold, cooldown |
| `input_validator_test.dart` | 13 | Length limits, charset, injection detection, clinical false-positive prevention |
| *(pre-existing migration test)* | 2 | Schema migration |

**Gaps**: no Cubit-level unit tests (`NoteEditorCubit` debounce behavior, `AiAssistCubit` subscription cleanup, `ModelManagerCubit` verification flow are all identified but not yet covered), and no integration test suite that spans the mobile app and a live Dart Frog instance.

## Performance

- BLoC/Cubit's targeted rebuilds keep the UI responsive while streaming tokens in — only the widget subtree bound to the relevant state rebuilds per token.
- On-device inference shifts LLM compute cost to the doctor's device rather than shared server infrastructure — this is a direct scalability benefit for the backend (see [`scalability.md`](scalability.md)), not just a privacy one.
- The sync queue's one-request-per-note replay loop is a real, if minor, battery/radio inefficiency for a doctor who's been offline all day; a bulk sync endpoint is the identified fix.

## Future Improvements

1. Persist the sync queue as a durable Drift table (P0 — currently in-memory and volatile).
2. Add local at-rest encryption for Drift (SQLCipher or platform Keystore/Keychain-backed keys).
3. Add Cubit-level unit tests and a real mobile↔backend integration suite.
4. Add a bulk sync endpoint to replace the one-at-a-time replay loop.
5. Resolve the DI testability gap — constructor injection for direct dependencies, GetIt reserved for genuinely global singletons.
6. Revisit the MediaPipe GenAI unification proposal (or formally close it out) to reduce the iOS/Android native LLM code fragmentation.
