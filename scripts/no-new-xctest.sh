#!/usr/bin/env bash
set -euo pipefail

# Every test is on Swift Testing (CLAUDE.md, "Testing Conventions"). This
# guard fails when a file under Tests/ imports XCTest. One framework keeps one
# set of conventions and one report format, which
# scripts/check-no-skipped-tests.sh reads.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# shellcheck source=lib/grep-guard.sh
. "scripts/lib/grep-guard.sh"

actual=$(code_matches '^import XCTest$' Tests/)

if [ -n "$actual" ]; then
  echo "ERROR: a test file imports XCTest. Use Swift Testing:"
  echo "$actual" | sed 's/^/  /'
  exit 1
fi

count=$(grep -rl "^import Testing" Tests/ 2>/dev/null | wc -l | tr -d ' ')
echo "no-new-xctest: OK ($count file(s) on Swift Testing; 0 on XCTest)"
