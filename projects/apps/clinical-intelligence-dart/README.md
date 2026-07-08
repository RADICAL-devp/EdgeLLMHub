# Clinical Intelligence — Dart Frog Backend

A Dart Frog-based Clinical Intelligence backend providing clinical text processing
and transcript summarization APIs. Ported from the existing Java/Micronaut
`clinical-intelligence` backend.

## Important Notes

- **Speech-to-text is app-side only.** This backend does NOT perform speech recognition.
  It accepts already-transcribed text from the Flutter doctor app.
- **LLM runs on-device.** The default stub adapter performs text processing without
  any external API. For richer processing, configure the Ollama adapter with a
  locally running Ollama instance.

## Quick Start

```bash
# Install dependencies
dart pub get

# Run the development server
dart_frog dev

# The server starts at http://localhost:8080
```

## Implemented Routes

### API Family A: Generic Clinical Processing (Milestone 1) ✅

| Method | Route | Status |
|--------|-------|--------|
| POST | `/api/v1/clinical-processing/process` | **Implemented** |

#### Processing Modes

| Mode | Status | Description |
|------|--------|-------------|
| `VOCAB_ASSIST` | ✅ Implemented | Conservative terminology assistance |
| `CLEAN_TRANSCRIPT` | ✅ Implemented | Transcript cleanup with speaker label preservation |
| `SUMMARIZE` | ⏳ Milestone 2 | Structured clinical summary |
| `GENERATE_DOCTOR_NOTE` | ⏳ Milestone 2 | Doctor note generation |
| `FULL_BUNDLE` | ⏳ Milestone 2 | All outputs in one request |

#### Example Request

```bash
curl -X POST http://localhost:8080/api/v1/clinical-processing/process \
  -H "Content-Type: application/json" \
  -d '{
    "inputText": "patient has blood pressure of 140 / 90 and heart rate 88 beats per minute",
    "processingMode": "VOCAB_ASSIST",
    "consultationId": "C-001",
    "source": "VOICE_NOTES"
  }'
```

#### Example Response

```json
{
  "processedText": "Patient has BP of 140/90 and HR 88 bpm.",
  "processingMode": "VOCAB_ASSIST",
  "warnings": [],
  "generatedAt": "2026-07-08T12:00:00.000Z",
  "metadata": {
    "consultationId": "C-001",
    "source": "VOICE_NOTES"
  }
}
```

### API Family B: Transcript Summary (Milestone 2) 🚧

| Method | Route | Status |
|--------|-------|--------|
| POST | `/api/v1/transcript-summary/generate` | Scaffolded |
| GET | `/api/v1/transcript-summary/{consultationId}` | Scaffolded |
| POST | `/api/v1/transcript-summary/{consultationId}/regenerate` | Scaffolded |

## Architecture

```
lib/
├── api/dto/                          # Request/Response DTOs
│   ├── clinical_processing_request.dart
│   ├── clinical_processing_response.dart
│   ├── transcript_summary_request.dart
│   └── transcript_summary_response.dart
├── application/
│   ├── ports/                        # Abstract interfaces
│   │   ├── llm_port.dart
│   │   ├── processed_output_repository.dart
│   │   ├── transcript_repository.dart
│   │   └── transcript_summary_repository.dart
│   └── services/                     # Business logic
│       ├── clinical_processing_orchestrator.dart
│       ├── doctor_note_generation_service.dart
│       ├── summary_generation_service.dart
│       ├── summary_orchestrator.dart
│       ├── terminology_assistance_service.dart
│       ├── transcript_chunking_service.dart
│       ├── transcript_cleanup_service.dart
│       ├── transcript_normalization_service.dart
│       ├── transcript_summary_aggregation_service.dart
│       └── validation_service.dart
├── core/models/                      # Domain models
│   ├── consultation_mode.dart
│   ├── consultation_transcript.dart
│   ├── doctor_note.dart
│   ├── executive_summary.dart
│   ├── extracted_clinical_fields.dart
│   ├── processing_mode.dart
│   ├── processing_source.dart
│   ├── structured_note_sections.dart
│   ├── structured_summary.dart
│   ├── transcript_chunk_summary.dart
│   └── transcript_summary_bundle.dart
└── infrastructure/
    ├── llm/                          # LLM adapters
    │   ├── ollama_llm_adapter.dart
    │   ├── stub_llm_adapter.dart
    │   └── prompts/
    │       └── clinical_prompts.dart
    └── persistence/                  # In-memory repositories
        ├── in_memory_processed_output_repository.dart
        ├── in_memory_summary_repository.dart
        └── in_memory_transcript_repository.dart
routes/
├── _middleware.dart                   # DI and CORS
├── index.dart                        # Health check
└── api/v1/
    ├── clinical_processing/
    │   └── process.dart              # POST clinical processing
    └── transcript_summary/
        ├── generate.dart             # POST generate summary
        └── [consultationId]/
            ├── index.dart            # GET summary
            └── regenerate.dart       # POST regenerate
```

## LLM Adapter Configuration

### Stub Adapter (Default — No API Keys Required)

The default `StubLlmAdapter` runs entirely on-device:
- **VOCAB_ASSIST**: Regex-based punctuation fixes, medical abbreviation standardization,
  capitalization
- **CLEAN_TRANSCRIPT**: Whitespace normalization, speaker label standardization
- **Summary modes**: Returns placeholder output indicating LLM not connected

### Ollama Adapter (On-Device LLM)

For richer processing with a local LLM:

1. Install [Ollama](https://ollama.com/)
2. Pull a model: `ollama pull llama3.2`
3. Uncomment the Ollama adapter in `routes/_middleware.dart`:
   ```dart
   final LlmPort llmPort = OllamaLlmAdapter();
   ```

## Running Tests

```bash
dart test
```

## Assumptions

1. **Persistence**: Uses in-memory repositories. Data is lost on server restart.
   Replace with database-backed implementations for production.
2. **Authentication**: No auth middleware. The Java backend uses JWT; add when needed.
3. **Encryption**: Not ported from the Java backend (used AES-GCM for data at rest).
4. **Vector Store**: Not ported. The Java backend used an in-memory embedding store
   for context-enriched summarization.
5. **Audit Logging**: Not ported. Add when needed for compliance.
6. **ConsultationMode**: Treated as metadata only. Does NOT create separate
   processing engines (IN_PERSON vs ONLINE use the same pipeline).
