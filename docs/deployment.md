# Deployment

This document covers local development, containerization, CI/CD, and production deployment across all three systems. As with [`java-enterprise.md`](java-enterprise.md), some sections here describe **recommended target state**, not confirmed current implementation — each section says explicitly which it is.

---

## Table of Contents

- [Local Development](#local-development)
- [Docker](#docker)
- [Docker Compose](#docker-compose)
- [Flutter](#flutter)
- [Micronaut](#micronaut)
- [Dart Frog](#dart-frog)
- [Ollama](#ollama)
- [Google Cloud](#google-cloud)
- [Environment Variables](#environment-variables)
- [Secrets](#secrets)
- [GitHub Actions / CI-CD](#github-actions--cicd)
- [Production Deployment](#production-deployment)
- [Observability](#observability)
- [Monitoring](#monitoring)
- [Logging](#logging)
- [Backups](#backups)
- [Disaster Recovery](#disaster-recovery)

---

## Local Development

**Confirmed current topology**: everything runs on `127.0.0.1` — Dart Frog and Ollama on one developer machine, the Flutter app pointed at `http://localhost:8080`. This is explicitly called out in the platform's own scalability review as the honest starting point, not a simplification for this document.

```bash
git clone https://github.com/RADICAL-devp/EdgeLLMHub.git
cd EdgeLLMHub
```

## Docker

**Confirmed**: the Java `clinical-intelligence` service ships a `docker-compose.yml` for local Qdrant. **Recommended, not confirmed as implemented**: Dockerfiles for the Dart Frog backend and the Java service as standalone deployable images. The platform's own deployment guidance is explicit that Dart Frog and the inference layer (Ollama/vLLM) should be **containerized separately** — Dart Frog is stateless, CPU-only, and cheap to replicate; the inference layer needs GPU-attached infrastructure and independent scaling. Coupling them in one container, as local dev implicitly does by running both on one machine, means you can't scale the cheap layer without also paying for GPUs you don't need.

## Docker Compose

```bash
cd projects/apps/clinical-intelligence
docker-compose up -d   # starts local Qdrant (confirmed)
```

No Compose file spanning all three systems (mobile build tooling aside, which isn't containerized) is confirmed to exist. A full local-stack Compose file — Qdrant + Dart Frog + Ollama — would be a reasonable addition; treat it as a suggested improvement, not a documented existing asset.

## Flutter

```bash
cd projects/apps/doctor_app
flutter pub get
flutter run
```

Physical-device requirements: **iOS A15+, 6GB+ RAM** for real on-device MLC inference (the Simulator cannot run it); Android devices supported via `flutter_gemma`. On a physical device, `localhost` will not resolve to your development machine — `EnvironmentConfig.apiBaseUrl` must point at your machine's LAN IP or a real deployed backend.

## Micronaut

```bash
./gradlew build
./gradlew :clinical-intelligence:run
```

Requires JDK 17+ and the Gradle wrapper. See [`java-enterprise.md`](java-enterprise.md) for prerequisites (Google Cloud credentials, OpenAI API key, running Qdrant).

## Dart Frog

```bash
cd projects/apps/clinical-intelligence-dart
dart pub get
dart_frog dev   # serves on http://127.0.0.1:8080
```

## Ollama

```bash
ollama serve                    # expected at http://127.0.0.1:11435 per OllamaLlmAdapter's default baseUrl
ollama pull llama3.2
```

Note this is a non-default Ollama port (`11435` rather than the more common `11434`) — confirmed from the adapter's own configuration, worth double-checking against your local Ollama install if you hit connection errors.

## Google Cloud

Required only for the Java `clinical-intelligence` pipeline: a service account with **Speech-to-Text V2** and **Translate V3** API access. No Google Cloud dependency exists in `doctor_app` or `clinical-intelligence-dart` — their speech and LLM paths are on-device or Ollama-based respectively.

## Environment Variables

| Variable | Used by | Purpose |
|---|---|---|
| `apiBaseUrl` (via `EnvironmentConfig`) | `doctor_app` | Backend host — hardcoded to `localhost:8080` historically; environment-based configuration is a documented, unresolved gap (see [`mobile.md`](mobile.md)) |
| `cloudLlmEnabled` (via `EnvironmentConfig`) | `doctor_app` | The compliance gate — see [`security.md`](security.md) for why its default matters |
| Ollama `baseUrl` / `model` | `clinical-intelligence-dart` | Defaults: `http://127.0.0.1:11435`, `llama3.2` |
| Google Cloud service account credentials | `clinical-intelligence` (Java) | STT/Translate API access |
| OpenAI API key | `clinical-intelligence` (Java) | LangChain4j LLM calls |

No `.env.example` or equivalent consolidated environment-variable manifest is confirmed to exist across the monorepo — this table is assembled from what each system's own documentation references, not a single source file.

## Secrets

No secrets-management strategy (Vault, cloud secret managers, encrypted CI variables) is documented as implemented. This is an open area flagged generally in the platform's security review without further detail — treat it as unaddressed rather than assume any particular scheme is in place.

## GitHub Actions / CI-CD

**No confirmed CI/CD pipeline configuration was available for review** — GitHub's `robots.txt` blocks automated inspection of the repository's `.github/workflows/` directory, and no architecture document describes an existing pipeline in detail. The platform's own recommended shape, stated generally:

```
lint → unit test → build → deploy to staging → smoke test → deploy to production
```

Each stage exists to catch a specific class of failure as cheaply and early as possible — running slow integration/load tests before a cheap lint check would be backwards. Treat this as **recommended target state**, not a confirmed existing pipeline.

## Production Deployment

No production environment is documented as currently live. The recommended path, staged by what has to be true first:

1. Postgres migration must land before the backend can be made stateless.
2. Once stateless, **blue-green or canary deployment** becomes possible — deploy the new version alongside the old, shift a small percentage of traffic, watch error rates, then cut over. This is only safe once state has been fully externalized; running two versions of a stateful in-memory backend side by side would give each an inconsistent view of the world.
3. GPU-backed inference (vLLM or a managed API) should be deployed and scaled entirely independently from the stateless Dart Frog layer, per [Docker](#docker) above.

## Observability

See [`scalability.md`](scalability.md#monitoring-at-scale) for full detail. Summary: structured logging with correlation IDs threading a single mobile-initiated action across its mobile → backend → LLM hops, key SLIs (latency percentiles by serving tier, fallback rate, LLM parse-failure rate), and OpenTelemetry-based distributed tracing are all **recommended, not yet implemented**.

## Monitoring

**Current state, confirmed**: `developer.log()` calls inside `HybridLlmAdapter`, and raw log files (`ollama.log`, `server.log`) on the backend. Genuinely useful for local debugging; genuinely insufficient for any real production user base — this is stated as a direct finding, not a hedge.

## Logging

Same current state as monitoring above — unstructured, file-based, no correlation IDs. The recommended fix (structured logging + correlation IDs) is the single highest-leverage observability improvement identified in the platform's own review, specifically because it's cheap relative to the debugging time it saves the first time a doctor reports "my summary never came back" with no way to trace the request across three hops.

## Backups

**Not currently applicable in a meaningful sense**: the backend has no persistent database yet — everything lives in in-memory `Map`s that are lost on every restart. Backups become a real requirement the moment the Postgres migration lands, and no backup strategy (point-in-time recovery, snapshot frequency, retention policy) is documented for that future state. Flag this explicitly as a gap to close **alongside**, not after, the Postgres migration — a database with no backup strategy from day one just moves the data-loss risk from "every restart" to "whatever eventually causes disk or instance failure."

## Disaster Recovery

No disaster recovery plan (RTO/RPO targets, multi-region failover, runbook) is documented anywhere in the available source material. Given the platform's own staged approach to everything else (fix correctness before scale, fix scale before hyperscale concerns), a reasonable sequencing would be: define backup/restore procedures once Postgres lands, define RTO/RPO targets once the system has real production traffic to protect, and treat multi-region failover as a hyperscale-tier concern consistent with the data-residency discussion in [`scalability.md`](scalability.md#1000000-users--multi-country-platform). This is a suggested sequencing, not a documented plan.

---

**Next:** [`docs/developer-guide.md`](developer-guide.md) — contributing to EdgeLLMHub.