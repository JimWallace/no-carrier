# Decisions log

Choices made where `kickoff.md` is ambiguous, and changes after playtests.
Newest last. Each entry names the brief section it refines. When this file
and the brief disagree, this file wins.

## M0 — Bootstrap (2026-11-27)

- **Repository tooling comes from Chickadee.** Kept: the `CLAUDE.md`
  conventions (Swift 6 strict settings, typed errors, no force unwraps,
  Swift Testing only), swift-format and SwiftLint with `--strict`, the
  guard scripts with self-test fixtures, the review agents
  (`diff-reviewer`, `test-runner`, `lint-guard`, `docs-audit`), the
  format and pre-push hooks, the session-start Swift install, changelog
  fragments, Dependabot with cooldowns, SHA-pinned actions, and a slim
  nightly steward. Left out: everything web, LTI, course, database, Docker,
  deploy, JupyterLite and UI-specific; the mutation, coverage and
  dead-code workflows (add them when the code is large enough to need
  them).
- **Versioning: changelog fragments, no auto-release.** There is nothing to
  deploy, so the maintainer cuts releases by hand with
  `scripts/assemble-release.sh` (the maintainer's choice).
- **No test-edit hook while prototyping** (the maintainer's choice). Golden
  snapshots change with every rule change, and a prompt on each would cost
  more than it protects.
- **Steward: the slim version** (the maintainer's choice): a red `main`,
  failed Dependabot updates, Swift pins, a monthly docs audit. It never
  changes a game rule or a number.
- **Chickadee has no issue or PR templates**, so there were none to copy.
- **No license file.** Chickadee's MIT license was not copied: the license
  for a game that may ship on Steam is the maintainer's decision.
- **Content lives in `Sources/CarrierContent/Content/`, not a root
  `Resources/` folder** (§8, repo layout). SwiftPM can bundle resources only
  from inside a target's directory. A small `CarrierContent` target owns the
  JSON and the Foundation-based loader, so `CarrierCore` and `CarrierGen`
  stay free of Foundation.
- **CI image `swift:6.4-noble`** for every Linux job, and swiftly on
  `macos-latest`. The SwiftLint plugin binary does not start on newer
  Ubuntu images (it links `libxml2.so.2`).

## M1 — Core types and the procgen readout (2026-11-27)

- **PRNG: xoshiro256\*\*, seeded through SplitMix64** (§8). It does not
  conform to `RandomNumberGenerator`, so the standard library's bounded
  draws and shuffles (whose algorithms are not promised across releases)
  cannot take it. Bounded draws use Lemire's method with rejection; the
  shuffle is Fisher-Yates. `PRNGTests` pins the first outputs, checked
  against an independent reimplementation.
- **Seed derivation: FNV-1a of the label, mixed with the parent by
  SplitMix64** (§6). Seeds print as `0x` and 16 hex digits; `--seed`
  takes that form or decimal.
- **Effects are JSON objects with an `op`** (§8), for example
  `{"op": "damage", "amount": 3, "hits": 2}`. SUDO is
  `ifLayer(auth, then: 10 damage, else: 4 damage)`, which is the brief's
  "4, +6 on AUTH".
- **A card's rules text is generated from its effects**, so the text cannot
  drift from what the card does.
- **ICE patterns are lists of steps, each a list of intents** (§4), so
  BLACKICE's "ATTACK 5 + HARDEN 3" is one step.
- **Each OS family names the CPUs it runs on** (§6): PANES and LINNET on
  M486DX2/66 and PENTAGON 90, LUNARIS on SPARK-10, CORTLAND on 68040/33 and
  POWERCHIP 601, OPENVAULT on OMEGA 21064. Flavour, and it ties CPU tier to
  the family.
- **Each role has its own RAM, modem, layer-HP and ICE pools** in
  `tuning.json` (§4, §6). Neutral machines never get BLACKICE; ROOT is
  always OPENVAULT at 64 MB and 28.8K baud.
- **RAM scales layer HP by one HP per 16 MB** (§6 says "scales layer HP"
  and gives no number). ROOT's ranges are 26/26/20, so with 64 MB it comes
  to the brief's 30/30/24.
- **CPU tiers** (§6): every ICE program carries out one pattern step per
  turn at tiers 1 and 2, and two at tier 3. "Stronger ICE" at tier 2 is
  +2 on every ATTACK intent. Both numbers are in `tuning.json`.
- **Filesystems**: the family's fixed paths, 2 to 4 user homes and 1 to 3
  org files, from a child seed (`filesystem`) so they can be generated
  lazily. 8.3 systems get 8.3 file names.
- **No real product names in content.** Two path strings that named real
  systems were changed before the first commit.
- **`GameState`, `Action` and `Event` arrive with the fight in M2**, where
  they have rules to carry. M1 ships the PRNG, the content types and
  loader, and the generator.
