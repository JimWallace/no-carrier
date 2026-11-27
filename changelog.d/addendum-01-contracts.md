### Added

- **Design addendum 01: contract objectives.** The plan for M5 to M9:
  Noise and Alert, access and GHOST, fog of war, seven objectives,
  modifiers, run Heat and the BBS contract board. Design only; nothing is
  built yet.

### Fixed

- **Linux CI test step.** It runs under bash. The container's default `sh`
  rejected `set -o pipefail`, so the job failed before any test ran.
