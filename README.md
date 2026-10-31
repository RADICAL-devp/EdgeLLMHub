# EdgeAI Doctor

A private, on-device clinical documentation app. Doctors dictate, the device
transcribes and drafts, and the saved note remains on the device.

## Core promise

- **Local-only:** no audio, transcript, note, or inference result leaves the
  device.
- **PHI at rest:** note text is encrypted with AES-256-GCM; the key is held in
  the platform secure store.
- **Temporary audio:** recordings are deleted immediately after transcription.
- **No backend:** the app has no account, network sync, remote backend, or
  cloud inference path.

## On-device pipeline

1. First launch: consent and onboarding, then a one-time model download.
2. Capture: 16 kHz mono PCM16 audio via `record`.
3. Transcribe: VAD frames, silence merging, Whisper `base` int8 from
   `flutter_edge_ai_speech`, in English and Hindi.
4. Clean: optional on-device transcript cleanup, followed by structured note
   generation with Qwen3 `0.6B` from `flutter_edge_ai_litertlm`.
5. Save: encrypted local storage via Drift; notes support draft and finalized
   states.

All AI decisions are made by the single `flutter_edge_ai` adapter in
`lib/core/ai`. There is no second LLM or STT implementation.

## Supported note content

Structured sections:

- Chief complaint
- History of present illness
- Examination
- Assessment
- Treatment plan
- Follow-up

Search covers title, patient name, transcript text, and note date.

Thinking mode is user-facing and disabled by default. When enabled, the app shows
a longer-running warning before use.

## Platform requirements

- iOS: deployment target 15.0, `arm64`.
- Android: minimum SDK 30, `arm64-v8a`.

## Model catalog

All model descriptors live in one place:

`projects/apps/doctor_app/lib/core/config/model_config.dart`

Default models:

- LLM: Qwen3 `0.6B`, `ModelType.qwen3`, LiteRT-LM artifact.
- STT: Whisper `base` int8, English and Hindi.

The model choice is configurable in that single location. The app-facing
identifiers remain generic (`Clinical language model`, `Clinical speech model`).

## Privacy and scope

This project does not claim medical-device, regulatory, or clinical-validation
certification. AI output is a draft and must be reviewed by a qualified clinician.
The model can omit or mishear speech, so manual review remains essential.

## Development

From the app directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter test --update-goldens
flutter build ios --no-codesign
```

An Android SDK must be installed for Android builds.

## Future integration

Agora real-time transcription is intentionally parked under
`projects/apps/doctor_app/lib/future_integrations/agora/` and is not wired into
the app.
