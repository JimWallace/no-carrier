#!/usr/bin/env bash
set -euo pipefail

# Starts `carrier mcp`, the MCP server for Claude Code playtest sessions
# (docs/playtest/mcp-playtesting.md). The project .mcp.json runs this script.
#
# It runs the release binary. When the binary is missing, it builds it first.
# A build writes only to stderr: stdout carries the JSON-RPC stream. It does
# not rebuild a binary that exists, because a full build can take longer than
# a client waits for a server to start. Build again after a pull:
#   swift build -c release --product carrier
# Arguments go to `carrier mcp`, for example `--content <dir>`.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v swift >/dev/null 2>&1; then
  for candidate in "$HOME"/swift/*/usr/bin; do
    if [ -x "$candidate/swift" ]; then
      PATH="$candidate:$PATH"
      break
    fi
  done
fi

bin_dir="$(swift build -c release --show-bin-path 2>/dev/null)"
if [ ! -x "$bin_dir/carrier" ]; then
  echo "carrier-mcp: building the release binary (once)" >&2
  swift build -c release --product carrier 1>&2
fi

exec "$bin_dir/carrier" mcp "$@"
