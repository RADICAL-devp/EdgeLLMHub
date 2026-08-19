#!/usr/bin/env bash
#
# Installs the sqlite-vec loadable extension for the backend's host platform.
#
# Rather than compiling from source, this downloads the pinned prebuilt
# "loadable" extension from the sqlite-vec GitHub release (v0.1.6):
#   https://github.com/asg017/sqlite-vec/releases/tag/v0.1.6
#
# The release tarball is verified against the SHA256 published in the
# release's own checksums.txt (fetched 2026-08-11, hashes embedded below).
#
# Installs to:
#   lib/infrastructure/persistence/vec_ext/vec0.dylib   (macOS)
#   lib/infrastructure/persistence/vec_ext/vec0.so      (Linux)
#
# These are the exact filenames the Dart code resolves in
# lib/infrastructure/persistence/sqlite_vec_store.dart.
#
# Idempotent: safe to re-run at any time; the pinned artifact is re-downloaded,
# hash-verified, and atomically installed.
#
# Usage:
#   scripts/build_sqlite_vec.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$REPO_ROOT/lib/infrastructure/persistence/vec_ext"

readonly VERSION="v0.1.6"
readonly BASE_URL="https://github.com/asg017/sqlite-vec/releases/download/${VERSION}"

# SHA256 of the release tarball, from the v0.1.6 release's checksums.txt.
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    ASSET="sqlite-vec-${VERSION#v}-loadable-macos-aarch64.tar.gz"
    SHA256="142e195b654092632fecfadbad2825f3140026257a70842778637597f6b8c827"
    FILENAME="vec0.dylib"
    ;;
  Linux-x86_64)
    ASSET="sqlite-vec-${VERSION#v}-loadable-linux-x86_64.tar.gz"
    SHA256="438e0df29f3f8db3525b3aa0dcc0a199869c0bcec9d7abc5b51850469caf867f"
    FILENAME="vec0.so"
    ;;
  *)
    echo "Unsupported platform: $(uname -s)-$(uname -m)" >&2
    echo "sqlite-vec v0.1.6 ships prebuilt loadable extensions for macOS (arm64/x86_64) and Linux (arm64/x86_64); compile from source for other hosts." >&2
    exit 1
    ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

URL="$BASE_URL/$ASSET"
echo "==> Downloading sqlite-vec ${VERSION} for $(uname -s)-$(uname -m)"
echo "    $URL"
curl -fsSL -o "$TMP_DIR/$ASSET" "$URL"

echo "==> Verifying SHA256"
if command -v shasum >/dev/null 2>&1; then
  (cd "$TMP_DIR" && echo "$SHA256  $ASSET" | shasum -a 256 -c -)
else
  (cd "$TMP_DIR" && echo "$SHA256  $ASSET" | sha256sum -c -)
fi

echo "==> Extracting"
tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR"

mkdir -p "$INSTALL_DIR"
install -m 0755 "$TMP_DIR/$FILENAME" "$INSTALL_DIR/$FILENAME"

echo "==> Installed $INSTALL_DIR/$FILENAME"
echo "    sqlite-vec ${VERSION} is ready for the backend (HNSW vector search)."
