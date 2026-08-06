# EdgeLLMHub Guide

---

## Section 1: Welcome & How to Use This Guide

**What EdgeLLMHub Is**
EdgeLLMHub is a clinical AI documentation system that enables doctors to dictate patient consultations, transcribe speech to text, and enrich transcripts into structured clinical notes. The system prioritizes patient privacy (PHI protection) by processing data on-device whenever possible, falling back to cloud LLM (Ollama) only when explicitly enabled, with a stub adapter for offline resilience.

**How to Navigate This Document**
This guide is organized by architecture (Sections 2-4) and implementation (Sections 5-9). Start with Section 2 for high-level context, then use Section 5 as a feature map. Section 7 is a quick-reference for file locations. Section 8 tells you how to run the project locally.

**Prerequisites**
- **Dart 3.x** and **Flutter 3.x** (for `doctor_app`)
- **Dart Frog CLI** (for `clinical-intelligence-dart` backend)
- **Ollama** (for local LLM inference) — optional, stub mode works without it
- Basic understanding of **REST APIs**, **state management in Flutter**, and **dependency injection**

---

---

## Section 2: Project Overview

### The Two Apps

| App | Type | Purpose | Architecture | Tech Stack |
|-----|------|---------|--------------|------------|
| `doctor_app` | Flutter mobile app | Doctor dictates speech → app transcribes → AI cleans/enhances → structured clinical note is saved | Clean Architecture | Flutter, BLoC/Cubit, Drift (SQLite), Dio, `speech_to_text` plugin, `flutter_gemma` (Android) |
| `clinical-intelligence-dart` | Dart Frog backend | Receives text processing requests from mobile app, routes via hexagonal architecture, delegates to Ollama or stub | Hexagonal / Ports-and-Adapters | Dart Frog, `http`, `provider()` DI |

### User Journey

```
Doctor taps microphone
    ↓
App records speech (speech_to_text plugin)
    ↓
Raw transcript appears in editor
    ↓
Doctor taps "Clean up" in AI toolbar
    ↓
App sends POST /api/v1/clinical-processing/process to backend
    ↓
Backend orchestrator routes to TranscriptCleanupService
    ↓
LLM Port (Ollama adapter) calls local Ollama API
    ↓
Processed text returned to app
    ↓
Doctor accepts suggestion → merged into note
    ↓
Note auto-saved to local SQLite (Drift)
```

### LLM Strategy (PHI-Conscious)

**Priority Order:**
1. **On-device** (Android: Gemma via `flutter_gemma` / Google AI Edge; iOS: MLC) — PHI never leaves device
2. **Cloud** (Ollama via Dart Frog backend) — enabled only if `EnvironmentConfig.cloudLlmEnabled == true`
3. **Stub** (offline fallback) — returns static responses for basic functionality when offline

**Fallback Logic:** `HybridLlmAdapter._withFallback()` in `lib/core/llm/hybrid_llm_adapter.dart` approximately line 49 tries native first, then cloud (if permitted), then stub.

### Technology Stack Summary

| Component | doctor_app | clinical-intelligence-dart |
|-----------|------------|-----------------------------|
| **Framework** | Flutter | Dart Frog |
| **State Management** | BLoC/Cubit | — |
| **DI** | GetIt | `provider()` (Dart Frog context) |
| **Persistence** | Drift (SQLite) | — |
| **HTTP Client** | Dio | `http` package |
| **LLM Integration** | `flutter_gemma` (Android), LlmPort abstractions | OllamaLlmAdapter, StubLlmAdapter |
| **Speech-to-Text** | `speech_to_text` plugin | — |

---

---

## Section 3: Repository Structure

### `projects/apps/doctor_app/` (Flutter App)

```
projects/apps/doctor_app/
├── lib/
│   ├── main.dart                                      # App entry point; GetIt setup; Dio + interceptors
│   ├── core/                                          # Shared utilities and abstractions (no business logic)
│   │   ├── config/
│   │   │   └── environment.dart                        # EnvironmentConfig: apiBaseUrl, cloudLlmEnabled, androidEmulatorApiUrl
│   │   ├── llm/                                       # LLM adapters and factory
│   │   │   ├── llm_port_factory.dart                 # LlmPortFactory.create() → HybridLlmAdapter with cloudEnabled flag
│   │   │   ├── hybrid_llm_adapter.dart                # HybridLlmAdapter._withFallback(): native → cloud → stub
│   │   │   ├── cloud_llm_adapter.dart                 # CloudLlmAdapter: Dio POST to backend /api/v1/clinical-processing/process
│   │   │   ├── android_native_llm_adapter.dart        # AndroidNativeLlmAdapter: flutter_gemma plugin for on-device inference
│   │   │   └── stub_llm_adapter.dart                  # StubLlmAdapter: fallback for offline
│   │   ├── network/
│   │   │   ├── retry_interceptor.dart                 # RetryInterceptor: exponential backoff for transient failures
│   │   │   └── circuit_breaker.dart                   # CircuitBreaker: registered in GetIt but not attached to Dio
│   │   ├── ports/
│   │   │   └── llm_port.dart                          # LlmPort interface: processText(inputText, ProcessingMode)
│   │   └── services/
│   │       ├── local_speech_service.dart             # LocalSpeechService: speech_to_text plugin wrapper
│   │       └── speech_service_factory.dart           # SpeechServiceFactory: chooses LocalSpeechService based on device capability
│   ├── features/                                      # Feature modules (each = self-contained)
│   │   └── note_assist/                               # Clinical note creation & AI assistance
│   │       ├── domain/                               # Domain layer (entities, use cases)
│   │       │   ├── entities/                          # DoctorNote
│   │       │   ├── repositories/                      # Repository interfaces
│   │       │   └── services/
│   │       │       └── note_assist_service.dart       # NoteAssistService (domain contract for AI actions)
│   │       ├── data/                                  # Data layer (repositories, data sources)
│   │       │   ├── local/
│   │       │   │   ├── note_local_repository.dart      # NoteLocalRepository: Drift insertOnConflictUpdate to doctorNotes table
│   │       │   │   └── local_database.dart             # Drift database schema and _openConnection()
│   │       │   ├── remote/
│   │       │   │   └── note_remote_datasource.dart      # NoteRemoteDatasource: syncNote() with commented-out POST
│   │       │   └── services/
│   │       │       └── on_device_llm_service.dart      # OnDeviceLlmService: delegates to LlmPort
│   │       └── presentation/                          # Presentation layer (UI + BLoC)
│   │           ├── cubit/
│   │           │   ├── note_editor_cubit.dart           # NoteEditorCubit: updateText(), _saveNote(), _triggerSync()
│   │           │   └── ai_assist_cubit.dart             # AiAssistCubit: cleanUpText(), _startGenerationStream()
│   │           ├── pages/
│   │           │   └── note_editor_page.dart            # NoteEditorPage: microphone FAB, SuggestionPanel, updateText()
│   │           └── widgets/
│   │               ├── ai_toolbar.dart                 # AiToolbar: "Clean up" action → AiAssistCubit.cleanUpText()
│   │               └── suggestion_panel.dart            # SuggestionPanel: renders processed text; onAccept → updateText()
│   └── ... (other app config)
└── ... (Flutter assets, pubspec, etc.)
```

**Architectural Layer Mapping:**
- **Presentation Layer:** `features/*/presentation/` (Cubits, Pages, Widgets)
- **Domain Layer:** `features/*/domain/` (Entities, Repository interfaces, Use Cases as Services)
- **Data Layer:** `features/*/data/` (Repository implementations, Data Sources, Plugins)
- **Core:** `core/` (Shared abstractions: DI, Ports, Adapters, Network, Config)

---

### `projects/apps/clinical-intelligence-dart/` (Dart Frog Backend)

```
projects/apps/clinical-intelligence-dart/
├── routes/                                           # HTTP handlers
│   ├── _middleware.dart                              # Middleware: provider<ClinicalProcessingOrchestrator>, constructs LlmPort = OllamaLlmAdapter()
│   └── api/
│       └── v1/
│           └── clinical-processing/
│               └── process.dart                      # onRequest(): parses ClinicalProcessingRequest, calls orchestrator.process()
├── lib/
│   ├── application/                                 # Application services (orchestrators)
│   │   └── services/
│   │       ├── clinical_processing_orchestrator.dart # ClinicalProcessingOrchestrator: process(), _processVocabAssist(), _processCleanTranscript()
│   │       ├── terminology_assistance_service.dart  # TerminologyAssistanceService: calls LlmPort.processText()
│   │       └── transcript_cleanup_service.dart        # TranscriptCleanupService: calls LlmPort.processText()
│   ├── infrastructure/                               # Adapters (driven side)
│   │   └── llm/
│   │       ├── ollama_llm_adapter.dart               # OllamaLlmAdapter: _generate() → HttpClient.postUrl() to local Ollama
│   │       └── stub_llm_adapter.dart                 # StubLlmAdapter: not selected by middleware
│   ├── domain/                                       # Domain models
│   │   └── dtos/
│   │       ├── clinical_processing_request.dart      # ClinicalProcessingRequest: fromJson()
│   │       └── clinical_processing_response.dart     # ClinicalProcessingResponse: toJson() exists; fromJson() MISSING
│   └── interfaces/                                   # Ports (driving side)
│       └── llm_port.dart                              # LlmPort: processText() interface
└── ... (Dart Frog config, pubspec)
```

**Architectural Layer Mapping:**
- **Handlers:** `routes/` (HTTP layer)
- **Application:** `lib/application/` (Orchestrators + Services)
- **Domain:** `lib/domain/` (DTOs, pure logic)
- **Infrastructure:** `lib/infrastructure/` (Adapters for external systems)
- **Interfaces:** `lib/interfaces/` (Ports/abstractions)

---

---

## Section 4: Architecture Deep Dive

---

### 4a. `doctor_app` — Clean Architecture

**The Three Rings (Dependency Rule: Inner → Outer only)**

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION (UI)                                                │
│  └─ Pages, Widgets, Cubits                                        │
│  └─ Depends on: Domain (interfaces) + Data (concrete)          │
└─────────────────────────────────────────────────────────────┘
                    ↓ (calls)
┌─────────────────────────────────────────────────────────────┐
│  DOMAIN                                                          │
│  └─ Entities (DoctorNote), Repository Interfaces, Use Cases    │
│  └─ Pure Dart; NO Flutter/Drift/Dio dependencies                 │
└─────────────────────────────────────────────────────────────┘
                    ↓ (implements)
┌─────────────────────────────────────────────────────────────┐
│  DATA                                                            │
│  └─ Repository Implementations, Data Sources, Plugins          │
│  └─ Depends on: Domain (interfaces) + Core (abstractions)      │
└─────────────────────────────────────────────────────────────┘
                    ↓ (uses)
┌─────────────────────────────────────────────────────────────┐
│  CORE                                                            │
│  └─ Shared abstractions: LlmPort, LlmPortFactory, Environment  │
│  └─ No business logic                                            │
└─────────────────────────────────────────────────────────────┘
```

**BLoC/Cubit: How State Flows**

- **Cubit** = simplified BLoC with single state stream (no events). Example: `NoteEditorCubit` owns `NoteEditorState` which wraps a `DoctorNote`.
- **Flow:**
  1. UI triggers action (e.g., `_toggleListening()` in `note_editor_page.dart` line 52)
  2. Cubit method called (`NoteEditorCubit.updateText()` in `note_editor_cubit.dart` line 88)
  3. Cubit updates state via `emit(newState)` (line 96 in `note_editor_cubit.dart`)
  4. Flutter rebuilds widgets listening to `BlocBuilder<NoteEditorCubit, NoteEditorState>`

**GetIt: Dependency Injection Container**

- **Registration:** `setupDependencies()` in `main.dart` lines 64-136 registers:
  - `Dio` with `BaseOptions` and `RetryInterceptor` (lines 82-90)
  - `CircuitBreaker` (line 79) — **registered but unused**
  - `LlmPortFactory.create()` → `HybridLlmAdapter` (line 111)
  - Repository implementations and services
- **Resolution:** `GetIt.I<SpeechService>()` in `note_editor_page.dart` line 59
- **Rule:** Register abstract interfaces → concrete implementations

**Drift: Reactive SQLite Persistence**

- **Schema:** `LocalDatabase` in `local_database.dart` defines `doctorNotes` table (line 11) with `primaryKey()` (line 24)
- **Access:** `NoteLocalRepository.saveNote()` in `note_local_repository.dart` line 11 calls `db.into(db.doctorNotes).insertOnConflictUpdate(DoctorNotesCompanion(...))` (line 12)
- **Connection:** `_openConnection()` in `local_database.dart` line 91 calls `NativeDatabase.createInBackground(file)`
- **Note:** No dedicated DAO class; repository writes directly through `LocalDatabase`

---

### 4b. `clinical-intelligence-dart` — Hexagonal Architecture

**Ports-and-Adapters (Driving vs Driven)**

- **Driving Side (App → Core):** `lib/interfaces/llm_port.dart` defines `LlmPort` interface with `processText(inputText, processingMode)`
- **Driven Side (Core → External):** Adapters implement `LlmPort`:
  - `OllamaLlmAdapter` (`infrastructure/llm/ollama_llm_adapter.dart`) — HTTP to local Ollama
  - `StubLlmAdapter` (`infrastructure/llm/stub_llm_adapter.dart`) — Static responses

**Dart Frog `provider()` DI Chain**

- **Middleware:** `middleware()` in `routes/_middleware.dart` line 24:
  1. Constructs `OllamaLlmAdapter()` (line 26) → assigned to `LlmPort llmPort`
  2. Constructs `TerminologyAssistanceService(llmPort, ...)` (line 39)
  3. Constructs `TranscriptCleanupService(llmPort, ...)` (line 44)
  4. Constructs `ClinicalProcessingOrchestrator(validationService, terminologyAssistanceService, transcriptCleanupService)` (line 57)
  5. Registers via `provider<ClinicalProcessingOrchestrator>(() => orchestrator)` (line 76)
- **Handler:** `onRequest()` in `process.dart` line 18 calls `context.read<ClinicalProcessingOrchestrator>()` (line 44)
- **Flow:** `Request → Route Handler → provider() → Orchestrator → Services → LlmPort → Adapter`

**Why the Orchestrator Exists**

- **Separation of Concerns:** Orchestrator (`clinical_processing_orchestrator.dart`) routes `ProcessingMode` to the correct service:
  - `ProcessingMode.vocabAssist` → `TerminologyAssistanceService` (line 37)
  - `ProcessingMode.cleanTranscript` → `TranscriptCleanupService` (line 38)
- **Validation:** Orchestrator validates `ClinicalProcessingRequest` via `ValidationService` (line 33) before processing
- **PHI Protection:** Ensures LLM prompts are wrapped with clinical context and validation happens before external calls

---

### 4c. How the Two Apps Connect

**HTTP Boundary**

```
──── HTTP BOUNDARY ────
APP sends:  POST /api/v1/clinical-processing/process
           body: { inputText: String, processingMode: String }
           (from CloudLlmAdapter._post() in doctor_app/lib/core/llm/cloud_llm_adapter.dart line 87)

BACKEND receives at: routes/api/v1/clinical-processing/process.dart line 18
```

**Shared DTO Contract**

| DTO | Fields | Direction | Status |
|-----|--------|-----------|--------|
| `ClinicalProcessingRequest` | `inputText: String`, `processingMode: String` | App → Backend | ✅ `fromJson()` implemented |
| `ClinicalProcessingResponse` | `processedText: String`, `processingMode: String`, `warnings: List<String>`, `generatedAt: String`, `metadata: Object` | Backend → App | ⚠️ `toJson()` exists; **`fromJson()` MISSING** |

**DTO Duplication Risk**

- **Problem:** Both apps define their own copies of `ClinicalProcessingRequest` and `ClinicalProcessingResponse` (not in a shared package)
- **Risk:** Schema drift — if one app changes a field, the other may break at runtime
- **Mitigation:** Currently manual alignment; consider extracting to a shared Dart package

---

---

## Section 5: Feature-by-Feature Wiring

---

### Feature 1 — Voice Capture & Speech-to-Text

**Plain English Summary**
The doctor taps the microphone button in the note editor to start dictating. The app captures audio via the device microphone, uses the native `speech_to_text` plugin to transcribe speech in real-time, and streams recognized words back into the editor. Each word is appended to the note's raw text and persisted via the Cubit state.

**Call Chain**

```
STEP 1  Doctor taps microphone FAB to toggle recording
├─ WHO:   FloatingActionButton.onPressed  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 233
├─ CALLS: _toggleListening() on _NoteEditorPageState  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 52
└─ WHY:   The FAB is the UI entry point for voice capture; toggles listening state.

STEP 2  Page flips listening state in Cubit
├─ WHO:   _toggleListening()  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 52
├─ CALLS: setListening() on NoteEditorCubit  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 58
└─ WHY:   Cubit state must reflect active dictation to update UI (microphone icon, status text).

STEP 3  Page starts injected SpeechService with transcript callback
├─ WHO:   _toggleListening()  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 52
├─ CALLS: startListening(Function(String)) on SpeechService  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 59
└─ WHY:   Delegates speech capture to abstract service; callback receives recognized words.

STEP 4  SpeechServiceFactory selects native implementation for capable devices
├─ WHO:   SpeechServiceFactory.create()  in  lib/core/services/speech_service_factory.dart  line 23
├─ CALLS: canUseSpeechToText() on DeviceCapabilityService  in  lib/core/services/speech_service_factory.dart  line 27
└─ WHY:   Physical devices use native STT; simulators fall back to cloud/mock.

STEP 5  LocalSpeechService initializes the speech_to_text plugin
├─ WHO:   LocalSpeechService.initialize()  in  lib/core/services/local_speech_service.dart  line 16
├─ CALLS: initialize() on stt.SpeechToText  in  lib/core/services/local_speech_service.dart  line 20
└─ WHY:   Plugin must report availability before starting native speech recognition.

STEP 6  LocalSpeechService starts listening and receives recognized words
├─ WHO:   LocalSpeechService.startListening()  in  lib/core/services/local_speech_service.dart  line 51
├─ CALLS: listen() on stt.SpeechToText  in  lib/core/services/local_speech_service.dart  line 58
└─ WHY:   Plugin delivers recognized text via onResult callback with result.recognizedWords.

STEP 7  Recognized text is appended to editor and sent to Cubit
├─ WHO:   _toggleListening() callback  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 59
├─ CALLS: updateText(newText) on NoteEditorCubit  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 64
└─ WHY:   Dictated text must update both the TextEditingController and the Cubit's DoctorNote state.

STEP 8  Cubit updates DoctorNote rawText and emits new state
├─ WHO:   NoteEditorCubit.updateText()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 88
├─ CALLS: copyWith(rawText: newText) on DoctorNote  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 91
└─ WHY:   NoteEditorLoaded state holds DoctorNote as source of truth; emits to trigger UI rebuild.
```

**Key Files to Open**
- `lib/features/note_assist/presentation/pages/note_editor_page.dart`
- `lib/features/note_assist/presentation/cubit/note_editor_cubit.dart`
- `lib/core/services/local_speech_service.dart`
- `lib/core/services/speech_service_factory.dart`

**Status Badge**
✅ **FULLY WIRED**

---


### Feature 2 — Clinical Processing Dispatch (App → Backend)

**Plain English Summary**
When the doctor taps "Clean up" in the AI toolbar, the app packages the raw transcript and sends it to the backend for AI-driven clinical text processing. The request is routed through a domain service, then through the LLM port abstraction, ultimately making an HTTP POST to the Dart Frog backend if cloud is enabled or on-device LLM is unavailable.

**Call Chain**

```
STEP 1  Doctor taps "Clean up" in AI toolbar
├─ WHO:   AiToolbar.build()  in  lib/features/note_assist/presentation/widgets/ai_toolbar.dart  line 12
├─ CALLS: cleanUpText(currentText) on AiAssistCubit  in  lib/features/note_assist/presentation/widgets/ai_toolbar.dart  line 35
└─ WHY:   UI action maps to the clinical clean-transcript workflow via Cubit.

STEP 2  AiAssistCubit starts generation via domain service
├─ WHO:   AiAssistCubit.cleanUpText()  in  lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart  line 14
├─ CALLS: cleanUpText(rawText) on NoteAssistService  in  lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart  line 16
└─ WHY:   Presentation layer delegates AI processing to domain service abstraction.

STEP 3  OnDeviceLlmService translates action to LLM port call
├─ WHO:   OnDeviceLlmService.cleanUpText()  in  lib/features/note_assist/data/services/on_device_llm_service.dart  line 13
├─ CALLS: processText(rawText, ProcessingMode.cleanTranscript) on LlmPort  in  lib/features/note_assist/data/services/on_device_llm_service.dart  line 14
└─ WHY:   Maps domain intention (cleanUpText) to correct LLM processing mode before execution.

STEP 4  HybridLlmAdapter chooses native first, then cloud, then stub
├─ WHO:   HybridLlmAdapter.processText()  in  lib/core/llm/hybrid_llm_adapter.dart  line 45
├─ CALLS: _withFallback() on HybridLlmAdapter  in  lib/core/llm/hybrid_llm_adapter.dart  line 46
└─ WHY:   Compliance and resilience enforced by native → cloud → stub fallback order.

STEP 5  CloudLlmAdapter prepares backend POST
├─ WHO:   CloudLlmAdapter.processText()  in  lib/core/llm/cloud_llm_adapter.dart  line 19
├─ CALLS: _post() on CloudLlmAdapter  in  lib/core/llm/cloud_llm_adapter.dart  line 21
└─ WHY:   Cloud fallback serializes inputText and processingMode for backend.

──── HTTP BOUNDARY ────
APP sends:  POST /api/v1/clinical-processing/process
           body: { inputText: string, processingMode: string }
BACKEND receives at: routes/api/v1/clinical-processing/process.dart  line 18

STEP 6  Dio performs outgoing HTTP POST
├─ WHO:   CloudLlmAdapter._post()  in  lib/core/llm/cloud_llm_adapter.dart  line 82
├─ CALLS: post() on Dio  in  lib/core/llm/cloud_llm_adapter.dart  line 87
└─ WHY:   Actual network call for /api/v1/clinical-processing/process with serialized body.

STEP 7  Dio is constructed with shared API base URL and interceptors
├─ WHO:   setupDependencies()  in  lib/main.dart  line 64
├─ CALLS: Dio() with BaseOptions(baseUrl: EnvironmentConfig.apiBaseUrl)  in  lib/main.dart  line 82
└─ WHY:   Centralized HTTP client configuration for backend API.

STEP 8  RetryInterceptor attached to shared Dio instance
├─ WHO:   setupDependencies()  in  lib/main.dart  line 90
├─ CALLS: add() on dio.interceptors  in  lib/main.dart  line 90
└─ WHY:   Transient idempotent HTTP failures automatically retried with exponential backoff.
```

**Key Files to Open**
- `lib/features/note_assist/presentation/widgets/ai_toolbar.dart`
- `lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart`
- `lib/features/note_assist/data/services/on_device_llm_service.dart`
- `lib/core/llm/cloud_llm_adapter.dart`
- `lib/core/llm/hybrid_llm_adapter.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: Dispatch goes through CloudLlmAdapter directly; no ClinicalProcessingRemoteDatasource exists — Fix: Consider introducing a repository pattern for clinical processing remote calls in `lib/features/note_assist/data/remote/`

---

### Feature 3 — Backend: Request Reception & Orchestration

**Plain English Summary**
The Dart Frog backend receives the clinical processing POST request, parses the JSON body into a `ClinicalProcessingRequest` DTO, and delegates to the `ClinicalProcessingOrchestrator`. The orchestrator validates the request, routes it to the appropriate service based on `processingMode` (e.g., CLEAN_TRANSCRIPT → `TranscriptCleanupService`), which then calls the LLM port. The response is serialized as JSON and returned to the client.

**Call Chain**

```
STEP 1  Route handler receives and parses the request body
├─ WHO:   onRequest()  in  routes/api/v1/clinical-processing/process.dart  line 18
├─ CALLS: body() on Request  in  routes/api/v1/clinical-processing/process.dart  line 30
└─ WHY:   Reads the HTTP request body as bytes for JSON parsing.

STEP 2  Route parses body into ClinicalProcessingRequest DTO
├─ WHO:   onRequest()  in  routes/api/v1/clinical-processing/process.dart  line 18
├─ CALLS: fromJson() on ClinicalProcessingRequest  in  routes/api/v1/clinical-processing/process.dart  line 42
└─ WHY:   Deserializes JSON into typed request DTO for processing.

STEP 3  Route retrieves orchestrator from Dart Frog provider()
├─ WHO:   onRequest()  in  routes/api/v1/clinical-processing/process.dart  line 18
├─ CALLS: read<ClinicalProcessingOrchestrator>() on RequestContext  in  routes/api/v1/clinical-processing/process.dart  line 44
└─ WHY:   Looks up the orchestrator instance injected by middleware.

STEP 4  Root middleware injects ClinicalProcessingOrchestrator
├─ WHO:   middleware()  in  routes/_middleware.dart  line 24
├─ CALLS: provider<ClinicalProcessingOrchestrator>((context) => orchestrator)  in  routes/_middleware.dart  line 76
└─ WHY:   Provides the orchestrator to all route handlers via Dart Frog DI.

STEP 5  Middleware constructs the active LLM dependency as Ollama
├─ WHO:   middleware()  in  routes/_middleware.dart  line 24
├─ CALLS: OllamaLlmAdapter() on OllamaLlmAdapter  in  routes/_middleware.dart  line 26
└─ WHY:   Provides concrete LLM adapter to services. StubLlmAdapter exists but is not selected.

STEP 6  Middleware constructs terminology and cleanup services
├─ WHO:   middleware()  in  routes/_middleware.dart  line 24
├─ CALLS: TerminologyAssistanceService(llmPort, normalizationService)  in  routes/_middleware.dart  line 39
├─ CALLS: TranscriptCleanupService(llmPort, normalizationService)  in  routes/_middleware.dart  line 44
└─ WHY:   Services depend on LlmPort abstraction to keep LLM details out of business logic.

STEP 7  Middleware constructs orchestrator with services
├─ WHO:   middleware()  in  routes/_middleware.dart  line 24
├─ CALLS: ClinicalProcessingOrchestrator(validationService, terminologyAssistanceService, transcriptCleanupService)  in  routes/_middleware.dart  line 57
└─ WHY:   Orchestrator composes validation and processing services.

STEP 8  Route invokes orchestration with parsed request
├─ WHO:   onRequest()  in  routes/api/v1/clinical-processing/process.dart  line 18
├─ CALLS: process(request) on ClinicalProcessingOrchestrator  in  routes/api/v1/clinical-processing/process.dart  line 45
└─ WHY:   Delegates business logic to orchestrator layer.

STEP 9  Orchestrator validates request
├─ WHO:   ClinicalProcessingOrchestrator.process()  in  lib/application/services/clinical_processing_orchestrator.dart  line 29
├─ CALLS: validateClinicalProcessingRequest() on ValidationService  in  lib/application/services/clinical_processing_orchestrator.dart  line 33
└─ WHY:   Ensures request is valid before processing (e.g., inputText not empty).

STEP 10  VOCAB_ASSIST routes to terminology assistance
├─ WHO:   ClinicalProcessingOrchestrator.process()  in  lib/application/services/clinical_processing_orchestrator.dart  line 29
├─ CALLS: _processVocabAssist() on ClinicalProcessingOrchestrator  in  lib/application/services/clinical_processing_orchestrator.dart  line 37
└─ WHY:   Routes ProcessingMode.vocabAssist to terminology service.

STEP 11  Terminology assistance reaches LLM port
├─ WHO:   TerminologyAssistanceService.process()  in  lib/application/services/terminology_assistance_service.dart  line 29
├─ CALLS: processText() on LlmPort  in  lib/application/services/terminology_assistance_service.dart  line 41
└─ WHY:   Service uses LLM port abstraction for text processing.

STEP 12  CLEAN_TRANSCRIPT routes to transcript cleanup
├─ WHO:   ClinicalProcessingOrchestrator.process()  in  lib/application/services/clinical_processing_orchestrator.dart  line 29
├─ CALLS: _processCleanTranscript() on ClinicalProcessingOrchestrator  in  lib/application/services/clinical_processing_orchestrator.dart  line 38
└─ WHY:   Routes ProcessingMode.cleanTranscript to cleanup service.

STEP 13  Transcript cleanup reaches LLM port
├─ WHO:   TranscriptCleanupService.process()  in  lib/application/services/transcript_cleanup_service.dart  line 30
├─ CALLS: processText() on LlmPort  in  lib/application/services/transcript_cleanup_service.dart  line 49
└─ WHY:   Service delegates to LLM port for actual text processing.

STEP 14  Orchestrator returns ClinicalProcessingResponse DTO
├─ WHO:   ClinicalProcessingOrchestrator._processVocabAssist()  in  lib/application/services/clinical_processing_orchestrator.dart  line 50
├─ CALLS: ClinicalProcessingResponse(...) constructor  in  lib/application/services/clinical_processing_orchestrator.dart  line 56
└─ WHY:   Wraps processed text and metadata into response DTO for serialization.

STEP 15  Route serializes response as JSON
├─ WHO:   onRequest()  in  routes/api/v1/clinical-processing/process.dart  line 18
├─ CALLS: json() on Response  in  routes/api/v1/clinical-processing/process.dart  line 47
└─ WHY:   Converts ClinicalProcessingResponse DTO to JSON for HTTP response.
```

**Key Files to Open**
- `routes/api/v1/clinical-processing/process.dart`
- `routes/_middleware.dart`
- `lib/application/services/clinical_processing_orchestrator.dart`
- `lib/application/services/terminology_assistance_service.dart`
- `lib/application/services/transcript_cleanup_service.dart`

**Status Badge**
✅ **FULLY WIRED**

---


### Feature 4 — LLM Adapter Selection & Text Processing

**Plain English Summary**
The backend selects a concrete LLM adapter (currently Ollama) via Dart Frog middleware and injects it into the orchestrator's services. The Ollama adapter prepares a clinical prompt based on the processing mode, then sends an HTTP POST to a local Ollama instance for text generation. A stub adapter exists but is not active in middleware.

**Call Chain**

```
STEP 1  Middleware constructs Ollama as the active LLM adapter
├─ WHO:   middleware()  in  routes/_middleware.dart  line 24
├─ CALLS: OllamaLlmAdapter()  in  routes/_middleware.dart  line 26
└─ WHY:   Provides concrete LLM implementation to the application layer.
⚠️ BUG: Comment at line 27 says "To use Ollama ... uncomment" but line 26 already instantiates OllamaLlmAdapter() — comment is misleading.

STEP 2  Ollama adapter builds prompt for requested processing mode
├─ WHO:   OllamaLlmAdapter.processText()  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 34
├─ CALLS: _generate(prompt, model) on OllamaLlmAdapter  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 47
└─ WHY:   Wraps input text with clinical context prompt specific to processing mode.

STEP 3  Ollama adapter opens HTTP request to local Ollama API
├─ WHO:   OllamaLlmAdapter._generate()  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 86
├─ CALLS: postUrl() on HttpClient  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 89
└─ WHY:   Opens connection to Ollama's HTTP API (typically http://localhost:11434/api/generate).

STEP 4  Ollama adapter sends model, prompt, stream flag, temperature
├─ WHO:   OllamaLlmAdapter._generate()  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 86
├─ CALLS: write() on HttpClientRequest  in  lib/infrastructure/llm/ollama_llm_adapter.dart  line 93
└─ WHY:   Sends JSON body with model name (e.g., "gemma:2b"), prompt, stream=true, temperature=0.0.

STEP 5  Stub adapter exists but is inactive
├─ WHO:   StubLlmAdapter.processText()  in  lib/infrastructure/llm/stub_llm_adapter.dart  line 19
└─ NOTE:  No provider in middleware selects StubLlmAdapter; Ollama is active at routes/_middleware.dart line 26.
```

**Key Files to Open**
- `routes/_middleware.dart`
- `lib/infrastructure/llm/ollama_llm_adapter.dart`
- `lib/infrastructure/llm/stub_llm_adapter.dart`

**Status Badge**
✅ **FULLY WIRED**

**Gaps**
🔧 GAP: Misleading comment in `routes/_middleware.dart` line 27 contradicts active Ollama instantiation at line 26 — Fix: Update comment to reflect that Ollama is already active, or remove the comment entirely.

---

### Feature 5 — Response Propagation (Backend → App UI)

**Plain English Summary**
The backend serializes the `ClinicalProcessingResponse` DTO as JSON and returns it to the app. The app's `CloudLlmAdapter` receives the response, extracts the `processedText` field directly from the JSON map (bypassing DTO deserialization due to missing `fromJson`), and streams it to the `AiAssistCubit`. The Cubit emits states to signal suggestion progress, and the UI renders the processed text in a `SuggestionPanel`. When the doctor accepts, the text is merged into the note editor.

**Call Chain**

```
STEP 1  Orchestrator returns ClinicalProcessingResponse DTO
├─ WHO:   ClinicalProcessingOrchestrator._processVocabAssist()  in  lib/application/services/clinical_processing_orchestrator.dart  line 50
├─ CALLS: ClinicalProcessingResponse(processedText: ..., processingMode: ..., warnings: [], generatedAt: ..., metadata: {})  in  lib/application/services/clinical_processing_orchestrator.dart  line 56
└─ WHY:   Encapsulates processed text and metadata for serialization.

STEP 2  Orchestrator returns ClinicalProcessingResponse for CLEAN_TRANSCRIPT
├─ WHO:   ClinicalProcessingOrchestrator._processCleanTranscript()  in  lib/application/services/clinical_processing_orchestrator.dart  line 69
├─ CALLS: ClinicalProcessingResponse(...)  in  lib/application/services/clinical_processing_orchestrator.dart  line 75
└─ WHY:   Same response structure for both processing modes.

──── HTTP BOUNDARY ────
BACKEND sends:  200 JSON  { processedText: string, processingMode: string, warnings: string[], generatedAt: string, metadata: object }
APP receives in: lib/core/llm/cloud_llm_adapter.dart  line 87

STEP 3  App receives JSON map from Dio response
├─ WHO:   CloudLlmAdapter._post()  in  lib/core/llm/cloud_llm_adapter.dart  line 82
├─ CALLS: post() on Dio  in  lib/core/llm/cloud_llm_adapter.dart  line 87
└─ WHY:   Dio deserializes JSON response into Map<String, dynamic>.

STEP 4  CloudLlmAdapter extracts processedText directly from map
├─ WHO:   CloudLlmAdapter.processText()  in  lib/core/llm/cloud_llm_adapter.dart  line 19
├─ CALLS: Direct map access response['processedText'] on Map<String, dynamic>  in  lib/core/llm/cloud_llm_adapter.dart  line 28
└─ WHY:   Only needs processedText; bypasses DTO instantiation due to missing fromJson().
⚠️ NOT WIRED: ClinicalProcessingResponse.fromJson() is missing in lib/core/dto/clinical_processing_response.dart; only toJson() exists at line 19.

STEP 5  AiAssistCubit emits suggestion states (in-progress → ready)
├─ WHO:   AiAssistCubit._startGenerationStream()  in  lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart  line 28
├─ CALLS: emit(AiAssistSuggestionInProgress) on AiAssistCubit  in  lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart  line 36
├─ CALLS: emit(AiAssistSuggestionReady) on AiAssistCubit  in  lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart  line 42
└─ WHY:   Notifies UI of processing state transitions.

STEP 6  SuggestionPanel renders processed text
├─ WHO:   SuggestionPanel.build()  in  lib/features/note_assist/presentation/widgets/suggestion_panel.dart  line 12
├─ CALLS: Text(response.processedText) widget  in  lib/features/note_assist/presentation/widgets/suggestion_panel.dart  line 93
└─ WHY:   Displays the AI-generated suggestion to the doctor for review.

STEP 7  Doctor accepts suggestion → merged into note editor
├─ WHO:   NoteEditorPage.build() onAccept callback  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 138
├─ CALLS: updateText(newText) on NoteEditorCubit  in  lib/features/note_assist/presentation/pages/note_editor_page.dart  line 174
└─ WHY:   Accepted suggestion becomes part of the note's rawText.
```

**Key Files to Open**
- `lib/application/services/clinical_processing_orchestrator.dart`
- `lib/core/llm/cloud_llm_adapter.dart`
- `lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart`
- `lib/features/note_assist/presentation/widgets/suggestion_panel.dart`
- `lib/features/note_assist/presentation/pages/note_editor_page.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: `ClinicalProcessingResponse.fromJson()` is missing in `lib/core/dto/clinical_processing_response.dart` — Fix: Add `fromJson(Map<String, dynamic> json)` method to deserialize backend responses, then use it in `CloudLlmAdapter.processText()` instead of direct map access.

---


### Feature 6 — On-Device LLM Path (flutter_gemma / Gemma local inference)

**Plain English Summary**
On Android, the app uses Google AI Edge via the `flutter_gemma` plugin for on-device LLM inference. The `LlmPortFactory` creates a `HybridLlmAdapter` that prioritizes the `AndroidNativeLlmAdapter`. The hybrid adapter first attempts on-device inference, falls back to cloud if `EnvironmentConfig.cloudLlmEnabled` is true, and finally uses the stub adapter if both fail.

**Call Chain**

```
STEP 1  EnvironmentConfig defines cloud LLM toggle
├─ WHO:   EnvironmentConfig.cloudLlmEnabled  in  lib/core/config/environment.dart  line 54
└─ WHY:   Runtime flag controlling whether cloud fallback is permitted.

STEP 2  App setup calls LlmPortFactory to create LLM port
├─ WHO:   setupDependencies()  in  lib/main.dart  line 111
├─ CALLS: LlmPortFactory.create() on LlmPortFactory  in  lib/core/llm/llm_port_factory.dart  line 28
└─ WHY:   Centralizes LLM adapter construction with environment-based configuration.

STEP 3  Factory checks if running on simulator
├─ WHO:   LlmPortFactory.create()  in  lib/core/llm/llm_port_factory.dart  line 28
├─ CALLS: isSimulator() on DeviceCapabilityService  in  lib/core/llm/llm_port_factory.dart  line 32
└─ WHY:   Simulators cannot use native LLM; must fall back to cloud/stub.

STEP 4  Factory selects Android native adapter for physical Android devices
├─ WHO:   LlmPortFactory.create()  in  lib/core/llm/llm_port_factory.dart  line 60
├─ CALLS: AndroidNativeLlmAdapter() on AndroidNativeLlmAdapter  in  lib/core/llm/android_native_llm_adapter.dart  line 72
└─ WHY:   Selects Gemma-based on-device adapter when running on Android.

STEP 5  Factory returns HybridLlmAdapter wrapping native adapter
├─ WHO:   LlmPortFactory.create()  in  lib/core/llm/llm_port_factory.dart  line 70
├─ CALLS: HybridLlmAdapter(nativeAdapter, cloudEnabled)  in  lib/core/llm/llm_port_factory.dart  line 70
└─ WHY:   Hybrid adapter manages fallback chain: native → cloud (if enabled) → stub.

STEP 6  OnDeviceLlmService wired to hybrid LLM port
├─ WHO:   setupDependencies()  in  lib/main.dart  line 136
├─ CALLS: OnDeviceLlmService(LlmPort)  in  lib/main.dart  line 136
└─ WHY:   Domain service uses LLM port abstraction for text processing.

STEP 7  HybridLlmAdapter attempts native first
├─ WHO:   HybridLlmAdapter._withFallback()  in  lib/core/llm/hybrid_llm_adapter.dart  line 48
├─ CALLS: processText() on AndroidNativeLlmAdapter  in  lib/core/llm/android_native_llm_adapter.dart  line 77
└─ WHY:   Prioritizes on-device LLM to preserve PHI and enable offline capability.

STEP 8  AndroidNativeLlmAdapter calls _generate()
├─ WHO:   AndroidNativeLlmAdapter.processText()  in  lib/core/llm/android_native_llm_adapter.dart  line 77
├─ CALLS: _generate(prompt) on AndroidNativeLlmAdapter  in  lib/core/llm/android_native_llm_adapter.dart  line 79
└─ WHY:   Prepares the prompt and delegates to the native plugin.

STEP 9  _FlutterGemmaProxy calls flutter_gemma plugin
├─ WHO:   AndroidNativeLlmAdapter._generate()  in  lib/core/llm/android_native_llm_adapter.dart  line 123
├─ CALLS: getResponse(prompt) on FlutterGemmaProxy  in  lib/core/llm/android_native_llm_adapter.dart  line 172
└─ WHY:   Invokes the flutter_gemma plugin for on-device inference.

STEP 10  flutter_gemma plugin executes on-device inference
├─ WHO:   FlutterGemmaProxy.getResponse()  in  lib/core/llm/android_native_llm_adapter.dart  line 167
├─ CALLS: FlutterGemmaPlugin.getResponse() on FlutterGemmaPlugin  in  lib/core/llm/android_native_llm_adapter.dart  line 172
└─ WHY:   Uses Google AI Edge to execute the prompt directly on the Android device.
⚠️ NOT WIRED: Android model verification is TODO-only in lib/features/model_manager/presentation/cubit/model_manager_cubit.dart line 194.
⚠️ NOT WIRED: Android model download is commented/TODO-only in lib/features/model_manager/presentation/cubit/model_manager_cubit.dart lines 210-221.
```

**Key Files to Open**
- `lib/core/llm/llm_port_factory.dart`
- `lib/core/llm/hybrid_llm_adapter.dart`
- `lib/core/llm/android_native_llm_adapter.dart`
- `lib/core/config/environment.dart`
- `lib/features/model_manager/presentation/cubit/model_manager_cubit.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: Android model verification is TODO-only — Fix: Implement model verification logic in `ModelManagerCubit` to check if the required Gemma model is available on-device before attempting inference.
🔧 GAP: Android model download is commented out — Fix: Uncomment and implement model download functionality in `ModelManagerCubit` to fetch the Gemma model from Google AI Edge when not present.

---

### Feature 7 — Note Persistence (Local Storage via Drift)

**Plain English Summary**
Every change to the note's text (via dictation or manual editing) triggers an auto-save via the `NoteEditorCubit`. The cubit schedules a debounced save to the `NoteLocalRepository`, which maps the `DoctorNote` domain entity to a Drift `DoctorNotesCompanion` and upserts it into the `doctorNotes` SQLite table. Drift handles the database connection in the background.

**Call Chain**

```
STEP 1  NoteEditorCubit loads or creates note on initialization
├─ WHO:   NoteEditorCubit.loadOrCreateNote()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 27
├─ CALLS: DoctorNote() constructor  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 37
├─ CALLS: saveNote(note) on NoteLocalRepository  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 46
└─ WHY:   Creates initial note state and persists it immediately.

STEP 2  NoteEditorCubit updates DoctorNote rawText on user input
├─ WHO:   NoteEditorCubit.updateText()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 88
├─ CALLS: copyWith(rawText: newText) on DoctorNote  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 91
└─ WHY:   Updates the domain entity's rawText field immutably.

STEP 3  NoteEditorCubit schedules auto-save
├─ WHO:   NoteEditorCubit.updateText()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 88
├─ CALLS: _scheduleAutoSave() on NoteEditorCubit  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 97
└─ WHY:   Debounces save operations to avoid excessive disk writes.

STEP 4  NoteEditorCubit saves note to local repository
├─ WHO:   NoteEditorCubit._saveNote()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 108
├─ CALLS: saveNote(note) on NoteLocalRepository  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 117
└─ WHY:   Delegates persistence to the data layer.

STEP 5  NoteLocalRepository maps DoctorNote to Drift companion and upserts
├─ WHO:   NoteLocalRepository.saveNote()  in  lib/features/note_assist/data/local/note_local_repository.dart  line 11
├─ CALLS: insertOnConflictUpdate() on InsertStatement  in  lib/features/note_assist/data/local/local_database.dart
└─ WHY:   Converts domain entity to Drift companion and performs upsert to avoid duplicates.
⚠️ NOT WIRED: No dedicated Drift DAO class; NoteLocalRepository writes directly through LocalDatabase.

STEP 6  DoctorNotes table defined in Drift schema
├─ WHO:   DoctorNotes table  in  lib/features/note_assist/data/local/local_database.dart  line 11
├─ CALLS: primaryKey()  in  lib/features/note_assist/data/local/local_database.dart  line 24
└─ WHY:   Defines the SQLite table structure for notes with auto-incrementing ID as primary key.

STEP 7  Generated Drift accessor handles queries
├─ WHO:   _$LocalDatabase generated code  in  lib/features/note_assist/data/local/local_database.g.dart  line 1552
└─ WHY:   Drift code generation provides type-safe database access.

STEP 8  Database connection opened in background
├─ WHO:   _openConnection()  in  lib/features/note_assist/data/local/local_database.dart  line 91
├─ CALLS: NativeDatabase.createInBackground(file)  in  lib/features/note_assist/data/local/local_database.dart  line 91
└─ WHY:   Opens SQLite connection asynchronously to avoid blocking the UI thread.
```

**Key Files to Open**
- `lib/features/note_assist/presentation/cubit/note_editor_cubit.dart`
- `lib/features/note_assist/data/local/note_local_repository.dart`
- `lib/features/note_assist/data/local/local_database.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: No dedicated Drift DAO class — Fix: Consider creating a `DoctorNoteDao` class in `lib/features/note_assist/data/local/` to encapsulate all Drift operations, then have `NoteLocalRepository` delegate to it for better separation of concerns.

---

### Feature 8 — Android Emulator URL Resolution

**Plain English Summary**
When running the app on an Android emulator, the backend API URL needs to be `http://10.0.2.2:<port>` to reach the host machine's Dart Frog server. The `EnvironmentConfig` provides both `apiBaseUrl` (default) and `androidEmulatorApiUrl` (for emulators). However, the shared Dio instance in `main.dart` always uses `apiBaseUrl`, bypassing the emulator-specific URL.

**Call Chain**

```
STEP 1  EnvironmentConfig defines default API base URL
├─ WHO:   EnvironmentConfig.apiBaseUrl  in  lib/core/config/environment.dart  line 32
├─ CALLS: fromEnvironment('API_URL', defaultValue: 'http://localhost:8080')  in  lib/core/config/environment.dart  line 33
└─ WHY:   Determines the default backend API location from environment variables.

STEP 2  EnvironmentConfig defines Android emulator API URL
├─ WHO:   EnvironmentConfig.androidEmulatorApiUrl  in  lib/core/config/environment.dart  line 44
├─ CALLS: fromEnvironment('ANDROID_EMULATOR_API_URL', defaultValue: 'http://10.0.2.2:8080')  in  lib/core/config/environment.dart  line 45
└─ WHY:   Provides emulator-specific URL to reach host from Android emulator.

STEP 3  DeviceCapabilityService detects Android emulator
├─ WHO:   DeviceCapabilityService.isSimulator  in  lib/core/services/device_capability_service.dart  line 17
├─ CALLS: androidInfo() on DeviceInfoPlugin  in  lib/core/services/device_capability_service.dart  line 24
└─ WHY:   Checks if running on Android emulator (isSimulator returns true for emulators).

STEP 4  LlmPortFactory accesses emulator URL config
├─ WHO:   LlmPortFactory.create()  in  lib/core/llm/llm_port_factory.dart  line 37
├─ CALLS: EnvironmentConfig.androidEmulatorApiUrl()  in  lib/core/llm/llm_port_factory.dart  line 37
└─ WHY:   Retrieves the emulator-specific URL for potential use in hybrid adapter.

STEP 5  BUG: Shared Dio in main.dart always uses apiBaseUrl
├─ WHO:   setupDependencies()  in  lib/main.dart  line 82
├─ CALLS: Dio(BaseOptions(baseUrl: EnvironmentConfig.apiBaseUrl))  in  lib/main.dart  line 82
└─ WHY:   Central Dio instance uses default URL, bypassing emulator detection and androidEmulatorApiUrl.
⚠️ NOT WIRED: Android emulator URL selection not applied to shared Dio in lib/main.dart line 83.
```

**Key Files to Open**
- `lib/core/config/environment.dart`
- `lib/core/services/device_capability_service.dart`
- `lib/core/llm/llm_port_factory.dart`
- `lib/main.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: Android emulator URL resolution bypassed by shared Dio instance — Fix: In `setupDependencies()` in `main.dart`, conditionally set `baseUrl` to `EnvironmentConfig.androidEmulatorApiUrl` when `DeviceCapabilityService.isSimulator()` is true, or inject the correct URL into CloudLlmAdapter at construction time.

---


### Feature 9 — Note Sync to Backend

**Plain English Summary**
When a note is saved or updated, the app should sync it to the backend API. The `NoteEditorCubit` triggers sync via `NoteSyncRepository`, which calls `NoteRemoteDatasource.syncNote()`. However, the actual HTTP POST to `/api/doctor-notes/sync` is commented out, and the corresponding backend route does not exist.

**Call Chain**

```
STEP 1  NoteEditorCubit loads or creates note and triggers sync
├─ WHO:   NoteEditorCubit.loadOrCreateNote()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 27
├─ CALLS: _triggerSync() on NoteEditorCubit  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 57
└─ WHY:   Initial note creation should sync to backend if connectivity is available.

STEP 2  NoteEditorCubit calls sync repository
├─ WHO:   NoteEditorCubit._triggerSync()  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 63
├─ CALLS: syncNoteToBackend() on NoteSyncRepository  in  lib/features/note_assist/presentation/cubit/note_editor_cubit.dart  line 69
└─ WHY:   Delegates sync logic to repository layer.

STEP 3  NoteSyncRepository calls remote data source
├─ WHO:   NoteSyncRepository.syncNoteToBackend()  in  lib/features/note_assist/data/remote/note_sync_repository.dart  line 23
├─ CALLS: syncNote() on NoteRemoteDatasource  in  lib/features/note_assist/data/remote/note_sync_repository.dart  line 43
└─ WHY:   Repository delegates to data source for actual HTTP calls.

STEP 4  NoteRemoteDatasource serializes note for sync
├─ WHO:   NoteRemoteDatasource.syncNote()  in  lib/features/note_assist/data/remote/note_remote_datasource.dart  line 15
├─ CALLS: toJson() on ExtractedFields  in  lib/features/note_assist/data/remote/note_remote_datasource.dart  line 24
└─ WHY:   Prepares note data for HTTP POST body.

STEP 5  HTTP POST to backend sync endpoint is commented out
├─ WHO:   NoteRemoteDatasource.syncNote()  in  lib/features/note_assist/data/remote/note_remote_datasource.dart  line 32
⚠️ NOT WIRED: Dio.post('/api/doctor-notes/sync', data: body) is commented out at line 32.
⚠️ NOT WIRED: Backend route routes/api/doctor-notes/sync.dart does not exist in workspace.
```

**Key Files to Open**
- `lib/features/note_assist/presentation/cubit/note_editor_cubit.dart`
- `lib/features/note_assist/data/remote/note_sync_repository.dart`
- `lib/features/note_assist/data/remote/note_remote_datasource.dart`

**Status Badge**
❌ **NOT WIRED**

**Gaps**
🔧 GAP: Dio.post() for note sync is commented out in `note_remote_datasource.dart` line 32 — Fix: Uncomment the Dio.post() call and ensure the Dio instance is available (pass via constructor if needed).
🔧 GAP: Backend route for note sync is missing — Fix: Create `routes/api/doctor-notes/sync.dart` in the Dart Frog backend with a handler that receives note data and persists it to a database (not currently implemented).

---

### Feature 10 — Retry & Circuit Breaker

**Plain English Summary**
The app uses a `RetryInterceptor` attached to the shared Dio instance to automatically retry transient network failures (connection timeouts, 5xx errors) with exponential backoff. A `CircuitBreaker` is registered in GetIt but is never attached to Dio or used to wrap any remote API calls, so it provides no runtime protection.

**Call Chain**

```
STEP 1  CircuitBreaker instantiated and registered in GetIt
├─ WHO:   setupDependencies()  in  lib/main.dart  line 79
├─ CALLS: CircuitBreaker() constructor  in  lib/main.dart  line 79
└─ WHY:   Creates circuit breaker instance for potential use in fault tolerance.

STEP 2  RetryInterceptor attached to shared Dio
├─ WHO:   setupDependencies()  in  lib/main.dart  line 90
├─ CALLS: dio.interceptors.add(RetryInterceptor(dio))  in  lib/main.dart  line 90
└─ WHY:   Ensures transient network failures are automatically retried.

STEP 3  RetryInterceptor checks if error is retryable
├─ WHO:   RetryInterceptor.onError()  in  lib/core/network/retry_interceptor.dart  line 29
├─ CALLS: _shouldRetry(err) on RetryInterceptor  in  lib/core/network/retry_interceptor.dart  line 30
└─ WHY:   Determines if the failed request can be safely retried.

STEP 4  _shouldRetry checks HTTP status codes and methods
├─ WHO:   RetryInterceptor._shouldRetry()  in  lib/core/network/retry_interceptor.dart  line 65
├─ CALLS: statusCode check (5xx, connection timeout, receive timeout)  in  lib/core/network/retry_interceptor.dart  line 73
├─ CALLS: _retryableMethods.contains(method)  in  lib/core/network/retry_interceptor.dart  line 81
└─ WHY:   Retries GET, HEAD, OPTIONS, PUT, DELETE by default; POST only if extra['_retryable'] == true.

STEP 5  RetryInterceptor replays request on retryable errors
├─ WHO:   RetryInterceptor.onError()  in  lib/core/network/retry_interceptor.dart  line 29
├─ CALLS: Dio.fetch()  in  lib/core/network/retry_interceptor.dart  line 58
└─ WHY:   Re-executes the failed request after backoff delay.

STEP 6  CircuitBreaker logic exists but is unused
├─ WHO:   CircuitBreaker.call()  in  lib/core/network/circuit_breaker.dart  line 36
├─ CALLS: throws CircuitBreakerOpenException()  in  lib/core/network/circuit_breaker.dart  line 46
└─ WHY:   Would prevent requests when circuit is open (after repeated failures), but is never invoked.
⚠️ NOT WIRED: CircuitBreaker is registered in GetIt (lib/main.dart line 79) but not attached to Dio or used to wrap any remote API calls.

STEP 7  CircuitBreaker cooldown tracking exists
├─ WHO:   CircuitBreaker._onFailure()  in  lib/core/network/circuit_breaker.dart  line 74
├─ CALLS: DateTime.now()  in  lib/core/network/circuit_breaker.dart  line 79
└─ WHY:   Sets cooldown period after which circuit transitions from open to half-open.
```

**Key Files to Open**
- `lib/core/network/retry_interceptor.dart`
- `lib/core/network/circuit_breaker.dart`
- `lib/main.dart`

**Status Badge**
⚠️ **PARTIALLY WIRED**

**Gaps**
🔧 GAP: CircuitBreaker is registered but never used — Fix: Attach CircuitBreaker to Dio as an interceptor in `main.dart` line 90 alongside RetryInterceptor, or wrap CloudLlmAdapter's Dio calls with CircuitBreaker.call().

---

---

## Section 6: Known Gaps — Consolidated Fix Plan

| ID | Feature | What is missing | File where fix goes | Effort | Priority |
|----|---------|-----------------|----------------------|--------|----------|
| GAP-1 | 2 — Clinical Processing Dispatch | No ClinicalProcessingRemoteDatasource; dispatch via CloudLlmAdapter only | `lib/features/note_assist/data/remote/` | M | P2 |
| GAP-2 | 4 — LLM Adapter Selection | Misleading comment in middleware | `routes/_middleware.dart` line 27 | S | P1 |
| GAP-3 | 5 — Response Propagation | `ClinicalProcessingResponse.fromJson()` missing | `lib/core/dto/clinical_processing_response.dart` | S | P0 |
| GAP-4 | 5 — Response Propagation | CloudLlmAdapter bypasses DTO parsing | `lib/core/llm/cloud_llm_adapter.dart` line 28 | S | P0 |
| GAP-5 | 6 — On-Device LLM Path | Android model verification is TODO | `lib/features/model_manager/presentation/cubit/model_manager_cubit.dart` line 194 | M | P1 |
| GAP-6 | 6 — On-Device LLM Path | Android model download is commented out | `lib/features/model_manager/presentation/cubit/model_manager_cubit.dart` lines 210-221 | M | P1 |
| GAP-7 | 7 — Note Persistence | No dedicated Drift DAO class | `lib/features/note_assist/data/local/` | M | P2 |
| GAP-8 | 8 — Android Emulator URL | Shared Dio always uses apiBaseUrl | `lib/main.dart` line 82-90 | S | P0 |
| GAP-9 | 9 — Note Sync | Dio.post() for sync commented out | `lib/features/note_assist/data/remote/note_remote_datasource.dart` line 32 | S | P0 |
| GAP-10 | 9 — Note Sync | Backend route missing | `routes/api/doctor-notes/sync.dart` | M | P0 |
| GAP-11 | 10 — Retry & Circuit Breaker | CircuitBreaker never attached to Dio | `lib/main.dart` line 90 | S | P1 |

**Priority Legend:**
- **P0**: Blocks end-to-end testing or core functionality. Must fix before any integration testing.
- **P1**: Needed for full feature functionality. Should fix before Milestone 2.
- **P2**: Technical debt / nice-to-have. Can defer past initial release.

**Effort Legend:**
- **S**: < 1 hour (simple uncomment, add method, or configuration change)
- **M**: 1-4 hours (new file, moderate logic, or integration)
- **L**: > 4 hours (significant new feature or refactor)

---

---

## Section 7: Key Files Quick Reference

| File | Purpose | Layer | When to open it |
|------|---------|-------|-----------------|
| `lib/main.dart` | App entry point; GetIt DI setup; Dio configuration with baseUrl and interceptors | Core | Start here for app initialization and dependency wiring |
| `lib/core/config/environment.dart` | Environment-based configuration: apiBaseUrl, cloudLlmEnabled, androidEmulatorApiUrl | Core | When debugging connectivity or environment-specific behavior |
| `lib/core/llm/hybrid_llm_adapter.dart` | Manages LLM fallback chain: native → cloud → stub; implements _withFallback() | Core | For understanding on-device vs cloud routing logic |
| `lib/core/llm/cloud_llm_adapter.dart` | Cloud LLM adapter; POSTs to backend /api/v1/clinical-processing/process via Dio | Core | For backend API calls from the app |
| `lib/core/llm/llm_port_factory.dart` | Factory for creating LlmPort (HybridLlmAdapter) with environment-based configuration | Core | For LLM adapter selection and Android emulator URL handling |
| `lib/core/llm/android_native_llm_adapter.dart` | Android-specific LLM adapter using flutter_gemma plugin for on-device inference | Core | For on-device LLM implementation on Android |
| `lib/core/network/retry_interceptor.dart` | Dio interceptor for automatic retries on transient failures | Core | For network resilience configuration |
| `lib/core/network/circuit_breaker.dart` | Circuit breaker implementation (registered but unused) | Core | For fault tolerance (currently needs wiring) |
| `lib/core/ports/llm_port.dart` | LLM port interface: processText(inputText, ProcessingMode) | Core | For understanding the LLM abstraction contract |
| `lib/features/note_assist/presentation/pages/note_editor_page.dart` | Main note editing screen; microphone FAB, text editor, SuggestionPanel | Presentation | For voice capture, text editing, and AI suggestion UI |
| `lib/features/note_assist/presentation/cubit/ai_assist_cubit.dart` | Manages AI text processing state (suggestion in-progress/ready) | Presentation | For AI workflow state management |
| `lib/features/note_assist/presentation/cubit/note_editor_cubit.dart` | Manages note state (rawText, auto-save, sync triggering) | Presentation | For note editing and persistence logic |
| `lib/features/note_assist/data/services/on_device_llm_service.dart` | Domain service for LLM text processing; delegates to LlmPort | Data | For understanding how domain layer uses LLM |
| `lib/features/note_assist/data/local/note_local_repository.dart` | Drift-based repository for saving/loading DoctorNote entities | Data | For local persistence logic |
| `lib/features/note_assist/data/remote/note_remote_datasource.dart` | Remote data source for note sync (POST commented out) | Data | For backend sync (needs implementation) |
| `lib/core/services/local_speech_service.dart` | speech_to_text plugin wrapper for native speech recognition | Core | For voice capture implementation |
| `routes/_middleware.dart` | Dart Frog middleware; provides ClinicalProcessingOrchestrator and LLM dependencies | Backend Infrastructure | For backend DI wiring |
| `routes/api/v1/clinical-processing/process.dart` | Dart Frog route handler for clinical processing POST | Backend Handlers | For backend API endpoint logic |
| `lib/application/services/clinical_processing_orchestrator.dart` | Orchestrates clinical processing: validation, routing by ProcessingMode | Backend Application | For understanding backend business logic flow |
| `lib/infrastructure/llm/ollama_llm_adapter.dart` | Ollama LLM adapter; HTTP client for local Ollama API | Backend Infrastructure | For backend LLM integration |

---

---

## Section 8: Running the Project Locally

### Prerequisites Checklist

- [ ] **Dart SDK 3.x** installed
- [ ] **Flutter SDK 3.x** installed (for `doctor_app`)
- [ ] **Dart Frog CLI** installed (`dart pub global activate dart_frog_cli`)
- [ ] **Ollama** installed and running (optional, for local LLM; stub mode works without it)
- [ ] **Android Studio / Xcode** (for mobile app)
- [ ] **Android emulator** or physical device (for `doctor_app`)

---

### Step 1: Start the Backend (clinical-intelligence-dart)

```bash
# Navigate to backend directory
cd /path/to/EdgeLLMHub/projects/apps/clinical-intelligence-dart

# Install dependencies
dart pub get

# Start Dart Frog dev server (defaults to port 8080)
dart_frog dev
```

**Verify Backend is Running:**
- Open `http://localhost:8080/api/v1/clinical-processing/process` in Postman/curl
- Send POST with body: `{"inputText": "Patient presents with fever", "processingMode": "cleanTranscript"}`
- Expect: 200 OK with `processedText` field (if Ollama is running) or error (if Ollama is not running)

**Ollama Setup (Optional):**
```bash
# Install Ollama (macOS/Linux)
curl -fsSL https://ollama.com/install.sh | sh

# Pull a compatible model (Gemma 2B recommended for testing)
ollama pull gemma:2b

# Start Ollama server
ollama serve

# Verify Ollama is running
curl http://localhost:11434/api/tags
# Should return: {"models":[{"name":"gemma:2b",...}]}
```

**Stub Mode:**
- If Ollama is not running, the backend will fail to process requests (no stub adapter is active in middleware)
- To enable stub: Modify `routes/_middleware.dart` line 26 to use `StubLlmAdapter()` instead of `OllamaLlmAdapter()`

---

### Step 2: Start the Mobile App (doctor_app)

```bash
# Navigate to app directory
cd /path/to/EdgeLLMHub/projects/apps/doctor_app

# Install dependencies
flutter pub get

# Run on Android emulator (replace <emulator-name> with your AVD)
flutter run -d <emulator-name> \
  --dart-define=API_URL=http://10.0.2.2:8080 \
  --dart-define=CLOUD_LLM_ENABLED=true

# Run on physical Android device (use actual device IP)
flutter run -d <device-id> \
  --dart-define=API_URL=http://<your-local-ip>:8080 \
  --dart-define=CLOUD_LLM_ENABLED=true

# Run on iOS simulator
flutter run -d iPhone \
  --dart-define=API_URL=http://localhost:8080 \
  --dart-define=CLOUD_LLM_ENABLED=true
```

**Android Emulator URL Note:**
- Use `10.0.2.2` to reach `localhost` from Android emulator
- **Current Issue:** The app's shared Dio instance in `main.dart` does not automatically use the emulator URL (see GAP-8). Workaround: Manually set `--dart-define=API_URL=http://10.0.2.2:8080`

**On-Device LLM (Android):**
- Requires `flutter_gemma` plugin and Google AI Edge
- Models must be downloaded via the model manager (currently TODO/placeholder — see GAP-5, GAP-6)
- Set `--dart-define=CLOUD_LLM_ENABLED=false` to force on-device only

**Stub Mode (Offline):**
- Set `--dart-define=CLOUD_LLM_ENABLED=false` and do not start backend
- The app will use `StubLlmAdapter` for static responses

---

### Step 3: Test the End-to-End Flow

1. **Start backend:** `dart_frog dev` in `clinical-intelligence-dart/`
2. **Start Ollama:** `ollama serve` (optional, or use stub)
3. **Run app:** `flutter run` with appropriate `--dart-define` flags
4. **Test voice capture:**
   - Tap microphone FAB in note editor
   - Speak a test phrase (e.g., "Patient has a cough")
   - Verify text appears in editor
5. **Test clinical processing:**
   - Tap "Clean up" in AI toolbar
   - Verify processed text appears in SuggestionPanel
   - Tap "Accept" to merge into note
6. **Test auto-save:**
   - Edit note text
   - Close and reopen app
   - Verify note is restored from Drift

---

### Step 4: Verify Ollama vs Stub Mode

| Mode | Backend Config | App Config | Expected Behavior |
|------|-----------------|------------|-------------------|
| **Ollama** | `OllamaLlmAdapter()` in middleware | `CLOUD_LLM_ENABLED=true` | Backend sends requests to local Ollama; app receives dynamic responses |
| **Stub** | `StubLlmAdapter()` in middleware | Any | Backend returns static responses; no Ollama required |
| **On-Device** | Any | `CLOUD_LLM_ENABLED=false` | App uses `AndroidNativeLlmAdapter` (flutter_gemma) for local inference; backend not called |

---

---

## Section 9: Glossary

| Term | Definition | Where It's Used |
|------|------------|-----------------|
| **BLoC** | Business Logic Component — Flutter state management pattern using events, states, and a BLoC class. Cubit is a simplified version with single state stream. | `doctor_app` presentation layer |
| **Cubit** | Simplified BLoC with a single state stream and no events. Used in EdgeLLMHub for state management (e.g., `NoteEditorCubit`, `AiAssistCubit`). | `doctor_app` presentation layer |
| **Clean Architecture** | Software design philosophy with concentric layers (Presentation → Domain → Data) where inner layers have no knowledge of outer layers. Dependency rule: Inner → Outer only. | `doctor_app` architecture |
| **Hexagonal Architecture** | AKA Ports-and-Adapters. Application core (domain + application) is isolated from external systems (infrastructure) via interfaces (ports) and implementations (adapters). | `clinical-intelligence-dart` architecture |
| **LlmPort** | Interface defining the LLM contract: `processText(inputText, ProcessingMode)`. Concrete adapters implement this. | `lib/core/ports/llm_port.dart` |
| **HybridLlmAdapter** | LLM adapter that implements a fallback chain: tries native on-device first, then cloud (if enabled), then stub. | `lib/core/llm/hybrid_llm_adapter.dart` |
| **ProcessingMode** | Enum defining the type of clinical text processing: `cleanTranscript` (clean up raw dictation), `vocabAssist` (medical terminology assistance). | `lib/core/ports/llm_port.dart`, `clinical_processing_orchestrator.dart` |
| **PHI** | Protected Health Information — any data that can identify a patient. EdgeLLMHub prioritizes on-device processing to keep PHI local. | Core design principle |
| **Drift** | Reactive persistence library for Flutter/Dart. Generates type-safe SQLite database access code. | `doctor_app` data layer |
| **Dart Frog** | Lightweight Dart backend framework for building REST APIs. Uses `provider()` for dependency injection. | `clinical-intelligence-dart` |
| **provider()** | Dart Frog's dependency injection mechanism. Services are provided in middleware and read from handlers via `context.read<T>()`. | `clinical-intelligence-dart` middleware and handlers |
| **GetIt** | Service locator / DI container for Dart/Flutter. Used in `doctor_app` to register and resolve dependencies. | `doctor_app` `main.dart` |
| **Dio** | Powerful HTTP client for Dart. Used in `doctor_app` for backend API calls with interceptors. | `doctor_app` network layer |
| **CircuitBreaker** | Fault tolerance pattern that "opens" after repeated failures, preventing further calls until a cooldown period passes. | `lib/core/network/circuit_breaker.dart` |
| **RetryInterceptor** | Dio interceptor that automatically retries failed requests (based on HTTP method and status code) with exponential backoff. | `lib/core/network/retry_interceptor.dart` |
| **DoctorNote** | Domain entity representing a clinical note. Contains `rawText`, `consultationId`, `createdAt`, etc. | `doctor_app` domain layer |
| **ClinicalProcessingRequest** | DTO sent from app to backend. Contains `inputText` and `processingMode`. | `clinical-intelligence-dart` domain |
| **ClinicalProcessingResponse** | DTO returned from backend to app. Contains `processedText`, `processingMode`, `warnings`, `generatedAt`, `metadata`. | `clinical-intelligence-dart` domain |
| **VOCAB_ASSIST** | ProcessingMode for medical terminology assistance. Routes to `TerminologyAssistanceService` in backend. | Backend orchestrator |
| **CLEAN_TRANSCRIPT** | ProcessingMode for cleaning up raw dictation into structured clinical notes. Routes to `TranscriptCleanupService` in backend. | Backend orchestrator |
| **On-device LLM** | LLM inference happening locally on the mobile device (Android: Gemma via Google AI Edge; iOS: MLC). Preserves PHI by not sending data to cloud. | `doctor_app` LLM layer |
| **Cloud LLM fallback** | When on-device LLM is unavailable and `cloudLlmEnabled` is true, the app falls back to calling the backend, which uses Ollama. | `HybridLlmAdapter._withFallback()` |
| **Stub adapter** | Fallback LLM adapter that returns static/predefined responses when both on-device and cloud are unavailable. | `StubLlmAdapter` |
