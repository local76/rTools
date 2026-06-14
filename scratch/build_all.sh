#!/bin/bash

PROJECTS=(
    "library"
    "app-helm"
    "app-pulse"
    "app-ignite"
    "app-scout"
    "screensaver-beams"
    "screensaver-bounce"
    "screensaver-bursts"
    "screensaver-chaos"
    "screensaver-cosmos"
    "screensaver-disco"
    "screensaver-flame"
    "screensaver-glyphs"
    "screensaver-gnats"
    "screensaver-security"
    "screensaver-storm"
    "screensaver-tree"
)

ROOT_DIR="/home/jeryd/Projects"

echo "=========================================="
echo "Compiling all local76 projects for Linux..."
echo "=========================================="

FAILED=()
SUCCEEDED=()

for proj in "${PROJECTS[@]}"; do
    path="$ROOT_DIR/$proj"
    if [ -d "$path" ]; then
        echo -e "\n------------------------------------------"
        echo "Building $proj..."
        echo "------------------------------------------"
        if (cd "$path" && cargo build); then
            SUCCEEDED+=("$proj")
        else
            FAILED+=("$proj")
        fi
    else
        echo "Directory $path does not exist, skipping."
    fi
done

echo -e "\n=========================================="
echo "Build Summary:"
echo "=========================================="
echo "Succeeded: ${#SUCCEEDED[@]} projects (${SUCCEEDED[*]})"
if [ ${#FAILED[@]} -ne 0 ]; then
    echo "Failed: ${#FAILED[@]} projects (${FAILED[*]})"
    exit 1
else
    echo "All projects compiled successfully! 🎉"
    exit 0
fi
