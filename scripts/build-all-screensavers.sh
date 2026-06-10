#!/bin/bash
# Builds all 10 screensavers, cloning each screensavers-<scene> repo from
# github.com/local76 into a local cache. Output goes to <repo-cache>/dist/binaries/.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_CACHE="${SCREENSAVERS_REPO_CACHE:-$TOOLKIT_ROOT/.cache/screensavers}"
mkdir -p "$REPO_CACHE"

OUTPUT_DIR="$REPO_CACHE/dist/binaries"
mkdir -p "$OUTPUT_DIR"

SCREENSAVERS=(beams bounce flame gnats bursts cosmos glyphs disco storm chaos)

get_repo_dir() {
    local saver="$1"
    local dir="$REPO_CACHE/screensavers-$saver"
    if [ ! -d "$dir/.git" ]; then
        rm -rf "$dir"
        git clone "https://github.com/local76/screensavers-$saver.git" "$dir"
    fi
    echo "$dir"
}

echo "=========================================="
echo "Building All Screensavers (Windows .exe/.scr via cargo)"
echo "Cache: $REPO_CACHE"
echo "=========================================="

for saver in "${SCREENSAVERS[@]}"; do
    echo "-> Building $saver..."
    dir=$(get_repo_dir "$saver")
    (cd "$dir" && cargo build --release)
    if [ -f "$dir/target/release/${saver}.exe" ]; then
        cp "$dir/target/release/${saver}.exe" "$OUTPUT_DIR/"
    fi
done

echo "=========================================="
echo "Build complete!"
echo "Binaries in: $OUTPUT_DIR"
echo "=========================================="
