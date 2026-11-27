# Docs audit (first Saturday of the month)

Goal: the documentation agrees with the code, with the findings filed as an
issue and the clear ones fixed. Follow the rules in
`Tools/maintenance/README.md`.

1. Look for work that already exists:
   `gh pr list --state all --search "docs audit" --limit 5`, and the newest
   issue labelled `docs-audit`. If an open or merged pull request already
   fixes the issue, report it and stop.
2. Run the `docs-audit` subagent on the worktree. Give it the newest
   `docs-audit` issue as the previous audit.
3. File one issue titled "Docs audit (DATE)" with the label `docs-audit`.
   The body is the agent's report. If the agent found nothing, say so in the
   report and file no issue. If the previous `docs-audit` issue is open,
   close it with a comment that links the new one.
4. Check each finding again on `origin/main`. Fix only a finding that has
   one clear, mechanical fix: a wrong path, name, count or status line. A
   finding that needs a design decision stays in the issue.
5. Run `diff-reviewer` on the diff. Open the pull request titled
   "docs: fix drift from the YYYY-MM docs audit". Write "Fixes #N" only when
   it fixes every finding; otherwise write "Refs #N".
