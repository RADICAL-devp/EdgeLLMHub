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

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. $2"
        exit 1
    fi
    echo "✅ $1 found: $(command -v "$1")"
}

echo "Checking prerequisites..."
echo ""

check_command "cmake" "Install via: brew install cmake (requires >= 3.24)"
check_command "git-lfs" "Install via: brew install git-lfs && git lfs install"
check_command "rustc" "Install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
check_command "cargo" "Install via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
check_command "python3" "Install via: brew install python@3.11"

# Check CMake version
CMAKE_VERSION=$(cmake --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d. -f1)
CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d. -f2)
if [ "$CMAKE_MAJOR" -lt 3 ] || ([ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 24 ]); then
    echo "❌ CMake >= 3.24 required (found $CMAKE_VERSION)"
    exit 1
fi
echo "✅ CMake version: $CMAKE_VERSION"

# Check git-lfs is initialized
if ! git lfs version &> /dev/null; then
    echo "⚠️  git-lfs not initialized. Running: git lfs install"
    git lfs install
fi

# Check mlc_llm pip package
if ! python3 -c "import mlc_llm" 2>/dev/null; then
    echo ""
    echo "⚠️  mlc_llm Python package not found."
    echo "   Installing via: pip install mlc-llm mlc-ai-nightly -f https://mlc.ai/wheels"
    pip install mlc-llm mlc-ai-nightly -f https://mlc.ai/wheels
fi
echo "✅ mlc_llm Python package found"

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

python3 -m mlc_llm package "$CONFIG_FILE" \
    --device iphone \
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
cat "$IOS_DIR/mlc-llm/SHA256SUMS.txt"

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

