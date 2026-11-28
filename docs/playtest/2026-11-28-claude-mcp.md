# Playtest: Claude through MCP (2026-11-28)

Claude played seven contracts through `carrier mcp`, as a careful player and
not as a bot: it read the telegraph, planned routes, and chose loot. It saw
only what the terminal shows (see `mcp-playtesting.md`, "The fog holds").
No rule or tuning number was changed. This is a report only.

## Build

The branch `claude/mcp-playtest-endpoint`, from `main` at `3e8a5b4` (M6),
with the bundled content. EXFILTRATION 4004 went through Claude Code's own
MCP client (the project `.mcp.json`). The other six went through a small
stdio client that sends the same JSON-RPC lines to the same binary.

## The contracts

| Objective | Seed | Outcome | Tick | Trace | Alert | INT | Replay |
|---|---|---|---|---|---|---|---|
| TAKEOVER | 1001 | jacked out at ROOT | 8 | 78 | 100 | 24 | `takeover-1001.json` |
| TAKEOVER | 2002 | jacked out at ROOT | 7 | 48 | 100 | 39 | `takeover-2002.json` |
| TAKEOVER | 3003 | jacked out, ROOT not reached | 8 | 51 | 99 | 28 | `takeover-3003.json` |
| EXFILTRATION | 4004 | won, FULL PAY | 7 | 12 | 42 | 6 | `exfiltration-4004.json` |
| EXFILTRATION | 5005 | won, FULL PAY | 7 | 11 | 40 | 38 | `exfiltration-5005.json` |
| EXFILTRATION | 6006 | won, CLEAN | 9 | 23 | 25 | 30 | `exfiltration-6006.json` |
| INFILTRATE | 7007 | jacked out, ROOT not found | 24 | 29 | 55 | 38 | `infiltrate-7007.json` |

The replays are in `replays-2026-11-28-claude-mcp/`. Each one plays back to
the outcome above:

```bash
.build/release/carrier replay docs/playtest/replays-2026-11-28-claude-mcp/takeover-2002.json
```

### What happened

- **TAKEOVER 1001.** Route 1 (VIRUS), 2 (REPAIR), 4 (VIRUS), 3 (sysop
  RELAY), 5 (RELAY). Alert reached 100 at tick 2. At ROOT (THE OPERATOR,
  BLACKICE, WATCHDOG), the telegraph showed 24 damage on turn 1 and 28 on
  turn 2 against 24 Integrity, and the FIREWALL grew from 35 to 42. I logged
  out on turn 2 and jacked out.
- **TAKEOVER 2002.** The best attempt: Integrity 40, Trace 23, an 18-card
  deck with two STACK SMASH, PROXY CHAIN, FIREWALL.DMN and three PAYLOAD.
  ROOT (THE OPERATOR, WATCHDOG, SENTRY) telegraphed 15 damage, Trace +12
  and HARDEN 4 each turn. My first turn did 6 net damage (STACK SMASH was
  resisted, and I had not run PROBE). At Trace +12 a turn, I had about five
  turns to do 89 damage plus the HARDEN. I logged out on turn 2.
- **TAKEOVER 3003.** Two RELAYs and SUDO early. I lost RELAY 5 to a CONTEST:
  I sent "take the loot" and "attack" in one batch and never looked at the
  map between them. That was my error, not the game's. Node 3 (sysop VIRUS,
  GATEKEEPER and BLACKICE) stalled for 9 turns at its KERNEL (see the
  GATEKEEPER stall below). Two WAITs to heal cost Trace +11 each. I never
  reached ROOT.
- **EXFILTRATION 4004.** I ghosted 2, 5 and 6. I attacked node 7 without a
  SCAN, and it was ROOT: LOGOUT at once, Trace +10. At the TARGET
  (GATEKEEPER, BLACKICE, WATCHDOG) the breach took 4 turns. Integrity went
  from 26 to 6. The 7 MB TRANSFER took 2 turns. A win, but close.
- **EXFILTRATION 5005.** SCAN before every attack, GHOST on every node. The
  TARGET had only a WATCHDOG. An easy win.
- **EXFILTRATION 6006.** I tried for CLEAN. I ghosted 2 nodes, then WAITed
  3 ticks while DORMANT (Alert 26 to 17, no Trace, no sysop move). During
  the 10 MB TRANSFER I played only PROXY cards. Alert at JACK OUT: 25, so
  CLEAN.
- **INFILTRATE 7007.** I claimed 1, 3 and 4 (DATA: +1 CPU) and ghosted 7.
  I held Alert under ACTIVE by WAITing about 10 ticks. In SUSPICIOUS, each
  WAIT let the sysop HARDEN a frontier node by 5. The two frontier nodes
  reached FIREWALL 46 and 34, and ROOT was still hidden behind them at
  tick 23. I jacked out.

## The bot findings, for a careful player

- **ROOT is unwinnable: holds.** Two careful attempts, one with full
  Integrity and a built deck. Each time the telegraph made the result clear
  in one turn. THE OPERATOR's ICE does 15 to 28 damage a turn, and HARDEN
  (4 to 7 a turn) almost cancels the best starter-plus-loot damage. In 2002
  the problem was also Trace: two ICE with TRACE +6 each end the contract in
  about five fight turns. A human with perfect play does not change this.
  The levers in `2026-11-27-m4-sim.md` still apply; Trace from ROOT's ICE
  should be on that list.
- **Quiet play is rare: does not hold for a careful player on stealth
  contracts.** No EXFILTRATION or INFILTRATE contract reached ACTIVE. The
  reason is WAIT: a tick with no noise takes 3 Alert, and while DORMANT a
  WAIT costs nothing (no Trace, no sysop move). In SUSPICIOUS a WAIT costs
  Trace +1 and lets the sysop HARDEN. That is a real cost, and it is the
  best decision in the stealth game. The bots never WAIT to cool down, so
  they do not see this. On TAKEOVER, quiet play does not exist (it starts at
  70 ACTIVE), as designed.
- **EXFILTRATION is too easy: mostly holds.** Three wins out of three, in 7
  to 9 ticks. The only danger came from my own blind attack into ROOT. A
  free WAIT while DORMANT also makes CLEAN reachable by patience alone,
  which removes the payout decision.
- **The GATEKEEPER stall: holds, and it is the least fun part.** Three
  fights stalled: TAKEOVER 3003 node 3 (9 turns; HARDEN 3 to 5 a turn on the
  KERNEL against one PAYLOAD about every second turn); EXFILTRATION 4004 at
  the TARGET (the FIREWALL went 13 to 12 to 13 for two turns); INFILTRATE
  7007 node 3 (two GATEKEEPERs, HARDEN 10 every second turn). INJECT MALWARE
  makes it worse: CORRUPT SECTOR fills the hand while the HARDEN goes on.

## Questions

### M2 and M3 (`2026-11-27-m2.md`, `2026-11-27-m3.md`)

1. **Is a 10-card starter deck interesting against one machine?** For the
   first fight, yes: BRUTE or PROXY against the telegraph is a real choice.
   By the third fight it is the same sum each turn. Loot (SUDO, STACK
   SMASH, SNIFFER.DMN) makes the decisions.
2. **Typing or number keys?** Names. Slot numbers move after each card that
   runs, so `play-1, play-2` in one batch runs the wrong card. Names do not
   move.
3. **Is the 40-column, 24-row screen readable?** Yes. Two gaps: a card's
   exploit tags show nowhere on the screen (only in names such as
   OVERFLOW), so "WEAK: OVERFLOW" is hard to use. The MCP view lists each
   card's tags.
4. **Does the sysop fight stall?** Yes. See the GATEKEEPER stall above.
5. **Is the map interesting at this size?** On TAKEOVER, the route choice
   (VIRUS for PAYLOAD, REPAIR to heal, RELAY for PROXY) is good. Under fog
   it is better: SCAN or attack blind is a real choice, and a blind attack
   into ROOT is a vivid punishment.
6. **Does PAYLOAD carrying create real decisions?** It creates clogged
   hands more than decisions. In 2002 and 3003 I drew 2 or 3 dead PAYLOAD
   in a 5-card hand before the KERNEL. In INFILTRATE, waiting filled the
   deck to its 20-card Storage with about 7 PAYLOAD.
7. **Is Trace pressure right?** On TAKEOVER, Trace comes from SWEEP (+8)
   and drift (+3) each tick: about 11 a tick, so about 9 ticks for a
   contract. That is the right length, but it makes healing at a REPAIR node
   a bad trade. Inside fights, SENTRY and THE OPERATOR add +4 to +12 a turn.
   LOGOUT costs +10.
8. **Did CONTEST and REINFORCE matter?** Yes, twice. I REINFORCEd a REPAIR
   node in 1001, and lost a RELAY in 3003 when I did not look.
9. **Was a DATA upgrade worth a fight?** +1 CPU (3 to 4 cycles) was the
   strongest single change I saw. It was worth a claim.
10. **THE OPERATOR: did it feel like a boss?** It felt like a wall. Its
    telegraph is clear, and it ends the fight in one look. I never saw its
    second phase.

### M5 (`2026-11-28-m5.md`)

1. **Does Noise make card choices interesting?** Yes, a little. SPOOF
   (noise -2) became a card I played every turn, and in a TRANSFER I played
   only PROXY cards. BRUTE's noise 2 is a tax I could not avoid.
2. **Could you stay below ACTIVE?** Yes, every time, by WAITing.
3. **Did GHOST feel like a real option?** On EXFILTRATION it was always
   right. A GHOST gives no loot, so my deck stayed at 10 cards for the whole
   contract. That is a fair trade, but it also means the new EXFILTRATION
   cards never showed up.
4. **Was the fog interesting, or was SCAN a tax?** Interesting. SCAN costs
   +2 Alert and one tick. PROBE scans the node for free from inside a
   fight. One blind attack walked me into ROOT.
5. **Is the Alert line clear?** Yes. The number and the state name are
   enough.

### M6 (`2026-11-28-m6.md`)

1. **Does a stealth contract feel different from TAKEOVER?** Yes, very.
   TAKEOVER is a damage race; stealth is about routes and patience.
2. **Is it too short?** 7 to 9 ticks and 3 or 4 fights. Short, and easy.
3. **Did the TRANSFER create tension?** Once (4004, Integrity 6). The
   escalation (WATCHDOG 5, 6, 8; BLACKICE 8, 9) was visible and could be
   blocked with PROXY each turn.
4. **Did the payout tier make you play quieter?** Yes, in 6006. But a free
   WAIT while DORMANT makes CLEAN a matter of patience. COMPRESS, SCRUB.SH,
   GHOST.DMN and NULL ROUTE never showed up, because I ghosted every node
   and a GHOST gives no loot.

## What felt wrong

- The GATEKEEPER stall, above all. A fight where nothing threatens and
  nothing moves.
- ROOT can be judged from one telegraph. There is no reason to fight it.
- PAYLOAD in hand before the KERNEL is a dead card.
- A WAIT while DORMANT costs nothing.
- The log says "ACCESS GRANTED" and "END OF SESSION: CAPTURED" before the
  CLAIM or GHOST choice. It reads as if the node was already taken.
- Two nodes in one network can have the same hostname (seed 4004: nodes 7
  and 9 are both `news.kestrel.net`; seed 2002 has two `mainframe` and two
  `ach-gw`). The test for the fog had to allow for this.
- REINFORCE N or SCAN N on a HIDDEN node gives a different refusal from a
  node number that does not exist ("?NODE 7 IS NOT CONTESTED" against
  "?NO NODE 12"). This tells a human how many nodes there are. ATTACK does
  not have this problem.
- The terminal (`PlaySession`) records a card that the fight engine refuses
  inside a contract (for example "?BRUTE.EXE NEEDS 1 CYCLES") as an
  action in the replay. The replay still plays back the same, because the
  action changes nothing. The MCP server leaves it out.

## Decisions

None. This note is input for the maintainer. The MCP choices are in
`docs/design/decisions.md`, "MCP playtest endpoint".

## The MCP interface itself

- The fog held. No view or log showed a hidden node, an unscanned machine,
  weak or resist tags before PROBE, or the draw order. The sysop's moves on
  hidden nodes read "ACTIVITY ON AN UNKNOWN NODE".
- Action ids (`attack-4`, `take-1-delete-5`) and typed commands both
  worked. Card names are safer than slot numbers in a batch.
- The compact view (the screen and the legal actions) was enough for most
  turns. The full view was useful at the start of a fight, for the rules
  text.
- After loot, look at the map before the next action. The sysop's next move
  is telegraphed there, and a batch can skip it.
