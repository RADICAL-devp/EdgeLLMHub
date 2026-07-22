# Diagrams

Standalone Mermaid diagram sources referenced throughout this documentation set. Each `.mmd` file is a single diagram; render with any Mermaid-compatible viewer (GitHub renders `.mmd` files natively, as does the [Mermaid Live Editor](https://mermaid.live)).

| File | Diagram | Referenced in |
|---|---|---|
| `01-system-overview.mmd` | The three systems and their actors | `README.md`, `architecture.md` |
| `02-architecture.mmd` | High-level layered architecture, all three systems | `architecture.md` |
| `03-doctor-journey.mmd` | End-to-end doctor experience for one consultation | `README.md` |
| `04-request-lifecycle.mmd` | Sequence diagram: UI through persistence | `architecture.md` |
| `05-hybrid-llm-routing.mmd` | Three-tier LLM fallback decision logic | `architecture.md`, `mobile.md` |
| `06-flutter-architecture.mmd` | Mobile component diagram, LLM path | `mobile.md` |
| `07-backend-architecture.mmd` | Dart Frog Hexagonal Architecture layering | `backend.md` |
| `08-java-pipeline.mmd` | Four-phase Java enterprise pipeline | `java-enterprise.md` |
| `09-offline-sync.mmd` | Local-first write path and sync queue state machine | `mobile.md`, `scalability.md` |
| `10-security-flow.mmd` | Current (unauthenticated) vs. planned three-layer auth | `security.md` |
| `11-deployment.mmd` | Current local-only topology vs. recommended target | `deployment.md` |
| `12-scalability-tiers.mmd` | Bottleneck-driven growth path, tier by tier | `scalability.md` |
| `13-cicd.mmd` | Recommended staged CI/CD pipeline | `deployment.md` |

## Provenance notes

- Diagrams `01`–`07`, `09` reflect confirmed architecture from source review documents and the implementation walkthrough.
- Diagram `08` (Java pipeline) is built only from the service's own top-level README — no file-level source was available for this service (see `docs/java-enterprise.md`).
- Diagrams `10`–`13` mix confirmed current state (shown in red/yellow) with recommended target state (shown in green) — colors are meaningful, not decorative. Check each diagram's inline comments before treating any element as already implemented.
