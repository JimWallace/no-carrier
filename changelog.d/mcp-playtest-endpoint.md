### Added

- **`carrier mcp`, an MCP server for playtests.** A Claude Code session can
  play contracts and sandbox fights through it and see what a human sees:
  the 40-column screen, the hand, the ICE telegraph, the fogged map and the
  legal actions. Tools: `new_contract`, `new_fight`, `view`, `act`, `log`,
  `save_replay`, `list_games` and `end_game`. The project `.mcp.json`
  starts it; `docs/playtest/mcp-playtesting.md` tells how.
- **A playtest by Claude**: seven contracts, with replays, in
  `docs/playtest/2026-11-28-claude-mcp.md`.

### Changed

- **The terminal's pure parts are a library, `CarrierTerminal`**, so the
  terminal and the MCP server draw the same screens.
