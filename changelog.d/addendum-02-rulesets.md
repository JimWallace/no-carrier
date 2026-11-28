### Added

- **Rule sets and mechanic flags** (addendum 02, §1). The rules of a
  contract are one RuleSet: mechanic flags and tuning, composed in layers
  (base, difficulty, run stage, contract, overrides). The state and the
  replay header hold it. `flags.json` lists the flags with their category
  and requirements.
- **Eight flags** for the mechanics added after the MVP: `alert`,
  `revoke`, `ghost`, `fog`, `scan`, `jackOut`, `transfer` and
  `objectiveLoot`. Their defaults keep every objective as it was.
- **`carrier play --flag name=on|off`** and **`--unsafe`**, also on
  `carrier sim`. **`carrier sim --compare <flag>`** plays the same seeds
  with the flag on and off and prints the difference.
- **`carrier rules`** prints the composed rules for an objective.
  `--json` prints them as a replay records them.
- **`--ascension`** is accepted and refuses every level but 0.
