### Added

- **`carrier crack`, a code-cracking prototype.** Instead of fighting a
  server, match its hidden code: put symbol cards on a board of slots,
  guess, and read Mastermind feedback (HIT: right symbol, right slot; NEAR:
  right symbol, wrong slot) before the alarm fills. A PROBE reveals one
  slot; a DIAL turns to another symbol where it stands. Three servers
  (`--server kiosk`, `corporate`, `root`) differ in code size, feedback
  (per-slot marks, counts, or hits only), alarm and interference (SCRAMBLE
  swaps your slots, ROTATE moves the code). `carrier crack` plays a run of
  all three, with a reward after each crack: take one of 3 cards, remove a
  card, or skip. HOLD ends a turn without a guess. `--sim N --values`
  reports what each reward card is worth per server. `--sim N` plays N
  cracks with a bot, for tuning. Its numbers are in `crack.json`. See
  `docs/design/addendum-03-code-cracking.md`.
- **The Godot frontend opens on the crack.** Click a card, then a slot;
  click two slots to swap; dials turn with arrows. Keywords in card text
  are bold, and hovering one shows what it means. `--mode contract` shows
  the map and the battle.
