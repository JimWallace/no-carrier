# Playtest notes

One file per playtest session, named `YYYY-MM-DD-<milestone>.md`, for example
`2026-12-01-m2.md`. Each milestone ends with one, written from the playtest
questions that the milestone names in `docs/design/kickoff.md` §9.

A note holds:

1. **Build.** The commit, and the command that was played (with its seed).
2. **Questions.** Each playtest question for the milestone, and the answer.
3. **What felt wrong.** Plain observations. No fixes yet.
4. **Decisions.** What changes because of this session. Each one also goes
   into `docs/design/decisions.md`.
5. **Replays.** A replay file that reproduces a bug, committed beside the
   note (`carrier fight --record`), with the command that plays it.
