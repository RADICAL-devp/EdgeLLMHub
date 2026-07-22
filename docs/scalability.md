# Scalability

Scalability isn't a yes/no property — it's a sequence of specific bottlenecks that become visible only after the previous one is fixed. This document walks that sequence tier by tier, using the platform's own five documented user-count tiers (100 → 1,000 → 100,000 → 1,000,000 → 100,000,000), each anchored to a specific, named bottleneck and fix.

> **Scope note:** the source architecture reviews define five tiers, not seven. Where a requested checkpoint (10, 10,000 users) doesn't correspond to a documented tier, it's noted inline rather than inventing a distinct architecture for a point the source material doesn't actually treat as a transition.

---

## Table of Contents

- [10 & 100 Users — Pilot](#10--100-users--pilot)
- [1,000 Users — Regional Rollout](#1000-users--regional-rollout)
- [10,000 Users](#10000-users)
- [100,000 Users — National Rollout](#100000-users--national-rollout)
- [1,000,000 Users — Multi-Country Platform](#1000000-users--multi-country-platform)
- [100,000,000 Users — Hyperscale](#100000000-users--hyperscale)
- [Summary Table](#summary-table)
- [Performance Engineering (Cross-Tier)](#performance-engineering-cross-tier)
- [Failure Recovery](#failure-recovery)
- [Testing at Scale](#testing-at-scale)
- [Deployment](#deployment)
- [Monitoring at Scale](#monitoring-at-scale)
- [Costs](#costs)
- [Future Improvements](#future-improvements)

---

## 10 & 100 Users — Pilot

At this scale — one hospital department — **the current architecture mostly works as-is**, and that's worth stating plainly rather than manufacturing problems that don't exist yet. A single Ollama process on a single machine comfortably absorbs the bursty, low-concurrency load of a handful of doctors recording a handful of consultations each per day; genuine simultaneous collisions are rare.

- **Architecture**: unchanged from the current design — single Dart Frog process, single Ollama instance, mobile app talking directly to both.
- **GPU inference**: one GPU, one Ollama process, no concurrency management needed yet.
- **Queues / caching / networking**: none required.
- **Database**: this is where the *one* required change lives, and it's a correctness fix, not a scale fix — **in-memory persistence must go**, because a routine deploy restart currently deletes every transcript and summary that hasn't synced. Fix: a single managed Postgres instance (RDS, Cloud SQL, or a well-monitored VM) — no replicas, no sharding.
- **Deployment**: today's actual topology is `127.0.0.1` — Dart Frog and Ollama on one developer machine. Getting to a real pilot deployment means containerizing the two separately (see [Deployment](#deployment)).
- **Monitoring**: `developer.log()` calls and raw log files are adequate for this tier's debugging needs, though not for anything beyond it.
- **Cost**: minimal — one small server, one GPU instance, no infrastructure team required.

## 1,000 Users — Regional Rollout

This is the first genuine scale bottleneck, and it's the one `scalability_efficiency_analysis.md` identified directly: **Ollama serializes GPU-bound inference**. At 100 users, request collisions were rare enough that a queue never really formed. At 1,000, concurrent "doctor finishes a consultation and taps summarize" moments overlap often enough that requests genuinely queue behind each other — multi-minute waits or timeouts follow.

Two distinct fixes are required here — conflating them is a common mistake:

1. **Replace naive Ollama serving with something built for concurrency** — specifically [vLLM](https://github.com/vllm-project/vllm). Its core innovation, **PagedAttention** (Kwon et al., 2023), manages each request's attention key/value cache the way an OS manages virtual memory pages, rather than reserving one large contiguous block per request. This is *why* vLLM serves many concurrent requests on one GPU with high throughput where naive serving serializes them — it's a fundamentally different memory-management strategy, not just "a faster server."
2. **Make the backend horizontally scalable** — which requires tier one's Postgres migration to already be done. You cannot run two Dart Frog replicas behind a load balancer while state lives in an in-process `Map`; replica B has no idea what replica A just wrote. Once state lives in Postgres, N stateless Dart Frog replicas behind a load balancer is straightforward — notably, the *route layer* (`process.dart`, `index.dart`) is already stateless; it's specifically `InMemoryTranscriptRepository`/`InMemorySummaryRepository` that isn't. Because those repositories sit behind port interfaces, swapping in a Postgres-backed adapter doesn't require touching `SummaryOrchestrator` or any route handler.

- **Caching**: not yet a priority at this tier.
- **Networking**: load balancer introduced in front of now-stateless Dart Frog replicas.
- **Failure recovery**: this is also the tier where a circuit breaker and retry-with-jitter on the backend's Ollama calls start earning their keep — currently absent (see [`backend.md`](backend.md#circuit-breaker)).

## 10,000 Users

Not a separately documented transition point in the source architecture reviews — this tier sits inside the same regime as the 1,000-user tier's fixes (vLLM/managed inference + stateless, Postgres-backed replicas), with those fixes under real, sustained load rather than early adoption. The next genuinely new bottleneck doesn't appear until the 100,000-user tier below.

## 100,000 Users — National Rollout

New problems appear here that didn't exist at 1,000:

- **Synchronous request/response stops being a viable shape for LLM generation.** Today, the mobile app POSTs and blocks for the full response. At this scale, holding open tens of thousands of concurrent long-lived HTTP connections (each waiting seconds for an LLM) is expensive on connection-handling infrastructure and fragile against network blips. The realistic shift is to **asynchronous, queue-based processing**: submit a transcript, get an immediate "accepted, job ID: X," then poll or receive a push notification when the summary is ready — the same shift email delivery, video transcoding, and large file processing all make at this scale. The synchronous call becomes a thin "enqueue" operation; a worker pool (RabbitMQ, Google Cloud Pub/Sub, or AWS SQS are all reasonable) pulls jobs at whatever rate the inference layer can sustain.
- **Rate limiting and per-doctor quotas become necessary**, not just nice-to-have — without them, one misbehaving client (a buggy retry loop, or outright abuse) degrades the queue for everyone.
- **Read replicas for Postgres** become worthwhile once "doctor pulls up consultation history" read traffic meaningfully exceeds write traffic — a normal shape here, since you write once per consultation but may re-read a patient's history many times before the next visit.
- **A CDN or edge cache for static assets** — app update manifests, and multi-gigabyte ML model download artifacts specifically — becomes worth offloading from the origin backend.

## 1,000,000 Users — Multi-Country Platform

- **Database sharding** becomes necessary once a single Postgres primary can't absorb write volume even with read replicas taking read load off it. The natural shard key is `doctor_id` or `clinic_id` — consultations for one doctor never need to be joined against a different doctor's data in a shard elsewhere, which is exactly the property a good shard key needs.
- **Data residency becomes an architectural constraint, not a compliance checkbox.** Health data regulation varies meaningfully by jurisdiction — "PHI" is HIPAA's (U.S.) vocabulary specifically; a deployment in India, for instance, falls under the Digital Personal Data Protection Act (DPDP Act, 2023), whose operational requirements have continued to evolve — worth confirming current status with someone tracking the regulatory landscape rather than treating any snapshot, including this one, as final. At this tier, "which region does this doctor's data physically live in" becomes a top-level architectural decision shaping the entire database topology (region-pinned shards, not a single global cluster).
- **The per-request fallback chain needs fleet-level visibility.** The 3-tier `HybridLlmAdapter` is well-designed *per request*, but at this scale you also need aggregate telemetry — if 40% of requests suddenly fall through to cloud because an OS update broke on-device model loading on a specific phone model, that needs to surface from a dashboard, not from doctors filing support tickets one at a time.

## 100,000,000 Users — Hyperscale

At this point the system resembles a large hospital-network EHR vendor or a national telehealth service in scale:

- **Model routing/cascading by difficulty** becomes economically necessary — route routine cases (a simple follow-up, a prescription refill note) to the cheapest, fastest model tier, and reserve larger models for cases a cheap model's confidence score flags as uncertain. Smaller/faster models absorb the bulk of traffic; larger models are the exception, not the default.
- **Custom inference infrastructure investment starts to make sense** — at this volume, small per-request cost or latency improvements compound into meaningful absolute savings, justifying a dedicated ML infrastructure team rather than backend engineers running a hosted API.
- **Organizational structure becomes an architecture concern.** Amazon's "two-pizza team" framing (build a service, own it end-to-end, communicate only through well-defined APIs) stops being a nice idea and becomes close to mandatory — no single team can hold mobile, backend, inference infrastructure, compliance, and data platform in their heads at once anymore.

## Summary Table

| Tier | New Bottleneck | Fix |
|---|---|---|
| 100 | Data loss on restart | Postgres (durability, not scale) |
| 1,000 | Ollama serializes concurrent requests | vLLM/managed inference API + stateless backend replicas |
| 100,000 | Synchronous HTTP wait doesn't scale | Queue-based async processing, rate limiting, read replicas |
| 1,000,000 | Single-region DB can't absorb writes | Sharding by `doctor_id`/`clinic_id`, data-residency awareness |
| 100,000,000 | Per-request inference cost/latency compounds | Model cascading, dedicated inference infra, org restructuring |

---

## Performance Engineering (Cross-Tier)

Distinct from the tier-by-tier bottlenecks above — these matter even at low load:

- **A new `HttpClient()` is instantiated on every call** in `OllamaLlmAdapter._generate()`, meaning a fresh TCP connection (and, over real HTTPS, a fresh TLS handshake) every time instead of a pooled, keep-alive connection. Fix: hold one long-lived `HttpClient` field and reuse it — Dart's `HttpClient` pools connections internally once you stop discarding it.
- **The cloud path gives up the streaming the native path has.** `'stream': false` is hardcoded on the Ollama call, so `CloudLlmAdapter` blocks for the full generation time while `IosNativeLlmAdapter` streams token-by-token. Fix: set `'stream': true`, parse Ollama's newline-delimited JSON chunks, forward them via SSE or chunked transfer encoding.
- **No token/context budgeting before calls reach the LLM** — an oversized prompt is either silently truncated by the model runtime or triggers a slow, wasted round trip that fails partway through.

## Failure Recovery

- **Circuit breaker** (mobile-side, `core/network/circuit_breaker.dart`) — three states: **closed** (normal operation, failures counted), **open** (after a failure threshold trips, requests fail immediately without attempting the network call, for a cooldown window), **half-open** (after cooldown, one trial request decides whether to close or re-open). This solves a different problem than `HybridLlmAdapter`'s tier fallback: the fallback decides *which tier* should handle a request; the circuit breaker decides *whether it's even worth trying* the cloud tier's HTTP call right now. Without it, a down backend means every request pays the full connection-attempt-and-timeout cost (30s per `LlmPortFactory`) before falling through — multiplied across every doctor hitting the same dead backend.
- **Retry with backoff and jitter** (`RetryInterceptor`) — exponential backoff (1s, 2s, 4s, 8s...) with a randomized offset added to each wait. Without jitter, if a backend goes down and recovers, every client retrying on the same clock schedule hits it at the same instant — a self-inflicted thundering herd that can knock a freshly-recovered service straight back down.
- **Sync queue durability** — `sync_queue_service.dart`'s `_pendingNotes` is currently a plain in-memory `List<DoctorNote>`. If the app is OS-killed while offline (routine on both iOS and Android, not an edge case), the queue is lost — notes are safe in Drift, but the *fact that they still need to sync* is forgotten. Fix: persist queue state as its own Drift table with a status enum (`pending`/`syncing`/`synced`/`failed`), so `SyncQueueService.startListening()` can rebuild its queue on relaunch by querying for any note not yet `synced`.

## Testing at Scale

Real coverage exists today for fallback logic and migrations (`circuit_breaker_test.dart`, `hybrid_llm_adapter_test.dart`, `local_database_migration_test.dart`, and more, across both Dart repos) — genuinely the two hardest things to get right by manual testing. What's missing, specifically relevant to scaling with confidence:

- **Integration/end-to-end tests spanning mobile ↔ backend** — nothing currently spins up a real Dart Frog instance and drives it from a real or simulated client, which is exactly the seam where the two repos' hand-copied model definitions could silently drift.
- **Load/stress tests** — the claim that "20 doctors hitting the backend simultaneously" causes Ollama to queue or OOM is currently a plausible prediction, not a measured result. A tool like `k6` or `Locust` driving concurrent requests against a staging Ollama instance would make it an empirical one.

## Deployment

1. **Containerize Dart Frog and the inference layer separately.** Dart Frog is stateless, CPU-only, and cheap to replicate; whatever replaces Ollama (vLLM or a managed inference API) needs GPU-attached infrastructure and independent scaling. Coupling them in one container — as the current dev setup does by running both on one machine — means you can't scale the cheap stateless layer without also paying for GPUs you don't need.
2. **CI/CD with ordered stages**: lint → unit test → build → deploy to staging → smoke test → deploy to production. Each stage exists to catch a class of failure as cheaply and early as possible.
3. **Blue-green or canary deployment**, once the backend is genuinely stateless (requires the Postgres migration first) — you cannot safely run two versions of a stateful in-memory backend side by side, since each would have its own inconsistent view of the world.

## Monitoring at Scale

1. **Structured logging with correlation IDs** — a single "summarize this consultation" action fans out across a mobile request → a backend HTTP call → an LLM generation call, with no shared identifier tying those log lines together today.
2. **Key SLIs**: latency p50/p95/p99 broken down by serving tier (native/cloud/stub); **fallback rate** (a sudden spike is an early-warning signal for a broken native integration on a specific device population); LLM error rate and structured-output parse-failure rate.
3. **Distributed tracing** via OpenTelemetry, providing trace waterfalls across the mobile→backend→LLM hop.
4. **Alerting tied to SLIs, not raw error counts** — e.g., "page if fallback rate exceeds 30% for 10 minutes," which catches a real degradation pattern rather than training the team to ignore pages.

## Costs

| Item | Estimated cost | Notes |
|---|---|---|
| Cloud API (fallback tier, pilot scale) | $0–50/month | Usage-dependent |
| Model storage / CDN | $0–20/month | Model download artifacts |
| Monitoring/analytics | $0–100/month | Firebase, Sentry, or equivalent |
| CI/CD | $0–50/month | GitHub Actions, Codemagic, or equivalent |

Costs at the 1,000-user tier and beyond scale primarily with **GPU infrastructure** (vLLM or managed inference) rather than the stateless Dart Frog layer, which is cheap to horizontally replicate. No documented cost model exists for the 100,000+ tiers beyond the qualitative shift toward dedicated inference infrastructure investment described above.

## Future Improvements

The scale-driven roadmap, in trigger order:
1. Postgres migration (now — correctness, not scale).
2. vLLM (or managed inference API) + stateless backend replicas (~1,000-user trigger).
3. Asynchronous queue-based processing, rate limiting, read replicas, CDN for model assets (~100,000-user trigger).
4. Database sharding by `doctor_id`/`clinic_id`, data-residency-aware topology (~1,000,000-user trigger).
5. Model cascading by difficulty, dedicated inference infrastructure, two-pizza-team organizational structure (~100,000,000-user trigger).
6. Structured logging, correlation IDs, and the fallback-rate SLI dashboard — genuinely worth doing earlier than "later," since it's cheap and pays for itself the first time something breaks in production.

---

**Next:** [`docs/deployment.md`](deployment.md) — local development through production deployment, in detail.