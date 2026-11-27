# Scheduled maintenance

CI runs no model, so every recurring job that needs judgement runs on the
maintainer's machine, in one Claude Code scheduled task: the **nightly
steward**. It is the slim version of the Chickadee steward. Its prompt only
points at a file in the repository, so a change to a procedure is a reviewed
change to a file, not an edit to a prompt that nobody else can see.

| Task | When | Prompt |
|---|---|---|
| Nightly steward | Daily, a quiet hour of the maintainer's choice | Follow Tools/maintenance/nightly.md |

The steward runs these jobs (`nightly.md`, "Tonight's calendar"):

| Job | Procedure |
|---|---|
| Fix a red `main` and failed Dependabot updates | `dependency-failures.md` |
| Bump behind Swift package pins | `swift-pins.md` |
| Docs audit (monthly) | `audit-rotation.md` |

## Rules every job follows

- Read the root `CLAUDE.md` first and load the `steward` skill before
  driving a pull request.
- Every pull request carries the `steward` label and a branch named
  `steward/<job>-<date>`. Every pull request is authored by the
  maintainer's account, so the label is how the steward finds its own work.
- A pull request merges by auto-merge (squash) when every required check
  passes. A change to the "Rules" section of this file or of `nightly.md`
  waits for the maintainer.
- The steward never merges a red pull request by hand. It pushes to or
  merges only pull requests with the `steward` label, and Dependabot pull
  requests.
- **No game changes.** The steward never changes a game rule, a card, an
  ICE program, a tuning number or a map. Those are playtest decisions. It
  lists anything it notices in the report.
- Never skip, disable or quarantine a test, and never loosen a check, to get
  green. A job gets one re-run at most. No empty commits, and no closing and
  reopening a pull request to kick CI.
- One changelog fragment per pull request in `changelog.d/`. Never touch
  `VERSION`, `Sources/CarrierCore/CarrierVersion.swift` or `CHANGELOG.md`.
- Write pull request bodies, issues and comments in ASD-STE100 English, as
  the `steward` skill says, and end each with the Claude Code footer.
- Each job ends with a short result (found, opened, merged, left for the
  maintainer) that goes into the night report.

## Setting the task up

In the Claude desktop app on the maintainer's machine, create one scheduled
task: the schedule and prompt above, the NO CARRIER checkout as its folder,
a fresh worktree from `main` for each run, and the GitHub connector. Run it
once by hand and approve the tools it asks for, so that unattended runs do
not stop on a prompt.

In auto mode, Claude Code drops the broad `Bash` allow rule in
`.claude/settings.json`, and its safety check reviews each command. The
project settings therefore allow `gh pr merge` and `gh label create` by
name: a narrow rule stays in force in auto mode. Deny rules for
`gh pr merge` with `--admin` are a second guard against a bypass. Branch
protection on `main` (required checks) is the main one; turn it on before
the first unattended run.
