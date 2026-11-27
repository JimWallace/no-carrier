---
name: steward
description: >
  Repo-specific guidance for an agent driving a NO CARRIER pull request to a
  mergeable state. Read on every CI failure, review comment and check-in.
---

# Stewarding a NO CARRIER pull request

This file is read when an agent wakes on a CI failure or review comment for a
NO CARRIER pull request. It covers what this repository does differently,
and how proactive to be. It does not grant anything: the harness rules it
sits under still forbid skipping or quarantining a test, pushing an empty
commit to kick CI, rewriting history on someone else's branch, and approving
or merging.

## Read a red check before believing it

- **`format-lint`** runs on the noble image only because the SwiftLint
  plugin binary needs `libxml2.so.2`. A SwiftLint "error while loading shared
  libraries" is that, not a lint finding.
- **`macos`** installs Swift with swiftly from the `swift-tools-version` in
  `Package.swift`. A failure in the install step is the runner image or the
  download, not the diff. Re-run once.
- **A golden-transcript failure** (`GoldenTranscriptTests`) means the event
  stream changed. That is expected when the pull request changes a rule or
  the content JSON, and the snapshot is regenerated in the same pull request.
  It is a bug when the pull request changes neither: look for a new
  iteration over a `Dictionary` or `Set`, or a PRNG draw that moved.

## Never bump the version

A pull request **must not touch** `VERSION`,
`Sources/CarrierCore/CarrierVersion.swift` or `CHANGELOG.md`. Add **one**
fragment under `changelog.d/` instead (see `changelog.d/README.md`). The
maintainer cuts releases by hand with `scripts/assemble-release.sh`.

## Run the guards before pushing, not after

Every step of the `format-lint` job runs locally in seconds, and the
pre-push hook runs them all (`scripts/format-lint.sh`). For the layers you
touched:

| Touched | Run |
|---|---|
| Swift | `scripts/format.sh`, then `scripts/lint.sh` and `scripts/swiftlint.sh` |
| `Sources/CarrierCore/`, `Sources/CarrierGen/` | `scripts/check-core-purity.sh` |
| a guard script | `scripts/check-guards.sh` |
| `.claude/hooks/` | `scripts/test-claude-hooks.py` |

`scripts/swiftlint.sh` passes `--strict`: every warning fails the build. If
a structural threshold causes real friction, raise it in `.swiftlint.yml`
rather than dropping `--strict`.

## Tests

- **Swift Testing only.** `scripts/no-new-xctest.sh` blocks `import XCTest`.
- **No force unwraps**, in tests either. Use `try #require(value)`.
- **A new guard needs a fixture** in `scripts/guard-fixtures/`.
  `scripts/check-guards.sh` applies each fixture's defect and fails if the
  guard passes. A check never seen to fail is not a check.
- **Do not weaken an assertion to get green.** Change one only when the
  behaviour it pins was changed on purpose, and say so in the pull request
  body.

## Prose

Repository prose, including pull request bodies and commit messages, is
written in ASD-STE100 English: short sentences, one idea each, plain
vocabulary. In-game text follows the terminal voice in `CLAUDE.md`.

## Shell snippets

The maintainer runs zsh with `interactive_comments` off. In anything meant
to be pasted into a terminal:

- No inline `#` comments on a command line.
- No apostrophes in explanatory text inside a code block.
- One plain command per line, with the explanation in prose outside the block.

## How proactive to be

**CI and tooling fixes** are wanted promptly. Diagnose, fix, verify, push.

**A change to a game rule or a tuning number is a design decision.** The
maintainer playtests and decides. Open the pull request, say plainly what
changes for the player, and let them decide. Record the decision in
`docs/design/decisions.md` once it is made.
