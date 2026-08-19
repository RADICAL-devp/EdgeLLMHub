# Doctor App — Operations Runbook

## System Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| Mobile App | Flutter 3.x | iOS/Android on-device LLM |
| Local LLM | MLC LLM (SmolLM-360M) | On-device inference |
| Database | Drift + SQLCipher | Encrypted local storage |
| Speech | Native STT + Agora RTT | Voice transcription |
| Sync | Custom offline queue | Best-effort backend sync |
| Backend | Dart Frog (optional) | Cloud fallback (disabled) |

---

## Critical Paths

### 1. On-Device Inference Flow

```
User Input → HybridLlmAdapter → Native Adapter → MethodChannel
                                                    ↓
                                              MLCEngine (Metal/Vulkan)
                                                    ↓
                                              EventChannel Stream
                                                    ↓
                                              Dart: Parse → UI
```

**SLA:** < 2s first token, < 10s full response on iPhone 13+

### 2. Model Download Flow

```
App Start → ModelManagerCubit.checkModelExists()
                    ↓
            Not installed? → Show Download UI
                    ↓
            User taps Download → ModelManagerCubit.downloadModel()
                    ↓
            Download + Verify SHA256 → Extract → Verify Inference
                    ↓
            Ready → ModelManagerReady
```

**SLA:** Download < 5 min (WiFi), Verify < 30s

### 3. Sync Flow

```
Note Save → Local DB → SyncQueueService.enqueue()
                    ↓
            Background: SyncQueueService.processQueue()
                    ↓
            For each entry: NoteSyncRepository.syncNoteToBackend()
                    ↓
            Success → Remove from queue
            Failure → Increment retry, exponential backoff
```

---

## Monitoring Dashboards

### Key Metrics to Alert On

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| `llm.inference.duration_ms` p99 | > 15s | > 30s | Check device thermal/throttling |
| `llm.inference.errors` rate | > 1% | > 5% | Check model corruption |
| `sync.errors` rate | > 5% | > 20% | Check backend health |
| `sync.queue.size` | > 100 | > 500 | Check connectivity/backlog |
| `db.errors` rate | > 0.1% | > 1% | Check DB corruption |
| `app.crashes` | > 0 | > 0 | Immediate investigation |

### Log Queries

```bash
# LLM inference errors
level=error logger=HybridLlmAdapter

# Model download failures
level=error logger=ModelManagerCubit message="Download failed"

# Sync conflicts
level=warn logger=NoteSyncRepository message="conflict"

# PHI encryption errors
level=error logger=PhiEncryptionService
```

---

## Incident Response

### INCD-001: LLM Inference Fails on All Devices

**Symptoms:** `llm.inference.errors` spike, users see `[OFFLINE MODE]`

**Diagnosis:**
1. Check `MLCLLMHandler` logs on device (Xcode/Logcat)
2. Verify model files exist: `Documents/SmolLM-360M-Instruct-q4f16_1-MLC/`
3. Check model checksum matches `checksums.sha256`

**Resolution:**
- If model corrupted: Push model re-download via remote config
- If binary issue: Rollback app version, rebuild with fixed MLC

### INCD-002: Model Download Stuck at 0%

**Symptoms:** Users report download never starts/progresses

**Diagnosis:**
1. Check `MODEL_DOWNLOAD_URL` is accessible
2. Verify network connectivity (WiFi required for large download)
3. Check disk space: `minFreeDiskSpaceBytes` (2GB)

**Resolution:**
- Update download URL via remote config
- Add fallback CDN URLs
- Clear partial downloads: `ModelManagerCubit._cleanupPartialFile()`

### INCD-003: Sync Queue Growing Unbounded

**Symptoms:** `sync.queue.size` > 500, users report data not syncing

**Diagnosis:**
1. Check backend API health: `GET /health`
2. Check network errors: `network.request.errors` by endpoint
3. Check for dead letters: `SyncQueueEntry.isDeadLetter`

**Resolution:**
- If backend down: Increase retry backoff, notify on-call
- If auth expired: Trigger token refresh via `AuthTokenService`
- If conflicts: Run manual conflict resolution script

### INCD-004: Database Corruption / Encryption Errors

**Symptoms:** `db.errors` spike, `EncryptionException` in logs

**Diagnosis:**
1. Check SQLCipher version compatibility
2. Verify key in secure storage: `flutter_secure_storage`
3. Check disk health / available space

**Resolution:**
- If key rotated: Run `EncryptedDatabase.rotateKey()`
- If corruption: Restore from backup (if available) or clear DB (last resort)
- **Never** clear DB without user consent — data loss!

### INCD-005: Agora RTT Transcription Not Working

**Symptoms:** Video call transcripts empty, webhook not receiving

**Diagnosis:**
1. Check Agora credentials: `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`
2. Verify webhook endpoint accessible from internet
3. Check `AgoraRttService` logs for API errors

**Resolution:**
- Regenerate Agora credentials in dashboard
- Update webhook URL in Agora console
- Check firewall/network rules for webhook

---

## Maintenance Procedures

### Weekly

- [ ] Review crash reports (Firebase Crashlytics / Sentry)
- [ ] Check `sync.queue.size` trend
- [ ] Verify model checksum on sample devices
- [ ] Review security audit logs

### Monthly

- [ ] Rotate database encryption key (if policy requires)
- [ ] Update model to latest SmolLM version (if available)
- [ ] Load test sync pipeline
- [ ] Review and update runbook

### Quarterly

- [ ] Penetration test (PHI handling)
- [ ] Disaster recovery drill (DB restore)
- [ ] Update dependencies (Flutter, MLC, Drift, etc.)
- [ ] Review compliance (HIPAA, local regulations)

---

## Deployment Checklist

### Pre-Release

- [ ] `flutter analyze` — no issues
- [ ] `flutter test` — all pass
- [ ] `flutter build ios --release` — succeeds
- [ ] `flutter build apk --release` — succeeds
- [ ] Test on physical iOS device (iPhone 13+)
- [ ] Test on physical Android device (Vulkan)
- [ ] Verify model loads and infers on both
- [ ] Verify sync works (offline → online)
- [ ] Verify encryption: DB + PHI fields
- [ ] Verify Agora RTT (if video calls enabled)

### Release

- [ ] Tag version in git
- [ ] Upload iOS to TestFlight
- [ ] Upload Android to Play Console (internal test)
- [ ] QA sign-off
- [ ] Promote to production track
- [ ] Monitor metrics for 1 hour

### Rollback

```bash
# iOS: TestFlight → Previous build
# Android: Play Console → Previous version
# Remote config: Disable problematic features
# Model: Keep previous model version compatible
```

---

## Contact Escalation

| Issue Type | Primary | Secondary |
|------------|---------|-----------|
| LLM/MLC Issues | ML Engineer | Platform Lead |
| Sync/Backend | Backend Engineer | Platform Lead |
| Security/PHI | Security Lead | CTO |
| App Crashes | Mobile Lead | Platform Lead |
| Agora/Video | Video Engineer | Backend Engineer |

---

## Useful Commands

```bash
# View device logs (iOS)
idevicesyslog | grep -E "(MLC|HybridLlm|ModelManager)"

# View device logs (Android)
adb logcat | grep -E "(MLC|HybridLlm|ModelManager)"

# Check model files on device
adb shell ls -la /data/user/0/com.omoyari.greentech.doctor_app/files/SmolLM-360M-Instruct-q4f16_1-MLC/

# Test API endpoint
curl -X POST https://api.example.com/api/v1/clinical-processing/process \
  -H "Content-Type: application/json" \
  -d '{"inputText":"Test","processingMode":"summarize"}'

# Check sync queue size (via app debug menu or logs)
# Metrics: sync.queue.size

# Force sync retry
# In app: SyncStatusIndicator → Retry

# Rotate DB key (emergency only)
# Requires app restart after
```

---

## Compliance Notes

- **HIPAA:** All PHI encrypted at rest (AES-256-GCM + SQLCipher)
- **No Cloud PHI:** `cloudLlmEnabled = false` hardcoded
- **Audit Logs:** `JsonLogger` with correlation IDs, no PHI in logs
- **Data Retention:** Local only, user-controlled deletion
- **Consent:** AI disclaimer on first launch
- **Breach Notification:** 72h detection via monitoring alerts