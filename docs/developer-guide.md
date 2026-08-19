# Developer Guide

A practical guide for contributing to EdgeLLMHub: how the codebase wants to be extended, not just what it currently contains.

> **A note on scope**: the architecture, code, and known issues sections throughout this documentation set are grounded directly in source material (architecture reviews, audits, an implementation walkthrough). Branch strategy, PR process, and review checklist below are **not documented anywhere in that source material** — they're written as reasonable conventions consistent with the codebase's own architectural discipline (ports/adapters, typed exceptions, explicit test coverage for fallback logic). Treat them as a recommended starting point, and adjust to match whatever the maintainers actually practice.

---

## Table of Contents

- [Architecture Philosophy](#architecture-philosophy)
- [Code Style](#code-style)
- [Folder Structure](#folder-structure)
- [How to Add a Feature](#how-to-add-a-feature)
- [How to Add an API (Backend Route)](#how-to-add-an-api-backend-route)
- [How to Add an LLM Adapter](#how-to-add-an-llm-adapter)
- [How to Add a Cubit](#how-to-add-a-cubit)
- [Testing](#testing)
- [Debugging](#debugging)
- [Branch Strategy](#branch-strategy)
- [PR Guidelines](#pr-guidelines)
- [Coding Standards](#coding-standards)
- [Review Checklist](#review-checklist)

---

## Architecture Philosophy

Three principles run through every subsystem in this codebase, and any new code should hold to the same ones:

1. **Depend on ports, not adapters.** Every place the system talks to something external and swappable (an LLM, a data store, a network client) is expressed as an interface (`LlmPort`, `TranscriptRepository`, `SpeechService`), with concrete implementations behind it. New code should extend an interface, not reach past one.
2. **Distinguish permanent failure from transient failure.** `HybridLlmAdapter`'s tier-disabling logic exists specifically because retrying a permanently broken dependency forever, or permanently abandoning a healthy one after one bad response, are both wrong. Any new resilience logic should make the same distinction explicitly, not treat "it failed" as a single undifferentiated case.
3. **Name the tradeoff, don't hide it.** Every major design decision in [`architecture.md`](architecture.md) states what it costs, not just what it buys. New architectural decisions should be documented the same way — a decision without a stated cost usually means the cost wasn't thought through, not that there wasn't one.

## Code Style

- **Dart**: standard `dart format` / `dart analyze` conventions. The codebase favors explicit typed exceptions (`AppException` subtypes) over bare `Exception` or `String` error messages — new error paths should follow the existing hierarchy rather than introducing a new one.
- **Java**: standard Micronaut/Java conventions; JUnit 5 + Mockito for tests, matching the existing `clinical-intelligence` service.
- **Naming**: adapters are suffixed `*Adapter` (`OllamaLlmAdapter`, `CloudLlmAdapter`); ports are suffixed `*Port` or `*Repository`; Cubits are suffixed `*Cubit`.

## Folder Structure

See [`mobile.md`](mobile.md#project-structure) and [`backend.md`](backend.md#hexagonal-architecture) for the current, full folder trees. The short version: `core/` (or `lib/application` + `lib/infrastructure` on the backend) holds cross-cutting concerns; `features/<feature_name>/` holds everything specific to one feature, itself layered `presentation/domain/data`.

## How to Add a Feature

1. Create `lib/features/<feature_name>/` with `presentation/`, `domain/`, `data/` subfolders — mirroring `note_assist/`.
2. Define the feature's service interface in `domain/services/`. Don't let `presentation/` import anything from `data/` directly.
3. If the feature needs LLM access, depend on the existing `LlmPort` from `core/` rather than creating a feature-local LLM client — this is exactly the kind of cross-feature dependency `core/` exists to hold.
4. Wire the new service into `main.dart`'s GetIt registration, following the existing pattern in that file.
5. Add unit tests alongside the existing suite structure (see [Testing](#testing)).

## How to Add an API (Backend Route)

Dart Frog's file-based routing means a new route is a new file:

1. Add `routes/api/v1/<resource>/<action>.dart`, matching the existing pattern in `routes/api/v1/clinical-processing/` and `routes/api/v1/transcript-summary/`.
2. Keep the route handler thin — it should parse the request, call into an orchestrator or service from `lib/application/services/`, and shape the response. Business logic belongs in the application layer, not the route file.
3. If the route needs a new external dependency, define a port in `lib/application/ports/` first, then an adapter in `lib/infrastructure/`. Don't call an SDK or `HttpClient` directly from a route or orchestrator.
4. **Until the authentication/authorization roadmap in [`security.md`](security.md) is implemented, treat every new route as unauthenticated by default** — this is not a hypothetical, it's the system's actual current state, and new routes inherit that risk unless you explicitly add the auth layer described there.

## How to Add an LLM Adapter

This is the pattern the codebase is best set up to extend cleanly:

1. Implement `LlmPort` (the same five-method interface used by every existing adapter — see [`architecture.md`](architecture.md#domain-model)).
2. Decide where it sits in the fallback chain, if it should be part of `HybridLlmAdapter` at all, versus being a standalone adapter used directly (as `OllamaLlmAdapter` is on the backend).
3. Distinguish permanent vs. transient failure modes for the new adapter explicitly, using the existing `AppException` hierarchy (`LlmInitializationException`, `UnsupportedPlatformException` for permanent; a bare `LlmException` for transient) — see [`mobile.md`](mobile.md#hybrid-llm-adapter) for the exact pattern `HybridLlmAdapter` expects.
4. Add a dedicated test file (`<adapter_name>_test.dart`) following the shape of `stub_llm_adapter_test.dart` or `hybrid_llm_adapter_test.dart` — specifically covering the no-throw guarantee (if applicable) and the fallback behavior on each documented exception type.
5. If this is a new **remote** adapter, reuse `RetryInterceptor`/`CircuitBreaker` on the mobile side, or add equivalent resilience on the backend side (currently absent for the Ollama call path — see [`backend.md`](backend.md#circuit-breaker) — don't let a new backend adapter repeat that gap).

## How to Add a Cubit

1. Define states as a sealed/`Equatable` hierarchy, matching the existing pattern in `NoteEditorCubit`/`AiAssistCubit`.
2. If the Cubit holds a `StreamSubscription`, cancel it explicitly in `close()` **and** cancel any previous subscription before starting a new one — `AiAssistCubit`'s original bug (a window where two subscriptions were briefly both active) is exactly the failure mode to avoid here.
3. If the Cubit does debounced work against async state (autosave, sync), re-read `state` **after** the async call completes rather than closing over a value captured when the timer was scheduled — see [`mobile.md`](mobile.md#cubits) for the exact bug this pattern avoids in `NoteEditorCubit`.
4. Register the Cubit with GetIt or provide it via `BlocProvider` at the point it's needed — don't reach for a global singleton unless the state is genuinely app-wide.

## Testing

- Mobile: `flutter test`, using `mocktail` for test doubles — matching the existing convention across both Dart repos.
- Java: `./gradlew test` (JUnit 5 + Mockito).
- **Prioritize fallback-logic and migration tests** — the codebase's own existing coverage (`circuit_breaker_test.dart`, `hybrid_llm_adapter_test.dart`, `local_database_migration_test.dart`) targets exactly the two categories of bug that are hardest to catch by manual testing, and new code in those categories should follow the same discipline.
- **Integration tests spanning mobile ↔ backend are a known, standing gap** (see [`scalability.md`](scalability.md#testing-at-scale)) — if you're touching the contract between `doctor_app` and `clinical-intelligence-dart`, a real end-to-end test is disproportionately valuable precisely because nothing currently catches drift at that seam.

## Debugging

- Mobile LLM issues: check `HybridLlmAdapter`'s tier-availability flags first — a tier that failed permanently earlier in the session will not be retried, which can look like a bug but is the intended behavior.
- Backend/Ollama issues: check `ollama.log` and `server.log` directly — there's no structured logging or correlation ID yet (see [`deployment.md`](deployment.md#logging)), so tracing a single request across mobile → backend → Ollama currently means manually correlating timestamps across three log sources.
- iOS Simulator: remember that on-device LLM inference and native speech-to-text **cannot run** in the Simulator at all — a failure there is expected, not a regression, unless it's specifically a fallback-routing bug.

## Branch Strategy

*(Recommended — not confirmed from source material.)* A trunk-based flow with short-lived feature branches (`feature/<short-description>`, `fix/<short-description>`) fits this codebase's size and the modularity of its port/adapter boundaries well — most changes should be scoped to one adapter, one Cubit, or one route, which keeps branches naturally small.

## PR Guidelines

*(Recommended — not confirmed from source material.)*
- State which layer(s) a PR touches (presentation/domain/data, or route/application/infrastructure) — this maps directly onto the architecture and makes review scope obvious.
- If a PR touches `StructuredSummary`, `ProcessingMode`, or `ClinicalPrompts`, **flag explicitly whether the corresponding file in the other Dart repository also needs updating** — this is the platform's single most well-documented structural risk (see [`architecture.md`](architecture.md#design-decisions)), and it currently has no automated check.
- Include the test file alongside the implementation, not as a follow-up.

## Coding Standards

- New exceptions extend `AppException`, not a bare `Exception`.
- New external dependencies are wrapped in a port/adapter pair — no direct SDK calls from application or presentation code.
- New LLM-facing prompts stay consistent with the existing conservative posture (low temperature, explicit "do not invent" constraints) — see [`architecture.md`](architecture.md#design-decisions).

## Review Checklist

- [ ] Does this change depend on a port, or does it reach past one into a concrete implementation?
- [ ] If this touches shared contracts (`StructuredSummary`, `ProcessingMode`, `ClinicalPrompts`, `LlmPort`), has the duplicate in the other repository been updated too?
- [ ] If this adds a new failure mode, is it classified as permanent or transient, consistent with the existing `AppException` hierarchy?
- [ ] If this adds a new backend route, does it acknowledge the current lack of authentication rather than silently assuming a future auth layer already exists?
- [ ] Are new Cubits free of the two documented historical bug patterns (stale state in debounced callbacks, unguarded subscription overlap)?
- [ ] Is there a test, and does it cover the failure path, not just the happy path?

---

**Next:** [`diagrams/`](../diagrams/) — standalone Mermaid diagram sources referenced throughout this documentation set.