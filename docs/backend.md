# Backend — `clinical-intelligence-dart`

A Dart Frog service that acts as the mobile app's cloud-tier LLM fallback: it receives cleaned or raw transcript text, routes it through the appropriate clinical processing pipeline, and forwards LLM calls to a local Ollama instance. This document covers its REST surface, its Hexagonal (Ports and Adapters) structure, and — deliberately prominently — the gaps that currently make it unsuitable for production PHI traffic.

---

## Table of Contents

- [REST Architecture](#rest-architecture)
- [Hexagonal Architecture](#hexagonal-architecture)
- [Ports](#ports)
- [Adapters](#adapters)
- [DTOs](#dtos)
- [Services](#services)
- [Orchestrators](#orchestrators)
- [Clinical Pipeline](#clinical-pipeline)
- [Ollama Integration](#ollama-integration)
- [Streaming](#streaming)
- [Retry](#retry)
- [Circuit Breaker](#circuit-breaker)
- [Validation](#validation)
- [Error Handling](#error-handling)
- [Scalability](#scalability)
- [Future Improvements](#future-improvements)

---

## REST Architecture

Dart Frog's file-based routing maps directly to HTTP endpoints:

```
routes/
├── index.dart
└── api/v1/
    ├── clinical-processing/
    │   └── process.dart                          # POST — run the full processing pipeline
    └── transcript-summary/
        └── [consultationId]/
            ├── index.dart                          # GET — fetch a summary
            └── regenerate.dart                     # POST — regenerate a summary
```

The server runs at `http://127.0.0.1:8080` in local development. There is currently **no environment-based configuration** documented for staging or production hosts — the mobile client's base URL was, at least at one point, hardcoded to `localhost`, which does not resolve from a physical device (see [`mobile.md`](mobile.md)).

## Hexagonal Architecture

The backend is structured as Ports and Adapters end to end:

```
API Layer (Dart Frog routes)
        ↓
Application Layer (orchestrators, services) ── depends only on ports
        ↓
Infrastructure Layer (adapters) ── implements the ports
```

```
lib/
├── api/dto/                      # Request/response DTOs
├── application/
│   ├── ports/
│   │   ├── llm_port.dart          # Same contract as doctor_app's LlmPort
│   │   └── transcript_repository.dart
│   └── services/
│       ├── clinical_processing_orchestrator.dart
│       ├── summary_orchestrator.dart
│       ├── summary_generation_service.dart
│       └── doctor_note_generation_service.dart
├── core/models/
│   ├── structured_summary.dart    # Duplicated from doctor_app, not shared
│   └── processing_mode.dart
└── infrastructure/
    └── llm/
        ├── ollama_llm_adapter.dart
        ├── stub_llm_adapter.dart
        └── prompts/clinical_prompts.dart  # Also duplicated, word for word
```

The application layer never imports `dart:io`'s `HttpClient` or anything Ollama-specific directly — it depends on `LlmPort`. This is *why* adding a hosted inference API later is additive (a new adapter class) rather than a rewrite of `ClinicalProcessingOrchestrator`.

## Ports

`LlmPort` is defined identically in both Dart repositories (see [`architecture.md`](architecture.md#domain-model) for the full interface). `TranscriptRepository` is the persistence port — currently satisfied only by an in-memory adapter (see [Scalability](#scalability)).

## Adapters

| Adapter | Role |
|---|---|
| `OllamaLlmAdapter` | Talks to a local Ollama instance for all real inference |
| `StubLlmAdapter` | Default backend adapter — used when no real LLM is configured, or as a dev/test double |
| `InMemoryTranscriptRepository`, `InMemorySummaryRepository` | `Map`-backed persistence — see [Scalability](#scalability) for why this is a hard limit, not a minor inefficiency |

## DTOs

`ClinicalProcessingRequest` / `ClinicalProcessingResponse` and `TranscriptSummaryRequest` / `TranscriptSummaryResponse` live under `lib/api/dto/`. **Field-level schemas for these DTOs are not available in the current documentation set** — this document intentionally does not invent them. If you're integrating against these routes, read the DTO source directly rather than relying on this page for exact field names.

## Services

- `SummaryGenerationService` — produces a `StructuredSummary` from a transcript.
- `DoctorNoteGenerationService` — produces a free-text doctor's note.
- `TranscriptCleanupService` — text cleanup, mirroring the mobile app's `cleanTranscript` processing mode.
- `TerminologyAssistanceService` — named in the project overview; specific behavior not detailed in available source material.

## Orchestrators

`ClinicalProcessingOrchestrator` is the entry point for `/api/v1/clinical-processing/process`: it inspects the requested `ProcessingMode` and routes the transcript through the matching service. `SummaryOrchestrator` backs the `/transcript-summary/*` routes specifically.

A specific, documented gap: the backend **does** have a `TranscriptChunkingService` for handling long transcripts, but it is currently **only wired into the `SummaryOrchestrator` path** — the mobile app's direct `processText` calls do not go through it. Long consultations can silently truncate or degrade on that path with no warning to the doctor.

## Clinical Pipeline

```
Dart Frog route → Orchestrator → Service → LlmPort → OllamaLlmAdapter → Ollama
```

For a structured summary specifically, the orchestrator assembles the `ClinicalPrompts.structuredSummary` prompt, calls the port, and parses the model's response into the seven-field `StructuredSummary` shape shared with the mobile app.

## Ollama Integration

```dart
class OllamaLlmAdapter implements LlmPort {
  OllamaLlmAdapter({
    this.baseUrl = 'http://127.0.0.1:11435',
    this.model = 'llama3.2',
    this.temperature = 0.1,   // clinical safety: conservative generation
  });

  Future<String> _generate(String prompt) async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('$baseUrl/api/generate'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
      'options': {'temperature': temperature},
    }));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return (jsonDecode(body)['response'] as String?).trim();
  }
}
```

Two specific, documented issues with this integration:

1. **Uses `/api/generate`, not `/api/chat`.** The generate endpoint has no structural notion of separate system/user roles — everything is one flat prompt string. This means there's no real trust boundary between trusted instructions and untrusted transcript text baked into the request format itself; prompt-injection defense has to do all the work at the string level. Switching to `/api/chat` with genuine role separation is a P1 fix (see [`security.md`](security.md)).
2. **A new `HttpClient()` is created on every call.** This is a real, if lower-severity, inefficiency — connection setup latency paid on every single request instead of once for a long-lived client instance.

## Streaming

The mobile app's on-device (native) tier streams tokens as they're generated (via `EventChannel`, see [`mobile.md`](mobile.md)). The cloud path through this backend does **not** — `'stream': false` is hardcoded in the Ollama request above, and the HTTP response is non-streaming end to end. A doctor who falls back to cloud gets a materially worse, silently-blocking-for-seconds experience with no architectural reason for the difference. The identified fix: set `'stream': true` on the Ollama request and forward chunks to the client via Server-Sent Events from Dart Frog.

## Retry

**There is currently no retry logic on the backend's Ollama calls.** Retry-with-backoff exists on the *mobile* side (`RetryInterceptor`, applied to calls the mobile app makes to this backend — see [`mobile.md`](mobile.md)), but nothing retries a failed or slow call from this backend to Ollama itself. This asymmetry means a transient Ollama hiccup surfaces to the mobile app as a single failed cloud-tier attempt rather than being absorbed here.

## Circuit Breaker

Similarly, **no circuit breaker exists on the backend today.** The mobile app has one (`CircuitBreaker`, 5-failure threshold, 30-second cooldown, three-state closed/open/half-open machine) protecting its calls *into* this backend — but nothing here protects this backend's calls *into* Ollama. Under concurrent load, a struggling Ollama instance has no circuit-breaking mechanism stopping this backend from continuing to hammer it. This is a named P0/P1-adjacent gap in the failure-recovery design — see [`scalability.md`](scalability.md).

## Validation

Input validation on the backend is minimal relative to the mobile app's `InputValidator` (length limits, charset sanitization, injection-pattern detection with clinical false-positive prevention — see [`mobile.md`](mobile.md)). The backend currently relies on a payload size limit (10MB) as the primary defense; there's no dedicated backend-side prompt-injection or content-filtering layer distinct from what the mobile app already applies before the request arrives. Because the backend has no authentication, this also means **any client**, not just the doctor_app, can currently reach these routes with unvalidated input — see [Error Handling](#error-handling) and [`security.md`](security.md).

## Error Handling

There is no unified backend exception hierarchy comparable to the mobile app's `AppException` tree. Failures largely surface as generic errors up through the route handlers. Combined with the missing retry/circuit-breaker layers above, this means a struggling Ollama instance or a malformed request tends to produce an undifferentiated failure rather than a typed, actionable one.

## Scalability

The backend's most consequential architectural fact: **all persistence is in-memory**.

```dart
// InMemoryTranscriptRepository, InMemorySummaryRepository
// backed by plain Dart Map objects
```

This has two direct, severe consequences:
- **Zero horizontal scalability.** You cannot run multiple instances behind a load balancer — a request to instance A has no knowledge of data written to instance B.
- **Data volatility.** Any restart, crash, or deployment permanently deletes every transcript and summary that hasn't already synced elsewhere.

The second bottleneck, once persistence is fixed: **LLM concurrency**. A single local Ollama instance serializes or OOMs under concurrent load — 20 doctors hitting the backend simultaneously will either queue behind each other (causing timeouts) or crash the process. A dedicated, load-balanced inference layer (vLLM, or a managed cloud inference API) is the identified fix once concurrent load justifies it. Full tier-by-tier detail in [`scalability.md`](scalability.md).

Asynchronous I/O (Dart Frog's non-blocking request handling) is a genuine strength here — the backend doesn't block its own thread waiting on Ollama, so it can hold many concurrent connections open even though it can't yet fan work out across multiple Ollama-backed processes.

## Future Improvements

In priority order, consolidated from the security and scalability reviews:

1. **Postgres migration** — replace `InMemoryTranscriptRepository`/`InMemorySummaryRepository`; this is a P0 item needed even at pilot scale, not just for growth.
2. **Authentication and object-level authorization** on every route — see [`security.md`](security.md).
3. **Fail-closed compliance gate** on the mobile side, but verified/enforced consistently with whatever this backend accepts.
4. **Switch to `/api/chat`** with real role separation; strengthen prompt-injection defenses.
5. **Add retry-with-backoff and a circuit breaker** around the Ollama call path — currently entirely absent on the backend side.
6. **Streaming parity** — set `'stream': true` and forward via SSE, matching the native tier's UX.
7. **Wire `TranscriptChunkingService` into the direct `processText` path**, not just the summary orchestrator.
8. **Reuse a single long-lived `HttpClient`** instead of constructing one per Ollama call.
9. **Add rate limiting and per-doctor quotas** ahead of the 100k-user tier, not after.
10. **Add an integration test suite** that drives a real Dart Frog instance end to end — none currently exists spanning mobile ↔ backend.

