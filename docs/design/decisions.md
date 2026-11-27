# Decisions log

Choices made where `kickoff.md` is ambiguous, and changes after playtests.
Newest last. Each entry names the brief section it refines. When this file
and the brief disagree, this file wins.

## M0 — Bootstrap (2026-11-27)

- **Repository tooling comes from Chickadee.** Kept: the `CLAUDE.md`
  conventions (Swift 6 strict settings, typed errors, no force unwraps,
  Swift Testing only), swift-format and SwiftLint with `--strict`, the
  guard scripts with self-test fixtures, the review agents
  (`diff-reviewer`, `test-runner`, `lint-guard`, `docs-audit`), the
  format and pre-push hooks, the session-start Swift install, changelog
  fragments, Dependabot with cooldowns, SHA-pinned actions, and a slim
  nightly steward. Left out: everything web, LTI, course, database, Docker,
  deploy, JupyterLite and UI-specific; the mutation, coverage and
  dead-code workflows (add them when the code is large enough to need
  them).
- **Versioning: changelog fragments, no auto-release.** There is nothing to
  deploy, so the maintainer cuts releases by hand with
  `scripts/assemble-release.sh` (the maintainer's choice).
- **No test-edit hook while prototyping** (the maintainer's choice). Golden
  snapshots change with every rule change, and a prompt on each would cost
  more than it protects.
- **Steward: the slim version** (the maintainer's choice): a red `main`,
  failed Dependabot updates, Swift pins, a monthly docs audit. It never
  changes a game rule or a number.
- **Chickadee has no issue or PR templates**, so there were none to copy.
- **No license file.** Chickadee's MIT license was not copied: the license
  for a game that may ship on Steam is the maintainer's decision.
- **Content lives in `Sources/CarrierContent/Content/`, not a root
  `Resources/` folder** (§8, repo layout). SwiftPM can bundle resources only
  from inside a target's directory. A small `CarrierContent` target owns the
  JSON and the Foundation-based loader, so `CarrierCore` and `CarrierGen`
  stay free of Foundation.
- **CI image `swift:6.4-noble`** for every Linux job, and swiftly on
  `macos-latest`. The SwiftLint plugin binary does not start on newer
  Ubuntu images (it links `libxml2.so.2`).

## M1 — Core types and the procgen readout (2026-11-27)

- **PRNG: xoshiro256\*\*, seeded through SplitMix64** (§8). It does not
  conform to `RandomNumberGenerator`, so the standard library's bounded
  draws and shuffles (whose algorithms are not promised across releases)
  cannot take it. Bounded draws use Lemire's method with rejection; the
  shuffle is Fisher-Yates. `PRNGTests` pins the first outputs, checked
  against an independent reimplementation.
- **Seed derivation: FNV-1a of the label, mixed with the parent by
  SplitMix64** (§6). Seeds print as `0x` and 16 hex digits; `--seed`
  takes that form or decimal.
- **Effects are JSON objects with an `op`** (§8), for example
  `{"op": "damage", "amount": 3, "hits": 2}`. SUDO is
  `ifLayer(auth, then: 10 damage, else: 4 damage)`, which is the brief's
  "4, +6 on AUTH".
- **A card's rules text is generated from its effects**, so the text cannot
  drift from what the card does.
- **ICE patterns are lists of steps, each a list of intents** (§4), so
  BLACKICE's "ATTACK 5 + HARDEN 3" is one step.
- **Each OS family names the CPUs it runs on** (§6): PANES and LINNET on
  M486DX2/66 and PENTAGON 90, LUNARIS on SPARK-10, CORTLAND on 68040/33 and
  POWERCHIP 601, OPENVAULT on OMEGA 21064. Flavour, and it ties CPU tier to
  the family.
- **Each role has its own RAM, modem, layer-HP and ICE pools** in
  `tuning.json` (§4, §6). Neutral machines never get BLACKICE; ROOT is
  always OPENVAULT at 64 MB and 28.8K baud.
- **RAM scales layer HP by one HP per 16 MB** (§6 says "scales layer HP"
  and gives no number). ROOT's ranges are 26/26/20, so with 64 MB it comes
  to the brief's 30/30/24.
- **CPU tiers** (§6): every ICE program carries out one pattern step per
  turn at tiers 1 and 2, and two at tier 3. "Stronger ICE" at tier 2 is
  +2 on every ATTACK intent. Both numbers are in `tuning.json`.
- **Filesystems**: the family's fixed paths, 2 to 4 user homes and 1 to 3
  org files, from a child seed (`filesystem`) so they can be generated
  lazily. 8.3 systems get 8.3 file names.
- **No real product names in content.** Two path strings that named real
  systems were changed before the first commit.
- **`GameState`, `Action` and `Event` arrive with the fight in M2**, where
  they have rules to carry. M1 ships the PRNG, the content types and
  loader, and the generator.

## M2 — One fight (2026-11-27)

- **The reducer is `Engine(content:).apply(action, to: state)`** (§8). The
  brief's signature has no content parameter; the engine holds the content
  pack instead of copying it into every state.
- **`GameState` is one fight in M2.** M3 adds the network around it.
- **Turn order** (§4): at the start of a turn Proxy and HONEYPOT reset,
  cycles refill (plus CRON), five cards are drawn, then each daemon fires
  in the order it started. `END` fires malware left in hand (TRACER),
  discards the hand, runs the ICE, and starts the next turn.
- **Hand limit 10** (`rig.maxHandSize`). A draw into a full hand stops.
- **Damage**: an exploit hit adds KEYLOGGER's bonus first, then the weak or
  resist percent, rounded down. A tag the OS is weak to beats one it
  resists. Multi-hit cards apply this per hit. DICTIONARY is one hit of
  5 x cycles. Daemon and HONEYPOT damage is not an exploit and takes no
  modifier.
- **Carry-over** (§4): excess carries from FIREWALL into AUTH only. Excess
  past AUTH is lost. Non-PAYLOAD damage on KERNEL is blocked and logged
  ("KERNEL BLOCKS 6: NEEDS PAYLOAD").
- **ICE effective numbers**: CLOAK's −1 comes off a TRACE intent before the
  modem multiplier; the tier-2 attack bonus is added to the printed
  number. The telegraph shows these effective numbers, as Slay the Spire
  shows final damage.
- **HONEYPOT** hits back once, on the first ICE attack after it is played;
  two HONEYPOTs add up into one bigger hit.
- **WATCHDOG** purges the daemon with the most RAM, the oldest on a tie,
  into the discard pile.
- **HARDEN** adds to the current layer and raises its bar's maximum.
- **DEFRAG** deletes malware from the hand first, then the discard pile.
- **SPOOF at Trace 0** does nothing and logs nothing.
- **Endings**: capture wins a tie with a trace-out in the same action.
  LOGOUT that fills Trace is NO CARRIER, not a logout. Integrity 0 ends the
  run (the brief's default).
- **Sandbox PAYLOAD**: against a machine with a KERNEL, `carrier fight`
  adds `sandbox.payloadVersusKernel` (3) PAYLOAD cards to the starter deck,
  because the sandbox has no VIRUS nodes. `--payload N` overrides it.
- **Both input modes are always on** (§7, open question 5): a digit on an
  empty prompt plays at once; anything else types a command, Tab
  completes it against the hand and the commands, a unique prefix is
  enough, Return submits. A name that is a card but not in hand gets
  "NOT IN HAND"; nonsense gets "?SYNTAX ERROR".
- **The screen fits a 24-row terminal**; on a taller one the log grows.
  Cards that cannot run now are dimmed. Trace blinks at 75% and over.
- **Replays**: `carrier fight --record FILE` writes the seed, role, PAYLOAD
  count and every action after each action; `carrier replay FILE` plays it
  back. Rejected actions are recorded too; they change nothing.
- **No bitmap font yet** (§7). It is a Godot-era asset; the TUI uses the
  terminal's font.

### Found while building M2 (for the playtest)

- **A KERNEL behind GATEKEEPERs can stall forever.** In the sysop golden
  transcript (seed 2600), two GATEKEEPERs add HARDEN 10 every other turn.
  The KERNEL reaches 20 before the three PAYLOADs come round, and nothing
  attacks or traces, so the fight neither ends nor threatens. Trace drift
  is per network tick, not per fight turn, so nothing in a fight forces the
  player out. Options for after the playtest: a per-turn Trace drift inside
  fights, a cap on HARDEN, or no GATEKEEPER pairs.

### After the M2 engine review

- **CLOAK's reduction is fixed for the whole ICE phase**, as it stood when
  END was pressed, so the TRACE the telegraph shows is the TRACE that
  lands even if WATCHDOG purges CLOAK first.
- **A hit reduced to 0** (a resisted 1, DICTIONARY at 0 cycles) logs
  "FIREWALL -0" instead of nothing.
- **A fight that starts at full Trace or 0 Integrity ends before turn 1.**
  This matters in M3, where both come in from the contract.
- **Validation** now refuses negative percents, a CPU tier with fewer than
  one intent per turn, and other negative tuning values.
- **The prompt reads only 0 to 99 as a card number.**

## M3 — One contract (2026-11-27)

Built at the maintainer's request before the M2 playtest, so the M2
playtest questions still stand.

- **Two reducers.** `Engine` stays the fight reducer and `GameState` stays
  one fight (the sandbox). `ContractEngine` is the contract reducer: it
  takes `ContractAction`s, holds the running fight inside
  `ContractPhase.fight`, and returns `ContractEvent`s, which wrap fight
  events in `.fight`. A Godot frontend reads one stream.
- **Map templates are one file, `maps.json`**, not `maps/*.json` (§8). Three
  templates (`spine` 9 nodes, `fork` 10, `ring` 9). Nodes sit on a 5 by 4
  grid and links join grid neighbours only, so the 40-column map draws them
  with `-` and `|`. Nodes are numbered 0 to 9; the player types the number.
  Validation checks one ENTRY, one ROOT, the grid and that every node can
  be reached.
- **Node types**: ENTRY and ROOT are fixed in the template; the rest are
  drawn from weights in `tuning.json` (RELAY 3, REPAIR 2, VIRUS 3, DATA 2).
  When no neutral VIRUS lands within 2 hops of ENTRY, the lowest-numbered
  open neutral node within 2 hops becomes one (§3).
- **One org per contract.** Every machine in a network shares the org; each
  node has its own seed (`node/N`), so its machine is the same whatever is
  generated first. Machines are generated when the network is, not lazily:
  the sysop changes them, so they are state.
- **ROOT runs THE OPERATOR** first (`requiredICE`), plus pool ICE for the
  rest of its count. THE OPERATOR's second pattern (`phaseTwo`) starts from
  its first step once the machine is down to its KERNEL: more Trace, and it
  injects TRACER (§4, "TRACE ramps in phase 2").
- **Tick order** (§3): the player's action (bandwidth 1), the fight and its
  loot, production (REPAIR, VIRUS in node order), the announced sysop
  intent, the next announcement, Trace +3, the check.
- **A fight carries back** Integrity and Trace whatever the outcome. Played
  PAYLOAD leaves the deck; malware the ICE injected does not come back.
  LOGOUT leaves the node exactly as it was before the fight.
- **Capture**: the node is the player's; loot is 3 different cards from
  `network.rewardPool` (take one or skip). A DATA node first offers its
  upgrade, once (+1 CPU, +2 RAM, +4 Storage, +10 max Integrity, which
  also heals 10). Capturing ROOT wins at once, with no loot.
- **Storage full**: loot needs a card deleted first (the CLI asks for its
  deck number); VIRUS produces nothing and says so.
- **Sysop intents**: a weighted kind among those that have a target
  (CONTEST 3, HARDEN 2, SPAWN ICE 1, SWEEP 2), then a random target.
  CONTEST targets a player node linked to a sysop node, ENTRY included,
  and marks it at once; REINFORCE clears the mark. An intent whose target
  changed hands by the end of the tick fails and says so. SPAWN ICE stops
  at 3 programs.
- **A node the sysop takes back** stands again at full HP and gains a
  KERNEL if it had none. Losing ENTRY ends the contract (§3).
- **The map's number keys attack**: pressing 4 on the map is `ATTACK 4`.
  REINFORCE, WAIT and SCAN are typed. SCAN is free and shows the machine
  but not its weak and resist tags (PROBE still does that).

### Found while building M3

- **The greedy test bot never wins.** Over 40 seeds it flatlines 30 times
  and is traced 10 times. It plays cards in hand order and never chooses
  its loot, so this says little about a human, but it is the first
  balance signal for M4.
- **The GATEKEEPER stall from M2 also stalls a contract**, because Trace
  does not move during a fight. The bot logs out after 15 fight turns to
  get past it. A human would too, but it is still a fight with no
  pressure.

### After the M3 engine review

- **Trace is checked before a capture** (§3, step 6): a fight that captures
  a node, ROOT included, with Trace at its maximum ends the contract as NO
  CARRIER.
- **A captured node keeps its machine as it was before the fight.** HARDEN
  inside the fight does not carry into a node the sysop later takes back.
- **Templates are checked for the layout rules**: ROOT 3 or 4 hops from
  ENTRY, the sysop holding ROOT and 2 or 3 more nodes, and an open neutral
  node within 2 hops of ENTRY for the VIRUS rule.
- **Replays record accepted actions only.**
