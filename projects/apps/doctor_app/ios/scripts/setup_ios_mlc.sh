#!/usr/bin/env bash
set -euo pipefail

# setup_ios_mlc.sh — Automate Mac environment setup and SmolLM-350M compilation for iOS
#
# Usage: ./ios/scripts/setup_ios_mlc.sh [--model MODEL] [--quant QUANT]
#
# Prerequisites verified:
#   - cmake >= 3.24
#   - git-lfs
#   - rustc/cargo
#   - python3
#   - mlc_llm pip package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$IOS_DIR/.." && pwd)"
CONFIG_FILE="$IOS_DIR/mlc-package-config.json"

# Default model configuration
MODEL="${MODEL:-HF://HuggingFaceTB/SmolLM-350M-Instruct}"
QUANT="${QUANT:-q4f16_1}"
MODEL_NAME="SmolLM-350M-Instruct-${QUANT}"
MODEL_LIB="${MODEL_NAME}-MLC"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="$2"
      # Extract model name from HF path
      MODEL_NAME=$(basename "$2" | sed 's/Instruct.*/Instruct/')"-${QUANT}"
      MODEL_LIB="${MODEL_NAME}-MLC"
      shift 2
      ;;
    --quant)
      QUANT="$2"
      MODEL_NAME="SmolLM-350M-Instruct-${QUANT}"
      MODEL_LIB="${MODEL_NAME}-MLC"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--model MODEL] [--quant QUANT]"
      echo "  Default model: HF://HuggingFaceTB/SmolLM-350M-Instruct"
      echo "  Default quant: q4f16_1"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

echo "═══════════════════════════════════════════════════"
echo " iOS MLC LLM Setup for ${MODEL_NAME}"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Project: $PROJECT_DIR"
echo "Config:  $CONFIG_FILE"
echo "Model:   $MODEL"
echo "Quant:   $QUANT"
echo ""

# ── 1. Verify prerequisites ─────────────────────────────────────────

VENV_PY="$IOS_DIR/venv-mlc/bin/python"
VENV_DIR="$IOS_DIR/venv-mlc/lib/python3.11"

if [ ! -x "$VENV_PY" ]; then
    echo "❌ Virtual env not found at $VENV_PY"
    echo "   Create it with: python3 -m venv ios/venv-mlc"
    exit 1
fi
echo "✅ venv python found: $VENV_PY"

# mlc_llm must be installed in the venv from MLC's wheel index
# (mlc-llm/mlc-ai are NOT on PyPI). Stable 0.20.0 pair + the matching
# tvm-ffi built from the vendored source tree (PyPI's apache-tvm-ffi is
# ABI-incompatible with the macOS wheels).
if ! "$VENV_PY" -c "import mlc_llm" 2>/dev/null; then
    echo "⚠️  mlc_llm not importable in venv. Expected setup:"
    echo "   1) $VENV_PY -m pip install cmake ninja"
    echo "   2) $VENV_PY -m pip install --pre -f https://mlc.ai/wheels mlc-ai-cpu mlc-llm-cpu"
    echo "   3) git -C $IOS_DIR/mlc-llm/3rdparty/tvm/3rdparty/tvm-ffi checkout 3c35034fd"
    echo "   4) $VENV_PY -m pip install $IOS_DIR/mlc-llm/3rdparty/tvm/3rdparty/tvm-ffi"
    echo "   5) $VENV_PY -m pip install pytest"
    echo "   6) Re-sign native libs (see resign step below)."
    exit 1
fi
echo "✅ mlc_llm Python package found"

# HuggingFace now requires authentication for model downloads.
if [ -z "${HF_TOKEN:-}" ] && [ ! -f "$HOME/.cache/huggingface/token" ]; then
    echo "❌ No HuggingFace token found (HF_TOKEN unset, no ~/.cache/huggingface/token)."
    echo "   Create a read token at https://huggingface.co/settings/tokens and run:"
    echo "   export HF_TOKEN=hf_..."
    exit 1
fi
echo "✅ HuggingFace token found"

# macOS 26 kills unsigned native dylibs at load time (SIGKILL on import).
# The MLC wheels ship invalidly-signed binaries; ad-hoc re-signing is
# required after every pip install that touches mlc/tvm/tvm_ffi.
echo "Re-signing native libraries in the venv (macOS 26 requirement)..."
find "$VENV_DIR/lib" -name "*.so" -o -name "*.dylib" 2>/dev/null | while read -r f; do
    codesign -f -s - "$f" 2>/dev/null || echo "  (skipped: $f)"
done
echo "✅ Native libraries re-signed"

echo ""
echo "All prerequisites verified."
echo ""

# ── 2. Update config file with model ────────────────────────────────

echo "Updating mlc-package-config.json with model: $MODEL, quant: $QUANT"
cat > "$CONFIG_FILE" << CONFIG_EOF
{
  "device": "iphone",
  "model_list": [
    {
      "model": "$MODEL",
      "model_id": "${MODEL_LIB}",
      "estimated_vram_bytes": 190000000,
      "bundle_weight": true,
      "overrides": {
        "context_window_size": 2048,
        "prefill_chunk_size": 512,
        "model_type": "smolLM",
        "quantization": "$QUANT"
      }
    }
  ]
}
CONFIG_EOF

echo "Config file contents:"
cat "$CONFIG_FILE"
echo ""
echo ""

# ── 3. Run mlc_llm package ──────────────────────────────────────────

echo "Running mlc_llm package for $MODEL_NAME..."
echo ""

cd "$IOS_DIR"

"$VENV_PY" -m mlc_llm package \
    --package-config "$CONFIG_FILE" \
    --mlc-llm-source-dir "$IOS_DIR/mlc-llm" \
    --output "$IOS_DIR/mlc-llm" \
    2>&1 | tee "$IOS_DIR/mlc_package_output.log"

PACKAGE_EXIT=$?
if [ $PACKAGE_EXIT -ne 0 ]; then
    echo ""
    echo "❌ mlc_llm package failed (exit code: $PACKAGE_EXIT)"
    echo "   Check $IOS_DIR/mlc_package_output.log for details"
    exit 1
fi

# ── 4. Generate SHA256 checksums ────────────────────────────────────

echo ""
echo "Generating SHA256 checksums for model artifacts..."

find "$IOS_DIR/mlc-llm" -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.json" -o -name "*.bin" -o -name "*.params" \) | \
    xargs sha256sum > "$IOS_DIR/mlc-llm/SHA256SUMS.txt"

echo "✅ Checksums saved to $IOS_DIR/mlc-llm/SHA256SUMS.txt"

# ── 4b. Emit checksums.sha256 for runtime verification ──────────────
# MLCLLMHandler reads `checksums.sha256` from the bundle and exposes it
# via getModelInfo; ModelManagerCubit logs it during verification.
# ios/Runner is a synchronized Xcode group, so this file is bundled
# automatically when the app builds.
echo ""
echo "Writing bundle checksums.sha256..."
MODEL_DIR2="$IOS_DIR/mlc-llm/$MODEL_LIB"
BUNDLE_CHECKSUM=""
if [ -d "$MODEL_DIR2" ]; then
  MODEL_BIN=$(find "$MODEL_DIR2" -maxdepth 1 -type f -name "*.bin" | head -1)
  if [ -n "$MODEL_BIN" ]; then
    BUNDLE_CHECKSUM=$(sha256sum "$MODEL_BIN" | awk '{print $1}')
  fi
fi
if [ -n "$BUNDLE_CHECKSUM" ]; then
  printf '%s  %s\n' "$BUNDLE_CHECKSUM" "${MODEL_LIB}.bin" > "$IOS_DIR/Runner/checksums.sha256"
  echo "✅ Wrote $IOS_DIR/Runner/checksums.sha256 ($BUNDLE_CHECKSUM)"
else
  echo "⚠️  Model artifacts not found; leaving checksums.sha256 untouched."
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo " ✅ iOS Model Preparation Complete!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Open ios/Runner.xcworkspace in Xcode"
echo "  2. Add MLCSwift as a local Swift Package:"
echo "     File → Add Package Dependencies → Add Local..."
echo "     Select: ios/mlc-llm/MLCSwift"
echo "  3. Ensure the model is in the Copy Bundle Resources build phase"
echo "  4. Build and run on a physical iOS device (A15+ / 6GB+ RAM)"
echo ""

# ── 5. Verify model directory structure ─────────────────────────────

MODEL_DIR="$IOS_DIR/mlc-llm/$MODEL_LIB"
if [ -d "$MODEL_DIR" ]; then
    echo "Model directory found at: $MODEL_DIR"
    ls -la "$MODEL_DIR"
else
    echo "⚠️  Model directory not found at expected path: $MODEL_DIR"
    echo "   Checking for alternative model directory names..."
    find "$IOS_DIR/mlc-llm" -maxdepth 1 -type d -name "*SmolLM*" | head -5
fi

