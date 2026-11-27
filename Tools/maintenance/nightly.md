# The nightly steward

One scheduled task runs every night on the maintainer's machine. Its prompt
is one line: `Follow Tools/maintenance/nightly.md`. The procedure files in
this folder stay the instructions for each job. This file decides what runs,
in which order, and when to stop.

## Rules

The rules in `Tools/maintenance/README.md` apply to every job. These are
added for the night:

- **Read the root `CLAUDE.md` first.** Load the `steward` skill before you
  drive a pull request.
- **The night has a clock.** Stop starting new work two hours after the run
  began. Then finish what is running, write the report (below), and stop.
- **Push early.** Open each pull request as a draft as soon as it has its
  first commit, with the `steward` label and a branch named
  `steward/<job>-<YYYY-MM-DD>`. If the run stops, the next night finds the
  work by its label.
- **Merge on green.** Mark a pull request ready and turn on auto-merge
  (squash) when the work is done. GitHub merges it when every required check
  passes. A change to the "Rules" sections waits for the maintainer.
- **Create the labels once.** If the `steward` or `steward-report` label
  does not exist, create it (`gh label create`).
- **No product work.** Do not take issues labelled `enhancement`, `design`
  or `playtest`, and do not make a change that needs a design decision. Put
  it in the report instead.

## Order of work

Do the work in this order. Each step that has nothing to do takes one line
in the report.

### 1. `main`

The newest `swift-tests.yml` run on `main`: red? Fix what a pull request can
fix (`dependency-failures.md`, section 1).

### 2. Last night's pull requests

List open pull requests with the `steward` label. For each: a red check, a
merge conflict or a branch behind `main` is work. Fix it on the same branch.
A draft from a run that was cut off: finish it.

### 3. Tonight's calendar

| Night of | Job | Procedure |
|---|---|---|
| Every night | Red `main`, failed Dependabot updates | `Tools/maintenance/dependency-failures.md` |
| Monday | Bump behind Swift pins | `Tools/maintenance/swift-pins.md` |
| First Saturday of the month | Docs audit | `Tools/maintenance/audit-rotation.md` |

### 4. Fill work

With the time left, take open issues labelled `tech-debt`, `maintenance` or
`tests`, oldest first. Skip one that a comment says a person is handling,
and one that another open pull request already covers. One work item is one
pull request.

## The report

Before you stop, file one issue titled `Steward night report (YYYY-MM-DD)`,
with the date the night started, and the label `steward-report`. Skip the
issue when every step had nothing to do. The maintainer closes it after
reading. It holds:

1. For the maintainer: decisions, and pull requests that wait for review.
2. Merged tonight: each pull request, one line each.
3. Open: each steward pull request and its state.
4. Skipped: each calendar job that did not run, and why.
5. Time: when the run started and stopped, and why it stopped.

Write it in ASD-STE100 English, as the `steward` skill says, and end it with
the Claude Code footer.
