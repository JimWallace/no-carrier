#!/usr/bin/env bash
# Proves the built extension loads in Godot and drives the engine: imports
# the project (which registers the extension), starts a contract at a fixed
# seed, attacks node 1 and checks that the game reached the fight; then
# starts a crack run, holds a turn and checks that it reached turn 2.
#
# Usage: godot/scripts/smoke.sh path/to/godot
set -euo pipefail

godot="$1"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$here/project"

"$godot" --headless --path "$project" --import >/dev/null 2>&1 || true
output="$("$godot" --headless --path "$project" -- --mode contract --seed 1994 --actions attack:1 --quit 2>&1)" || {
    echo "smoke: Godot exited with status $?" >&2
    printf '%s\n' "$output" | tail -20 >&2
    exit 1
}
printf '%s\n' "$output" | grep "NO CARRIER" || true
if printf '%s\n' "$output" | grep -q "Cannot get class"; then
    echo "smoke: Godot did not load the extension" >&2
    exit 1
fi
if ! printf '%s\n' "$output" | grep -q "^NO CARRIER: .* PHASE FIGHT$"; then
    echo "smoke: the game did not reach the fight. Godot said:" >&2
    printf '%s\n' "$output" | tail -20 >&2
    exit 1
fi
echo "smoke: the extension loaded and attacked node 1"

output="$("$godot" --headless --path "$project" -- --mode crack --seed 1994 --crack-actions hold --quit 2>&1)" || {
    echo "smoke: Godot exited with status $? in crack mode" >&2
    printf '%s\n' "$output" | tail -20 >&2
    exit 1
}
if ! printf '%s\n' "$output" | grep -q "^NO CARRIER: CRACK .* TURN 2 PHASE CRACKING$"; then
    echo "smoke: the crack did not reach turn 2. Godot said:" >&2
    printf '%s\n' "$output" | tail -20 >&2
    exit 1
fi
echo "smoke: the crack run started and held a turn"
