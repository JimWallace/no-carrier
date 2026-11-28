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

## Playing without building

A Mac that cannot run the Swift 6.4 toolchain (macOS 13 or 14, for
example) can still play. The `macOS binary` workflow builds a copy for
macOS 13 and later, for Intel and Apple Silicon, on every push to `main`.

1. Open the newest green run of the `macOS binary` workflow on `main`, in
   the repository's Actions tab.
2. Download the artifact `no-carrier-macos` and unzip it.
3. In Terminal, go to the unzipped folder. The browser marks a download as
   quarantined, so clear that mark first, then make the program runnable
   and play:

```bash
xattr -dr com.apple.quarantine .
```

```bash
chmod +x carrier
```

```bash
./carrier play
```

Keep the `.bundle` folder beside `carrier`: it holds the content.
