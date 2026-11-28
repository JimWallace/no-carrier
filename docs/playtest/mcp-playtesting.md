# Playtesting with Claude through MCP

`carrier mcp` is an MCP server on standard input and output. Through it, a
Claude Code session plays contracts and fights and sees what a human player
sees: the 40-column screen, the hand, the ICE telegraph, the fogged map and
the legal actions. The server only drives `ContractEngine` and `Engine`.
It holds no rule.

## Build

Build the release binary once, and again after each pull:

```bash
swift build -c release --product carrier
```

The project `.mcp.json` starts `scripts/carrier-mcp.sh`. The script runs the
release binary, and builds it first if it is missing. It does not rebuild a
binary that exists, because a full build can take longer than Claude Code
waits for a server to start.

## Start a playtest session

Start Claude Code in the repository root:

```bash
claude
```

Claude Code asks once to approve the project server `no-carrier`. Approve
it. Then check that it is connected:

```text
/mcp
```

Ask for a playtest in plain words. For example: play three TAKEOVER
contracts with seeds 1001, 2002 and 3003, save each replay under
`docs/playtest/`, and write a playtest note.

## The tools

| Tool | What it does |
|---|---|
| `new_contract` | Starts a contract (`takeover`, `exfiltration`, `infiltrate`), with an optional seed. `flags` switches mechanics as `carrier play --flag` does, for example `["fog=off"]`; `unsafe: true` allows a combination that breaks a requirement. Returns the game id and the first view. |
| `new_fight` | Starts a sandbox fight (`carrier fight`): role `neutral`, `sysop` or `root`, a seed, and an optional PAYLOAD count. |
| `view` | The view now: the phase, the screen, the status, the map, the fight, and the legal actions with their ids. `detail`: `full`, `compact` or `none`. |
| `act` | One action: an id from `legal_actions` (`attack-4`, `play-2`, `ghost`, `take-1-delete-5`), or the text a human types (`ATTACK 4`, `BRUTE.EXE`, `END`, `JACK OUT`, `INFO 3`). Returns `ok`, `info` or `rejected`, the new log lines, and the view (compact by default). A rejected action changes nothing. |
| `log` | The last lines of the log. |
| `save_replay` | Writes the replay in the `carrier play --record` format. |
| `list_games` | The running games. |
| `end_game` | Forgets a game. |

Several games can run at once. Each game is deterministic for its seed. A
game started without a seed gets a random one, and every view shows it.

## The fog holds

The server shows only what the terminal shows. A HIDDEN node, and every
link to it, is not listed. A DETECTED node shows only its place on the grid.
The weak and resist tags show as `???` until PROBE runs. The draw pile is a
count, never an order. The sysop's PRNG and the rule state are never shown.
`Tests/CarrierMCPTests/FogTests.swift` checks this on every view of whole
contracts.

The seed is the one way around the fog. Every view shows it, as the
terminal does at the end of a game, and `carrier gen` or `carrier replay`
with that seed shows the whole network. In a playtest session, tell Claude
not to run them on a game in progress.

`save_replay` writes to the path it is given, relative to the repository
root, and overwrites a file that is there.

## Play a saved session again

`save_replay` writes a file that `carrier replay` reads:

```bash
.build/release/carrier replay docs/playtest/replays-2026-11-28-claude-mcp/exfiltration-6006.json
```

## Without Claude Code

The server reads one JSON-RPC 2.0 message per line. This line lists the
tools:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | scripts/carrier-mcp.sh
```
