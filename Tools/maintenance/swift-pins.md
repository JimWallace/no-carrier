# Bump behind Swift package pins (weekly)

Goal: the Swift package pins stay current. Follow the rules in
`Tools/maintenance/README.md`.

1. On the latest `origin/main`, run `swift package update --dry-run` (or
   `swift package update` in a scratch worktree and read the
   `Package.resolved` diff). If every pin is current, report that and stop.
   If an open pull request already bumps the same pins, report it and stop.
2. Update only the packages that are behind, one
   `swift package update <package>` per package, so nothing else moves. The
   SwiftLint plugin lands as its own pull request (`.github/dependabot.yml`
   says why).
3. `swift build`, then `swift test`, then `scripts/format-lint.sh`. Fix the
   fallout: warnings are errors, and strict concurrency and strict memory
   safety are on.
4. Branch `steward/swift-pins-<date>` from `origin/main`. Add a changelog
   fragment and open a pull request that lists each pin, old and new, with a
   link to each release's notes. Enable auto-merge.
5. If a bump needs a change you cannot make safely, open the pull request as
   a draft that explains the failure, and do not enable auto-merge.
