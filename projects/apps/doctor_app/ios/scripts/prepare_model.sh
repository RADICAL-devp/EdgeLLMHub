#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# prepare_model.sh — Automate MLC LLM model compilation for iOS
# ═══════════════════════════════════════════════════════════════════════
#
# Usage:
#   ./ios/scripts/prepare_model.sh
#
# Prerequisites:
#   - CMake >= 3.24
#   - Git-LFS
#   - Rust/Cargo
#   - Python 3.10+
#   - mlc_llm pip package
#
# This script:
#   1. Verifies all prerequisites are installed
#   2. Runs `mlc_llm package` with the project's config
#   3. Places compiled model artifacts where Xcode expects them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$IOS_DIR/.." && pwd)"
CONFIG_FILE="$IOS_DIR/mlc-package-config.json"

echo "═══════════════════════════════════════════════════"
echo " MLC LLM Model Preparation for iOS"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Project: $PROJECT_DIR"
echo "Config:  $CONFIG_FILE"
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
check_command "python3" "Install via: brew install python@3.10"

# Check CMake version
CMAKE_VERSION=$(cmake --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d. -f1)
CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d. -f2)
if [ "$CMAKE_MAJOR" -lt 3 ] || ([ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 24 ]); then
    echo "❌ CMake >= 3.24 required (found $CMAKE_VERSION)"
    exit 1
fi
echo "✅ CMake version: $CMAKE_VERSION"

# Check mlc_llm pip package
if ! python3 -c "import mlc_llm" 2>/dev/null; then
    echo ""
    echo "⚠️  mlc_llm Python package not found."
    echo "   Install via: pip install mlc-llm mlc-ai-nightly -f https://mlc.ai/wheels"
    echo ""
    read -p "Install now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pip install mlc-llm mlc-ai-nightly -f https://mlc.ai/wheels
    else
        exit 1
    fi
fi
echo "✅ mlc_llm Python package found"

echo ""
echo "All prerequisites verified."
echo ""

# ── 2. Verify config file ───────────────────────────────────────────

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ mlc-package-config.json not found at $CONFIG_FILE"
    exit 1
fi

echo "Config file contents:"
cat "$CONFIG_FILE"
echo ""
echo ""

# ── 3. Run mlc_llm package ──────────────────────────────────────────

echo "Running mlc_llm package..."
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

echo ""
echo "═══════════════════════════════════════════════════"
echo " ✅ Model preparation complete!"
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
