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
