# doctor_app

Private, offline-first Flutter app for on-device clinical documentation.

The app captures short clinical encounters, transcribes them with an
on-device speech model, drafts structured clinical notes with an on-device LLM,
and stores encrypted notes locally.

## What it does

- On-device speech-to-text for English and Hindi.
- On-device note structuring and optional transcript cleanup.
- Six structured clinical sections.
- Draft and finalized notes.
- Local encrypted storage and search.
- On-device model management and privacy settings.

## What it intentionally does not do

- No cloud STT, cloud LLM fallback, or remote backend.
- No note sync, background queue, or conflict-resolution UI.
- No vector database, embeddings, or medical knowledge base.
- No account, authentication, or analytics containing clinical content.

## AI scope

Generated notes are drafts. A qualified clinician must review and correct every
section. The model can omit, mishear, or invent details.

This app does not make medical-device or regulatory certification claims.
