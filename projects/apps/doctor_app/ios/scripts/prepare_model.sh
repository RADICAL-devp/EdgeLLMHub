#!/usr/bin/env bash
set -euo pipefail

# Thin compatibility wrapper around setup_ios_mlc.sh.
#
# Usage:
#   ./ios/scripts/prepare_model.sh [--model MODEL] [--quant QUANT]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pass all arguments to setup_ios_mlc.sh
exec "$SCRIPT_DIR/setup_ios_mlc.sh" "$@"
