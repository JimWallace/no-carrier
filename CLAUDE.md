# NO CARRIER — Project Context

## What This Is

A hacking deckbuilder set in an alt-1990s, played through a green-phosphor
terminal. Each contract is a small network that the player takes over node by
node (Descent 3 Entropy mode), and each node is a card fight (Slay the Spire)
against the machine's security layers and its ICE. NO CARRIER is a working
title.

The design brief is [docs/design/kickoff.md](docs/design/kickoff.md). Choices
made where the brief is ambiguous, and changes after playtests, are in
[docs/design/decisions.md](docs/design/decisions.md). When the two disagree,
`decisions.md` wins: it is newer.

**Process: prototype, playtest, adjust.** Build the smallest thing that can be
played, then let playtesting decide what comes next. Every number is a first
guess for tuning, not a specification. If something turns out unfun once it is
playable, say so.

---

## Shell Snippets (maintainer environment)

The maintainer runs **zsh with `interactive_comments` off**. When giving shell
commands meant to be pasted into a terminal — in chat or in `docs/` runbooks:

- **No inline `#` comments on a command line** — zsh parses `#` as a normal
  argument, so `cmd value  # note` fails with "too many arguments".
- **No apostrophes in explanatory text inside a code block** — an unmatched `'`
  drops zsh into a `quote>` continuation prompt and nothing runs.
- **One plain command per line.** Keep all explanation in prose *outside* the
  code block; never rely on `#` to annotate inside it.

---

## Architecture

| Target | Holds | May import |
|---|---|---|
| `CarrierCore` | Rules, state, actions, events, the seeded PRNG, the content *types* | the standard library only |
| `CarrierGen` | Procedural generation: machines, hardware, orgs, hostnames, filesystems (later: maps) | `CarrierCore` |
| `CarrierContent` | Reads the content JSON in `Sources/CarrierContent/Content/` into a `ContentPack` | `CarrierCore`, Foundation |
| `CarrierSim` | The bots and the headless simulation behind `carrier sim` | `CarrierCore`, `CarrierGen` |
| `carrier-cli` | The terminal frontend and the subcommands (`play`, `fight`, `gen`, `sim`, `replay`) | everything, ArgumentParser |

- **Pure reducers.** `Engine(content:).apply(action, to: state)` runs a
  fight and `ContractEngine(content:).apply(action, to: state)` runs a
  contract around it; each returns the new state and the events. State is value types. A frontend sends `Action`s and
  renders `Event`s, and never changes rule state itself. The future Godot
  frontend will read the same event stream, so every outcome that a player
  could see is an event.
- **No Godot yet.** `godot/` stays empty until the MVP (M3) has been
  playtested. Do not add SwiftGodot.

---

## Determinism

A replay is a seed plus an action log, and it reproduces a game exactly, on
any machine and any Swift release.

- **All randomness goes through `Xoshiro256StarStar`**, whose state lives in
  the game state. Never use `SystemRandomNumberGenerator`, `random(in:)`,
  `shuffled()`, `randomElement()`, `Date`, or a clock. The PRNG does not
  conform to `RandomNumberGenerator`, so the standard library's algorithms
  (which can change between releases) cannot take it.
- **Seeds are hierarchical** (run → network → node → filesystem). Derive a
  child seed with `Seed.derive(_:_:)`, which hashes a label with FNV-1a.
  Never use `hashValue` or `Hasher`: Swift seeds them per process.
- **`Dictionary` and `Set` iteration order is random per process.** Where
  order can reach a rule, an event, a PRNG draw or printed output, use an
  array or sort the keys.
- **Integer arithmetic only in rules.** A multiplier is a percent (`150`), and
  division rounds down.
- `scripts/check-core-purity.sh` fails `format-lint` when `CarrierCore`,
  `CarrierGen` or `CarrierSim` imports Foundation, Dispatch or the C library, uses the
  standard library's randomness, reads a hash, or uses floating point.
  Iteration order is the one rule it cannot see; the golden transcripts
  catch it.

---

## Content as Data

Cards, ICE, OS families, hardware, orgs, map templates and tuning constants
live in JSON under `Sources/CarrierContent/Content/`. A card's
effects are a list of `Effect` values, a small composable enum in
`CarrierCore` that the JSON names by `op`. A balance change edits JSON, not
Swift.

- **No tuning number in Swift.** Starting cycles, hand size, the weakness
  percent, layer HP ranges, the LOGOUT Trace cost: all in `tuning.json`.
- **A new card that the existing effects can express is a JSON change only.**
  A new effect is a new `Effect` case, its JSON coding, its rule, and a test.
- `ContentPack.validate()` checks every cross-reference (starter deck, ICE
  that injects a card, OS families that a generator names). `carrier` refuses
  to start on content that does not validate.
- `carrier fight --content <dir>` loads content from a directory instead of
  the bundle, so a playtester can tune without a rebuild.

---

## Terminal Voice (in-game text)

Everything the player reads is a 1994 terminal: upper case for commands,
cards and system messages, short lines, no emoji, no exclamation marks except
in an alert. The default layout is **40 columns** (an 80-column mode is a
later unlock). Allusive names only: an OS, a CPU or a company in the content
must never be a real product or trademark.

---

## Coding Conventions

- Swift 6, strict concurrency. Every target also turns on the upcoming
  features `ExistentialAny` (write `any P`), `MemberImportVisibility` (import
  each module whose members a file uses), `InternalImportsByDefault` (write
  `public import` where a public API shows another module's type),
  `InferIsolatedConformances` and `ImmutableWeakCaptures`, through
  `sourceSettings` in `Package.swift`. Warnings are errors.
- No `@unchecked Sendable`, in `Sources/` or `Tests/`.
  `scripts/check-unchecked-sendable.sh` fails `format-lint` on any site.
- Strict memory safety (SE-0458) is on for every target, tests included. Mark
  `unsafe` only where no safe API exists (the termios calls in the terminal
  layer), with a comment that says why.
- All `CarrierCore` and `CarrierGen` types are `Sendable` value types;
  persisted ones (state, actions, content, replays) are `Codable` and
  `Equatable`.
- Error types are explicit enums. Declare `throws(E)` where the set of errors
  is closed: the content decoder and validator, the replay reader.
- No force unwraps except in tests (and use `try #require` there too).
- Optionals are preferred over sentinel values (no `-1` for "missing").
- File names match the primary type they contain. One type per file unless
  the types are trivially small and closely related.
- `swift-format` owns formatting (`.swift-format`); SwiftLint owns correctness
  (`.swiftlint.yml`, from the `SwiftLintPlugins` dependency). Both apply to
  `Tests/`. Run `scripts/format.sh` before you commit; `scripts/lint.sh` and
  `scripts/swiftlint.sh` only check. `scripts/swiftlint.sh` passes `--strict`:
  raise a threshold in `.swiftlint.yml` rather than dropping it.
- Each `.swift-format` names every rule, `true` or `false`.
  `scripts/check-swift-format-config.sh` enforces this.
- **No environment variables.** Configure behaviour with a CLI flag on
  `carrier`, or derive it. Ask before adding one.

---

## Testing Conventions

- **Swift Testing only.** `scripts/no-new-xctest.sh` blocks `import XCTest`.
- Use `@Suite`, `@Test`, `#expect`, `#require`, `.serialized`, `.tags(...)`,
  `@Test(arguments:)` and `.timeLimit(.minutes(n))`. `@Suite struct` by
  default.
- **No force unwraps in tests.** Use `try #require(value)`.
- **Skip with a `ConditionTrait`, never with `Issue.record`.**
  `scripts/check-no-skipped-tests.sh` fails CI on any skip.
- **One rule, one test.** Every rule in `docs/design/decisions.md` and the
  brief has a unit test (layer carry-over, Kernel-only Payload, weakness
  math, RAM limit, and so on).
- **Golden transcripts.** `GoldenTranscriptTests` plays a fixed seed and a
  fixed action list and compares the event log with a file in
  `Tests/CarrierCoreTests/Snapshots/`. A rule or content change that alters
  the log regenerates the snapshot in the same commit: delete the file and
  run the test once, which writes it and fails; run it again and it passes.
  Read the diff of the snapshot before you commit it. A snapshot that changes
  with no rule or content change is a determinism bug.
- **Procgen snapshots.** The same seed gives the same machine, and a test
  pins it.

---

## Subagents and Hooks

The subagents are in `.claude/agents/`. Each one reports and does not edit.
CI runs no model, so a review that a session does not run does not happen.

- After a code change, run `test-runner` with a filter for the affected
  suites. Run it with no filter once before a push.
- Before a commit, run `diff-reviewer` on the uncommitted diff.
- `lint-guard` runs `scripts/format-lint.sh` and reports each failure.
- For drift between the docs and the code, run `docs-audit`. The nightly
  steward runs it once a month.
- The recurring jobs that need judgement (a red `main`, failed Dependabot
  updates, Swift pin bumps, the docs audit) run in one nightly scheduled task
  on the maintainer's machine, the steward: `Tools/maintenance/nightly.md`.
  Its pull requests carry the `steward` label.

The hooks in `.claude/hooks/`:

- `session-start.sh` installs the Swift toolchain on web sessions.
- `format-swift.py` runs `swift-format` on each Swift file that you edit.
- `pre-push-format-lint.py` runs `scripts/format-lint.sh` (every step of the
  CI `format-lint` job) before `git push`, and stops the push when a step
  fails. `scripts/test-claude-hooks.py` tests the hooks in CI.

There is no test-edit hook during prototyping (the maintainer's decision,
2026-11-27): golden snapshots change with every rule change.

**A new guard needs a fixture.** `scripts/check-guards.sh` applies each
fixture in `scripts/guard-fixtures/` and fails if the guard passes. A check
never seen to fail is not a check.

---

## Versioning

Semantic Versioning in the `0.y.z` phase. The version is in `VERSION` and
`CarrierVersion.current` in `CarrierCore`.

**A PR does not bump the version.** A PR must not touch `VERSION`,
`Sources/CarrierCore/CarrierVersion.swift` or `CHANGELOG.md` (the settings
deny list blocks them). Add **one fragment** under `changelog.d/` instead
(see `changelog.d/README.md`). The maintainer cuts a release by hand with
`scripts/assemble-release.sh`; there is no auto-release workflow.

---

## Milestones

Work milestone by milestone (`docs/design/kickoff.md` §9), in small commits.
**Do not build ahead into the backlog.** Each milestone ends with something
playable or inspectable, a playtest note in `docs/playtest/`, and a summary
for the maintainer: what is playable, how to run it, and the playtest
questions.

| Milestone | State |
|---|---|
| M0 Bootstrap | done |
| M1 Core types + `carrier gen` | done |
| M2 One fight, `carrier fight` | done; waiting for a playtest |
| M3 One contract, `carrier play` (the MVP) | done; waiting for a playtest |
| M4 Bots and `carrier sim` | done |
| M5 Foundations: Noise/Alert, access, fog, SCAN, JACK OUT ([addendum 01](docs/design/addendum-01-contracts.md)) | not started |
| M6 Exfiltration | not started |
| M7 Sabotage, Backdoor, modifier framework | not started |
| M8 Runs: BBS board, cash/Rep, logs and Heat | not started |
| M9 Recon, Partition, Cleanup | not started |

---

## What Not To Do

- Do not import Foundation (or Dispatch, or the C library) in `CarrierCore`
  or `CarrierGen`.
- Do not draw a random number from anything but the state's PRNG.
- Do not write a tuning number or a card stat in Swift.
- Do not start on Godot, sound, a CRT shader or Steam before the MVP has been
  playtested.
- Do not use a real product, OS, CPU or company name in content.
- Do not add an environment variable.
- Do not use `@unchecked Sendable`.

---

## Reference Material

[docs/README.md](docs/README.md) is the index of every document in `docs/`.
When you add a document, add its line there.
