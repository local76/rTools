#!/bin/bash
# Builds all screensavers, cloning the single unified screensavers repo from
# github.com/local76 into a local cache. Output goes to <repo-cache>/dist/binaries/.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_CACHE="${SCREENSAVERS_REPO_CACHE:-$TOOLKIT_ROOT/.cache/screensavers}"
mkdir -p "$REPO_CACHE"

OUTPUT_DIR="$REPO_CACHE/dist/binaries"
mkdir -p "$OUTPUT_DIR"

SCREENSAVERS_DIR="$REPO_CACHE/screensavers"
if [ ! -d "$SCREENSAVERS_DIR/.git" ]; then
    rm -rf "$SCREENSAVERS_DIR"
    git clone "https://github.com/local76/screensavers.git" "$SCREENSAVERS_DIR"
else
    (cd "$SCREENSAVERS_DIR" && git pull)
fi

echo "=========================================="
echo "Building All Screensavers (Windows .exe/.scr via cargo)"
echo "Cache: $REPO_CACHE"
echo "=========================================="

(cd "$SCREENSAVERS_DIR" && cargo build --release)

SCREENSAVERS=(beams bounce bursts chaos cosmos disco flame glyphs gnats security storm tree)
for saver in "${SCREENSAVERS[@]}"; do
    if [ -f "$SCREENSAVERS_DIR/target/release/${saver}.exe" ]; then
        cp "$SCREENSAVERS_DIR/target/release/${saver}.exe" "$OUTPUT_DIR/"
    fi
done

echo "=========================================="
echo "Build complete!"
echo "Binaries in: $OUTPUT_DIR"
echo "=========================================="
