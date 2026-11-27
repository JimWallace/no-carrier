# Fix a red `main` and failed dependency updates (nightly)

Goal: `main` is green, and every Dependabot update that CI blocked is merged
or closed with a recorded reason. Follow the rules in
`Tools/maintenance/README.md`.

## 1. A red `main`

1. `gh run list --workflow swift-tests.yml --branch main --limit 1 --json conclusion,databaseId,headSha`
2. If it is red, find the root cause in the failed job's full log, not its
   tail. Re-run a job at most once, and only to show that the failure is not
   repeatable. Fix it on `steward/main-<date>`.

## 2. Dependabot pull requests

1. List the open pull requests by `app/dependabot`. For each one with a red
   required check, read the failed job's full log.
2. Fix the cause with commits on the Dependabot branch. Never rewrite that
   branch's history or force-push.
3. If the new version cannot work here, add an `ignore` entry with the
   reason to `.github/dependabot.yml` in its own pull request (auto-merge
   on), and close the Dependabot pull request with an explanation.
4. Turn on auto-merge for each Dependabot pull request that is green.
