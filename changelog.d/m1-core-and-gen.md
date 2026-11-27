### Added

- **`carrier gen`.** Prints generated machines: OS, org, hostname, CPU,
  RAM, modem, ICE, security layers, weak and resist tags, and a small
  filesystem. The same seed always prints the same machines.
- **Content as data.** Cards, ICE, OS families, hardware, orgs and tuning
  load from JSON and are validated at start. `--content <dir>` loads a
  copy for tuning without a rebuild.
- **Seeded PRNG** (xoshiro256\*\*) and hierarchical seeds, so a seed
  reproduces everything it generates.
