#!/usr/bin/env bash
# Saves a screenshot of each component sheet (see Gallery.swift) into a
# folder, for designing the components from screenshots.
#
# Usage: godot/scripts/gallery.sh path/to/godot out-dir [sheet ...]
# With no sheet named, it saves them all. It needs a display; on a
# headless Linux machine, run it under xvfb-run.
set -euo pipefail

godot="$1"
out="$2"
shift 2
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sheets=("$@")
if [ "${#sheets[@]}" -eq 0 ]; then
    sheets=(cards card-states nodes ice fight-panels bars dialogs crack-cards crack-slots crack-guesses)
fi
mkdir -p "$out"
out="$(cd "$out" && pwd)"

for sheet in "${sheets[@]}"; do
    case "$sheet" in
        cards) size=1440x1320 ;;
        *) size=1440x900 ;;
    esac
    case "$sheet" in
        crack-*) mode=crack ;;
        *) mode=contract ;;
    esac
    "$godot" --path "$here/project" --rendering-driver opengl3 --resolution "$size" \
        -- --mode "$mode" --seed 1994 --gallery "$sheet" --screenshot "$out/$sheet.png" 2>&1 | grep "SCREENSHOT" || {
        echo "gallery: no screenshot for $sheet" >&2
        exit 1
    }
done
