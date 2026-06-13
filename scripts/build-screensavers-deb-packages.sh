#!/bin/bash
# Builds Debian (.deb) packages for all 10 screensavers, cloning each
# screensavers-<scene> repo from github.com/local76 into a local cache.
# Optionally pass a single scene name as $1 to build just that one.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_CACHE="${SCREENSAVERS_REPO_CACHE:-$TOOLKIT_ROOT/.cache/screensavers}"
mkdir -p "$REPO_CACHE"

OUTPUT_DIR="$REPO_CACHE/dist/packages"
mkdir -p "$OUTPUT_DIR"

SCREENSAVERS=(beams bounce flame gnats bursts cosmos glyphs disco storm chaos security tree)

build_single_deb() {
    local saver="$1"
    local dir="$REPO_CACHE/screensavers-$saver"
    echo "=========================================="
    echo "Building Debian Package via cargo-deb: $saver"
    echo "=========================================="
    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir"
        git clone "https://github.com/local76/screensavers-$saver.git" "$dir"
    fi
    (cd "$dir" && cargo deb -o "$OUTPUT_DIR")
}

if [ -n "$1" ]; then
    build_single_deb "$1"
else
    for saver in "${SCREENSAVERS[@]}"; do
        build_single_deb "$saver"
    done
fi
