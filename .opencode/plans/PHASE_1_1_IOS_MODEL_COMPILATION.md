# Phase 1.1 Execution Plan: iOS SmolLM-350M Model Compilation

**Objective:** Compile `HuggingFaceTB/SmolLM-350M-Instruct` via MLC LLM toolchain and bundle for iOS.

**Prerequisites (Mac):**
- macOS 14+ (Sonoma/Ventura)
- Xcode 15+ with Command Line Tools
- Homebrew
- Physical iOS device (A15+, 6GB+ RAM) for testing

---

## Task 1.1.1: Create `ios/scripts/setup_ios_mlc.sh`

**File:** `projects/apps/doctor_app/ios/scripts/setup_ios_mlc.sh` (NEW)

**Requirements:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Verify prerequisites
check_cmd() { command -v "$1" >/dev/null || { echo "❌ $1 missing: $2"; exit 1; } }
check_cmd cmake "brew install cmake (need ≥3.24)"
check_cmd git-lfs "brew install git-lfs && git lfs install"
check_cmd rustc "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
check_cmd python3 "brew install python@3.11"

# 2. Verify cmake ≥ 3.24
cmake_ver=$(cmake --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
[[ $(echo "$cmake_ver" | awk -F. '{print $1*100+$2}') -ge 324 ]] || { echo "❌ cmake ≥3.24 required"; exit 1; }

# 3. Install mlc_llm pip package
python3 -c "import mlc_llm" 2>/dev/null || pip install mlc-llm mlc-ai-nightly -f https://mlc.ai/wheels

# 4. Check if pre-compiled SmolLM-350M exists on HF MLC repo
#   HF: mlc-ai/SmolLM-350M-Instruct-q4f16_1-MLC (may not exist yet)
#   If missing: compile from HuggingFaceTB/SmolLM-350M-Instruct

# 5. Run mlc_llm package with config
cd "$(dirname "$0")/.."
python3 -m mlc_llm package mlc-package-config.json \
    --device iphone \
    --output mlc-llm \
    2>&1 | tee mlc_package_output.log

# 6. Generate SHA256 checksums for model artifacts
find mlc-llm -name "*.so" -o -name "*.dylib" -o -name "*.json" -o -name "*.bin" | \
    xargs sha256sum > mlc-llm/SHA256SUMS.txt

echo "✅ Model compiled to ios/mlc-llm/"
echo "📋 Next: Add ios/mlc-llm/MLCSwift as local Swift Package in Xcode"
echo "📋 Next: Verify model in Copy Bundle Resources build phase"
```

---

## Task 1.1.2: Update `ios/mlc-package-config.json`

**File:** `projects/apps/doctor_app/ios/mlc-package-config.json` (MODIFY)

```json
{
  "device": "iphone",
  "model_list": [
    {
      "model": "HF://HuggingFaceTB/SmolLM-350M-Instruct",
      "bundle_weight": true,
      "overrides": {
        "context_window_size": 2048,
        "prefill_chunk_size": 512,
        "model_type": "smolLM",
        "quantization": "q4f16_1"
      }
    }
  ]
}
```

**Notes:**
- Model ID: `HuggingFaceTB/SmolLM-350M-Instruct` (360M params, marketed as 350M class)
- Quantization: `q4f16_1` = 4-bit uniform quantization, FP16 compute
- Context: 2048 tokens (max for SmolLM)
- Prefill chunk: 512 (optimized for mobile memory)

---

## Task 1.1.3: Update `ios/scripts/prepare_model.sh`

**File:** `projects/apps/doctor_app/ios/scripts/prepare_model.sh` (MODIFY)

**Changes:**
- Replace all "Llama-3.2-3B-Instruct" references with "SmolLM-350M-Instruct"
- Update model path: `SmolLM-350M-Instruct-q4f16_1-MLC`
- Add checksum verification step after packaging
- Update Xcode instructions for MLCSwift package location

---

## Task 1.1.4: Verify & Test

**Manual Steps (after script runs):**
1. Open `ios/Runner.xcworkspace` in Xcode
2. File → Add Package Dependencies → Add Local → Select `ios/mlc-llm/MLCSwift`
3. Verify `SmolLM-350M-Instruct-q4f16_1-MLC` appears in Build Phases → Copy Bundle Resources
4. Build on physical device (not simulator)
5. Check logs for `[MLCLLMHandler] MLC engine initialized successfully`

---

## Success Criteria

| Check | Pass Condition |
|-------|----------------|
| Script runs | No errors, exits 0 |
| Artifacts exist | `ios/mlc-llm/MLCSwift/Package.swift`, model files in bundle |
| Checksums | `SHA256SUMS.txt` generated with >0 entries |
| Xcode build | Compiles on device without MLCSwift linking errors |
| Runtime | `isAvailable` returns `true` after `initialize()` |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Pre-compiled model not on HF | Script compiles from source (slower, ~30-60 min) |
| cmake version too old | Homebrew `cmake` is usually ≥3.27 on macOS 14+ |
| MLCSwift API changes | Pin mlc_llm version in requirements.txt |
| Device OOM (6GB RAM) | SmolLM-350M q4f16 ~200MB, should fit with 2048 ctx |

---

## Estimated Time

| Step | Duration |
|------|----------|
| Prereq verification | 5 min |
| mlc_llm install | 5-10 min |
| Model compile (if needed) | 30-60 min |
| Xcode integration | 10 min |
| Device test | 10 min |
| **Total** | **1-1.5 hours** |