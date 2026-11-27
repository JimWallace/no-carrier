#!/usr/bin/env bash
set -euo pipefail

# The pure targets stay pure (CLAUDE.md, "Determinism").
#
# CarrierCore and CarrierGen hold every rule and every generator, and
# CarrierSim the bots, whose reports must be the same for the same seed. A replay is
# a seed plus an action log, and it must reproduce a game exactly on any
# machine, so these two targets may not reach anything that differs between
# runs or between platforms:
#
#   - Foundation, Dispatch or the C library: I/O, clocks and locale-dependent
#     formatting live in carrier-cli and CarrierContent.
#   - The standard library's randomness (`random(in:)`, `shuffled()`,
#     `randomElement()`, `SystemRandomNumberGenerator`). Its algorithms are
#     not specified and can change between Swift releases. Use the seeded
#     `Xoshiro256StarStar` that lives in GameState.
#   - `hashValue` and `Hasher`: Swift seeds them per process.
#   - Floating point: rules use integer arithmetic only, so a percentage is an
#     Int out of 100.
#
# Dictionary and Set iteration order is also per process. A grep cannot see
# an iteration, so that rule is enforced by review (diff-reviewer) and by the
# golden-transcript tests, which fail on any order change.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib/grep-guard.sh
. "scripts/lib/grep-guard.sh"

pure=(Sources/CarrierCore Sources/CarrierGen Sources/CarrierSim)
status=0

report() {
  local title="$1" hits="$2"
  if [ -n "$hits" ]; then
    echo "ERROR: $title"
    printf '%s\n' "$hits" | sed 's/^/  /'
    echo
    status=1
  fi
}

report "a pure target imports Foundation, Dispatch or the C library." \
  "$(code_matches '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|internal|package)[[:space:]]+)?import[[:space:]]+(Foundation|FoundationEssentials|FoundationInternationalization|Dispatch|Glibc|Musl|Darwin|WinSDK)\b' "${pure[@]}")"

report "a pure target uses the standard library's randomness. Use Xoshiro256StarStar." \
  "$(code_matches '(SystemRandomNumberGenerator|\.random\(|\.shuffled?\((\)|using:)|randomElement\()' "${pure[@]}")"

report "a pure target reads a per-process hash. Hash seeds change on every run." \
  "$(code_matches '(\.hashValue\b|\bHasher\()' "${pure[@]}")"

report "a pure target uses floating point. Rules use integer arithmetic only." \
  "$(code_matches '\b(Double|Float|Float16|Float32|Float64|CGFloat)\b' "${pure[@]}")"

if [ "$status" -eq 0 ]; then
  echo "check-core-purity: OK (${pure[*]} are free of I/O, randomness, hashing and floating point)"
fi
exit "$status"
