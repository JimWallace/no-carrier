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

## Addendum 01 — Contract objectives (2026-11-27)

- **Adopted as the backlog after M4, not started.** `addendum-01-contracts.md`
  defines M5 to M9. Work on it waits for the M3 playtest and the
  maintainer's go-ahead. It resolves kickoff Open Question 1 (run
  structure) in favour of an open BBS contract board.
- **Content paths.** Where the addendum names `Resources/objectives.json`
  and `Resources/modifiers.json` (§8), the files go in
  `Sources/CarrierContent/Content/`, as the M0 entry decided for all
  content.

## M4 — Bots and `carrier sim` (2026-11-27)

- **A new pure target, `CarrierSim`**, holds the bots and the simulation.
  The purity guard covers it, so the same seed gives the same report.
  Percentages are integer tenths.
- **Two bots** (§8). `random` picks uniformly from the legal actions.
  `greedy` is a simple, sensible player: it reinforces, rests on REPAIR when
  Integrity is low, waits for PAYLOAD when every KERNEL in reach is too
  strong, and attacks the cheapest target it can break, favouring VIRUS,
  DATA and REPAIR. In a fight it probes, shields against the telegraphed
  attack, starts daemons, then hits hardest. It logs out after 12 turns.
  It takes loot that beats BRUTE.EXE and the CPU upgrade. It is a
  yardstick, not an expert.
- **Run `i` uses seed `Seed.derive(seed, "run/i")`**, so one run of a
  simulation can be played again on its own.
- **A contract that passes `--limit` actions (5000) counts as stalled.**
- **The report** gives the endings, the average Trace at the end, ticks,
  fights and logouts, ROOT attempts and runs lost at ROOT, captures per
  node type, loot taken and offered per card, and DATA upgrade picks.

### Found with the simulation

- **ROOT is not winnable as tuned.** Over 500 contracts the greedy bot
  reaches ROOT in 276 and loses all 276; it wins none. ROOT's OMEGA 21064 is
  tier 3, so every ICE acts twice, and 64 MB gives it three programs
  (THE OPERATOR and two more): about 30 damage a turn against 40
  Integrity. Experiments with `--content` are in
  `docs/playtest/2026-11-27-m4-sim.md`. No number was changed: this is for
  the M3 playtest to confirm.

## M5 — Foundations (2026-11-28)

The maintainer gave the go-ahead for Addendum 01 before the M3 playtest.

- **Objectives are data** (`objectives.json`). M5 ships TAKEOVER (start
  Alert 70, fog off, no GHOST: the MVP) and `infiltrate`, a **test
  objective** for M5 only (TAKEOVER's win, start Alert 0, fog on, GHOST
  allowed), so that Noise, Alert, access and fog can be played before M6
  adds EXFILTRATION. Remove or replace it then. The first objective in the
  file is the default, and a contract replay without an objective is
  TAKEOVER.
- **Noise** is a field on each card (`noise`, plus `noisePerCycle` for
  DICTIONARY). The addendum's "SPOOF: Noise 0 and Alert −2" is
  `"noise": -2`: a negative noise lowers Alert and does not count as noise
  for decay. SNIFFER.DMN and FIREWALL.DMN make their noise when played.
  The fight engine does not know about Noise; the contract reads each
  `cardPlayed` event, so Alert moves during the fight.
- **ACTIVE stays for the contract** (open question 2, default "no"). Cards
  can still lower the number; the state does not change. This is also what
  keeps TAKEOVER exactly the MVP: at Alert 70, a SPOOF would otherwise drop
  it to SUSPICIOUS.
- **Trace drift comes from the Alert state** (0, +1, +3), replacing
  `network.traceDrift`. A quiet tick (no noise) lowers Alert by 3 below
  ACTIVE; SCAN, capture and access count as noise.
- **Sysop intents by state.** DORMANT announces nothing. SUSPICIOUS:
  HARDEN and SPAWN ICE. The addendum also lists a SUSPICIOUS "SCAN" for the
  sysop, which it does not define, so it is left out. ACTIVE: every intent,
  and REVOKE on a node the player has access to (weight 2). REVOKE uses the
  same mark as CONTEST, and REINFORCE clears either.
- **GHOST is an objective switch** (`ghost`). When AUTH falls (the last
  layer before any KERNEL), the contract pauses on `accessChoice`: CLAIM
  fights on (or captures, when there is no KERNEL), GHOST leaves with access
  (+3 Alert) and the fight's costs, and no loot. The choice comes once per
  fight. A node with access can still be attacked, to claim it.
- **Fog.** `on`: ENTRY SCANNED, nodes linked to a foothold DETECTED, the
  rest HIDDEN. `partial`: everything DETECTED. Capturing or ghosting a node
  scans it and detects its neighbours; PROBE in a fight scans the node.
  ATTACK needs a node to be shown (DETECTED or SCANNED).
- **SCAN is now a network action** (a tick, +2 Alert, DETECTED nodes only).
  The free node readout that M3 called `SCAN` is now `INFO`, and shows only
  what the player knows.
- **JACK OUT** (typed in full, so it cannot happen by accident) ends the
  contract as a win when the objective is met, else as `jackedOut`. For
  TAKEOVER the contract is already won the moment ROOT falls.
- **Regression guard** (§8): `takeoverStillPlaysAsTheMVP` replays the M3
  golden transcript with the Alert lines left out, and it matches the M3
  snapshot unchanged. The sim gives TAKEOVER the same numbers as in M4.
- **A third sim bot, `ghost`**: the greedy bot, but it GHOSTs every node
  except VIRUS, REPAIR and ROOT, and weighs a point of noise as three of
  damage. Both reports now show the highest Alert state each run reached.

### Found while building M5

- **Quiet play barely exists as tuned.** On `infiltrate`, the loud greedy
  bot reaches ACTIVE in 97% of 500 runs and the quiet `ghost` bot in 87%
  (93% before the review found that it re-attacked the nodes it had
  ghosted).
  The starter deck is loud (four BRUTE.EXE at 2 each), a fight plays about
  ten cards, a capture adds 10, and decay needs a tick with no noise,
  which a tick with a fight never is. Levers for the playtest: lower
  noise on starter cards, decay that does not need a silent tick, or
  higher thresholds. No number was changed.

### After the M5 review

- **Alert decays before the sysop announces its next intent**, so a sysop
  that drops to DORMANT at the end of a tick announces nothing.
- **An accessed node can always be attacked, to claim it**, even when no
  linked node is a foothold any more.
- **The fog hides the sysop's moves on HIDDEN nodes** in the log and on the
  map ("ACTIVITY ON AN UNKNOWN NODE"). A DETECTED node's number shows.
- **`JACK OUT` must be typed in full**; a prefix of JACK is not enough.
- **The sim's bots REINFORCE a REVOKE too**, and the quiet bot no longer
  attacks a node it has ghosted unless owning it pays.


## M6 — Exfiltration (2026-11-28)

- **EXFILTRATION** (`objectives.json`): start Alert 0, fog on, GHOST
  allowed, a TARGET, and the win `exfiltrate` (copy the file, then
  JACK OUT). `infiltrate` stays as a test objective for the foundation
  tests.
- **The TARGET** is drawn at contract start from a PRNG of its own
  (`objective`), so TAKEOVER's draws do not move: any node but ENTRY and
  ROOT, at least 2 hops from ENTRY. It becomes a DATA node, its KERNEL is
  removed ("replaced by the TRANSFER"), its file is 6 to 12 MB, and it is
  DETECTED at the start. The map shows it as `$`.
- **The TRANSFER** is not a layer. A TARGET fight carries a
  `TransferProgress`: breaching every layer starts the copy instead of
  capturing the node, and no CLAIM or GHOST is offered there. At the start
  of each later turn it moves the modem's `transferMB` (2400: 1, 9600: 2,
  14.4K: 3, 28.8K: 4, in `hardware.json`). When it is complete the player
  LOGs OUT with the file (with LOGOUT's usual Trace cost); leaving earlier
  keeps nothing. Exploits do nothing once the layers are down.
- **ICE escalates** by `network.transferEscalation` (1) on every ATTACK and
  TRACE intent for each turn the copy has run.
- **Payout tier** by the Alert state at JACK OUT: DORMANT clean, SUSPICIOUS
  full, ACTIVE half. Cash and logs come with runs (M8); until then the
  tier is an event, a field on the state and a line in the sim report.
- **The four new cards** join loot on EXFILTRATION only, through the
  objective's `extraRewards`, so TAKEOVER's loot draws do not move.
  COMPRESS adds 3 MB to a running copy (nothing before it starts).
  SCRUB.SH is `"noise": -5` with exhaust, like SPOOF. GHOST.DMN is a
  daemon passive (`quietFirstCard`) that the contract reads: the first
  card played each fight turn while it runs makes no noise. NULL ROUTE
  cuts ICE TRACE intents by 2 until the next turn.
- **Bots**: on EXFILTRATION the greedy and ghost bots head for the TARGET
  (each hop away costs 15 in their target score), hold a running copy with
  proxies, COMPRESS and daemons, log out when it completes, and JACK OUT
  with the file.

### Found while building M6

- **EXFILTRATION is short and easy as tuned.** Over 500 runs the greedy
  bot wins 90% in about 4 ticks and 3 fights; the quiet bot wins 89% with
  more clean payouts (28% against 22%). The TARGET is only 2 hops from
  ENTRY and a 6 to 12 MB file at 2 to 4 MB a turn takes 2 to 6 turns.
  Addendum open question 4 asks whether EXFIL is too short; the sim says
  yes. Levers: a larger `minDistance`, bigger files, faster escalation.

### After the M6 review

- **Only TAKEOVER is won by a capture.** On EXFILTRATION, capturing a
  node after taking the file goes on as normal; the contract ends at
  JACK OUT, with its payout.
- **GHOST.DMN silences noise, not SCRUB.SH or SPOOF**: a negative noise
  card still lowers Alert when it is the first card of a turn.
- **The TARGET never gets a KERNEL**, even when the sysop takes it back.
  So a boss's second phase never starts on a TARGET; no boss runs there
  today (THE OPERATOR is ROOT's, and ROOT cannot be a TARGET).
- **A card whose effects change nothing says so** ("COMPRESS: NO EFFECT"):
  an exploit once every layer is down, COMPRESS with no running copy. It
  still costs its cycles and makes its noise.
- **A map with no node far enough for the TARGET** takes the farthest
  eligible node instead of leaving the contract unwinnable.
- **The random bot JACKs OUT once it has the file**, so the sim reads it
  fairly on EXFILTRATION.

## Addendum 02, §1 — Rule sets and mechanic flags (2026-11-28)

Only §1 is built. Implants, auto-pressure, ascension levels and REIMAGE
(§2 to §4) wait for the MVP playtest and the maintainer's go-ahead.

- **`RuleSet` = flags + tuning** (`CarrierCore/Rules/`). It is composed in
  five layers, in this order: base (`flags.json` defaults and
  `tuning.json`), difficulty, run stage, contract, overrides. A later layer
  wins. The difficulty and run-stage layers exist but are empty. A layer
  sets only flags today. Tuning changes join a layer when the first layer
  needs one (the ascension ladder, §4.2).
- **The rules are in the state.** `ContractState.rules` and
  `GameState.rules` hold the composed RuleSet. The contract and fight
  engines read every tuning number from it, not from `content.tuning`.
  Tests can change one number in the state. The generators
  (`NetworkGenerator`, `MachineGenerator`, `SandboxFight`) still read
  `content.tuning`: no layer changes generator tuning yet, and the network
  is generated before the rules are composed. Event text
  (`SysopIntent.label`, the SWEEP amount) also reads `content.tuning`: it is
  display only, and `ContractEvent.line(content:)` has no rules. Change
  both when a layer first changes those numbers.
- **Replay headers.** `ContractReplay.rules` and `FightReplay.rules` record
  the whole composed RuleSet. `carrier replay` plays a replay under its
  recorded rules. It says so when the recorded flags or tuning differ from
  this build's defaults.
  A replay without `rules` (older than this change) runs under the
  objective's defaults (a fight replay: the base layer). The format stays 1.
  In a recorded flag set, **a flag that the file does not name is off**:
  the mechanic did not exist when the replay was recorded. A flag name that
  this build does not know is an error.
- **`flags.json`** is in `Sources/CarrierContent/Content/`, as the M0 entry
  decided for all content. Each entry has `name`, `description`, `default`,
  `category` and `requires`. The names are a closed Swift enum,
  `MechanicFlag` (`Flag` is taken by ArgumentParser), so a rule cannot
  misspell one. Validation needs exactly one entry per flag, known names in
  `requires`, and default rules that keep every requirement for every
  objective.
- **`requires` means all of.** The addendum's example says "or" in §1 and
  "+" in §2. A flag that is on needs every flag in its list on. "One of" can
  be added when implants need it.
- **Objective requirements.** An objective also needs flags to be winnable:
  `exfiltrate` needs `transfer` and `jackOut`. This is code
  (`ObjectiveWin.requiredFlags`), because the win rule is code. `--unsafe`
  lets a broken requirement or an unwinnable objective through. It never
  lets an ascension above 0 through.

### The flags, and where each one lives

| Flag | Category | Default | What it switches | Off |
|---|---|---|---|---|
| `alert` | core | on | Noise, Alert, Alert states, drift by state, decay (M5) | Alert does not move; the sysop is ACTIVE for the whole contract, as in the MVP |
| `revoke` | core | on | The sysop's REVOKE intent (M5) | The sysop never announces REVOKE |
| `ghost` | contract | off | CLAIM or GHOST when AUTH falls (M5) | The node is captured as before |
| `fog` | contract | off | Fog of war (M5) | Every node SCANNED |
| `scan` | core | on | SCAN as a network action (M5) | SCAN is refused |
| `jackOut` | core | on | The JACK OUT action (M5) | JACK OUT is refused |
| `transfer` | contract | off | The objective's TARGET and its TRANSFER (M6) | No TARGET is marked |
| `objectiveLoot` | contract | off | The objective's `extraRewards` in the loot pool (M6) | Only the shared pool |

- **`ghost` requires `revoke`.** REVOKE is the sysop's answer to access, so
  it is the paired control (§1, "Paired mechanics").
- **The core flags are on by default**, because M5 and M6 already shipped
  them and every objective uses them. With `alert` off, TAKEOVER plays the
  M3 transcript exactly, with no line filtered
  (`takeoverWithoutAlertIsTheM3Transcript`).
- **The objective is the contract layer.** Its fields keep their meaning in
  `objectives.json`, and the contract layer reads them as flags:
  `ghost` sets `ghost`; a `fog` other than `off` sets `fog` (the field also
  gives the mode); a `target` sets `transfer`; non-empty `extraRewards` sets
  `objectiveLoot`. The layer sets all four flags, on or off, for every
  objective. `startAlert`, the fog mode, the target spec and the extra
  cards stay objective parameters. They do not move to `flags.json`. This
  keeps `objectives.json` unchanged for playtesters' `--content` copies and
  for the M7 work on the other branch.
- **A flag forced on without an objective parameter.** `--flag fog=on` on
  TAKEOVER uses the mode `on`. `--flag transfer=on` or
  `--flag objectiveLoot=on` on an objective without a target or extra cards
  has no effect: there is nothing to switch on.
- **`--ascension N`** is accepted on `play`, `sim` and `rules`, and refuses
  every value but 0.
- **`carrier rules`** prints each flag, its category and the layer that set
  it, the contract layer's parameters, headline tuning and every flag's
  description. `--json` prints the whole RuleSet as a replay records it.
- **`carrier sim --compare <flag>`** plays the same seeds with the flag on
  and off. Other `--flag` settings apply to both. Both rule sets are checked,
  so a comparison that breaks a requirement needs `--unsafe`.
- **No rule or tuning number changed.** The golden snapshots did not change.
  `carrier sim --runs 500 --seed 1994` gives 357 flatlined and 143 traced,
  as before.

### Found while building it

- **`--compare fog` shows no difference for the bots.** The bots read a
  DETECTED node's machine through the fog, and a HIDDEN node is never
  attackable anyway. Fog changes only what a human sees. For the sim to
  measure fog, the bots must stop reading what the player cannot see.
- **`--compare alert` on TAKEOVER shows no difference.** TAKEOVER starts at
  ACTIVE, which never ends, so Noise has no effect there. This is the
  addendum 01 regression guard seen from the other side.

## Playing on older Macs (2026-11-28)

- **The macOS floor is 13.0, not 15.0.** The M0 floor was a guess, and
  nothing in the code needs macOS 15. The maintainer's Mac runs macOS 13
  and cannot run the Swift 6.4 toolchain.
- **CI builds a playable copy.** The `macOS binary` workflow builds
  `carrier` for Intel and Apple Silicon with the 13.0 floor, packs it with
  its content bundle, checks the minimum macOS of each slice, runs the
  packed copy from another directory, and uploads it as the artifact
  `no-carrier-macos`. `docs/playtest/README.md` says how to run it.
