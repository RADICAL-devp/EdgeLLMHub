# Future integration: Agora RTT (parked)

This folder is intentionally **not wired into the app**.

The shipping app is local-only:

- 16 kHz PCM is captured with `record`.
- Whisper base (via `flutter_edge_ai_speech`) transcribes on the device.
- The temporary audio file is deleted after transcription.
- The transcript and note are encrypted at rest with `PhiEncryptionService`.
- No network service is used except the one-time model download.

Agora Real-Time Transcription is a remote service. Enabling it would mean audio
or transcript data leaves the device, so it needs a separate privacy/consent
review before it can be used with real patients.

If the integration is resumed:

1. Add the official Agora token generator (the placeholder in
   `agora_rtt_service.dart` is not production-ready).
2. Get explicit patient/clinician consent and document retention.
3. Add an audit trail and a way to disable remote processing per clinic.
4. Keep this code out of the default dependency-injection graph.
