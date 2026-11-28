### Added

- **Noise and Alert.** Every card makes Noise; Alert moves the sysop from
  DORMANT to SUSPICIOUS to ACTIVE, which sets its intents and the Trace
  drift. ACTIVE stays.
- **Access.** On objectives that allow it, breaching AUTH offers CLAIM or
  GHOST. A ghosted node can be moved through but gives nothing; an ACTIVE
  sysop can REVOKE it.
- **Fog of war, SCAN and JACK OUT.** Nodes are HIDDEN, DETECTED or
  SCANNED; `SCAN N` spends a tick to learn a node; `INFO N` shows what you
  know; `JACK OUT` ends a contract.
- **Objectives.** `--objective` on `carrier play` and `carrier sim`, with
  TAKEOVER (the MVP, unchanged) and the `infiltrate` test objective. A
  `ghost` bot for the sim, and the highest Alert state in its report.
