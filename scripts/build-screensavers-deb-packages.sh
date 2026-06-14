#!/bin/bash
# Builds Debian (.deb) packages for all screensavers, cloning the single
# unified screensavers repo from github.com/local76 into a local cache.
# Optionally pass a single scene name as $1 to build just that one.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_CACHE="${SCREENSAVERS_REPO_CACHE:-$TOOLKIT_ROOT/.cache/screensavers}"
mkdir -p "$REPO_CACHE"

OUTPUT_DIR="$REPO_CACHE/dist/packages"
mkdir -p "$OUTPUT_DIR"

SCREENSAVERS_DIR="$REPO_CACHE/screensavers"
if [ ! -d "$SCREENSAVERS_DIR/.git" ]; then
    rm -rf "$SCREENSAVERS_DIR"
    git clone "https://github.com/local76/screensavers.git" "$SCREENSAVERS_DIR"
else
    (cd "$SCREENSAVERS_DIR" && git pull)
fi

build_single_deb() {
    local saver="$1"
    echo "=========================================="
    echo "Building Debian Package via cargo-deb: $saver"
    echo "=========================================="
    (cd "$SCREENSAVERS_DIR/$saver" && cargo deb -o "$OUTPUT_DIR")
}

if [ -n "$1" ]; then
    build_single_deb "$1"
else
    SCREENSAVERS=(beams bounce bursts chaos cosmos disco flame glyphs gnats security storm tree)
    for saver in "${SCREENSAVERS[@]}"; do
        build_single_deb "$saver"
    done
fi
