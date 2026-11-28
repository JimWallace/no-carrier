### Added

- **`carrier crack`, a code-cracking prototype.** Instead of fighting a
  server, match its hidden code: put symbol cards on a board of 4 slots,
  guess, and read Mastermind feedback (HIT: right symbol, right slot; NEAR:
  right symbol, wrong slot) before the alarm fills. A PROBE reveals one
  slot; a DIAL turns to another symbol where it stands. `--sim N` plays N
  cracks with a bot, for tuning. Its numbers are in `crack.json`. See
  `docs/design/addendum-03-code-cracking.md`.
