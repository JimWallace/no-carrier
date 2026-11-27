#!/usr/bin/env bash
set -euo pipefail

# No `@unchecked Sendable`, in Sources/ or Tests/ (CLAUDE.md, "Coding
# Conventions").
#
# The attribute switches the compiler's data-race check off for one type.
# Shared mutable state is an actor or a `Mutex`, which the compiler can
# check. A comment that explains the attribute does not make it acceptable.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib/grep-guard.sh
. "scripts/lib/grep-guard.sh"

offenders=$(code_matches '@unchecked[[:space:]]+Sendable' Sources/ Tests/)

if [ -n "$offenders" ]; then
  echo "ERROR: @unchecked Sendable, with or without a comment."
  echo
  printf '%s\n' "$offenders" | sed 's/^/  /'
  echo
  echo "The attribute turns the compiler's data-race check off. Make the type"
  echo "an actor, give its state a Mutex, or make it plainly Sendable."
  exit 1
fi

echo "check-unchecked-sendable: OK (no @unchecked Sendable)"
