# NO CARRIER — Addendum 02: Implants, Auto-Pressure, and Rule Sets

> Builds on `docs/design/kickoff.md` and `docs/design/addendum-01-contracts.md`.
> Commit at `docs/design/addendum-02-implants-and-rulesets.md`.
>
> **What applies when:**
> - **§1 (Rule sets and mechanic flags) applies now.** It's a standing architectural rule. If the MVP is mid-build, introduce it at the next convenient point, and no later than the end of M4.
> - **Everything else waits** until the MVP has been playtested and the user gives the go-ahead.
>
> All numbers are first guesses. Put them in data.

---

## 1. Rule sets and mechanic flags (applies now)

### Why
Mechanics will be introduced selectively: some only in later contracts, some only at higher difficulty (ascensions), some only in certain contract types, and some only as experiments. Every mechanic beyond the MVP core must therefore be **switchable**, so it can be playtested on its own, compared in the sim, and placed wherever it works best.

### The rule
- Every gameplay mechanic added after the MVP sits behind a **named flag**, and every tuning number lives in data.
- The active rules for a contract are a single **`RuleSet`** value (flags + tuning), built by layering:

```
base defaults
  → difficulty layer   (ascension level)
  → run-stage layer    (contract 1 / 2 / 3 escalation)
  → contract layer     (objective + modifiers)
  → overrides          (CLI / sim flags, for experiments)
```

- Later layers override earlier ones. The composed RuleSet is stored in GameState and written into the **replay header**, so every replay records exactly which rules were active.
- **Flag metadata** (in `Resources/flags.json`): name, description, default, category (`core` / `difficulty` / `experiment` / `contract`), and `requires: [...]`. Example: `implants` requires `reimage` or `implantRamUpkeep`. Building an invalid combination is an error, unless an explicit `--unsafe` override is given for experiments.
- **Paired mechanics:** mechanics that exist to *balance* another mechanic must be enabled with it, at every difficulty level. Only mechanics in the `difficulty` category may be held back for ascensions.

### Tooling
- `carrier play --ascension N --flag name=on|off --seed S`
- `carrier sim --runs 1000 --bot greedy --flag name=on|off` and `--compare name` (runs the same seeds with the flag on and off and reports the difference)
- `carrier rules [--ascension N] [--contract ...]` prints the composed RuleSet

### Testing
- Golden transcripts run under the **default** RuleSet and must not change when a new flag is added with its default value.
- Every flag gets at least one test with it on and one with it off.

---

## 2. Implants (node conversion)

### Concept
Right now the map feeds the deck (e.g. a Virus node puts Payload into your deck), but the deck can't change the map. **Implants** close that loop: the deck builds the map, and the map builds the deck. Node types are best thought of as **card generators**, so converting a node means choosing what your network feeds into your deck.

### Rules (flag: `implants`, category `core`, requires `reimage` + `implantRamUpkeep`)
- New card type: **IMPLANT**. It's played **during the fight on the node you want to convert**, and takes effect only if you **CLAIM** (capture) that node at the end of the fight. If you lose, LOGOUT or GHOST, the implant is wasted.
- Implants are **consumed** when played, like Payload. They're dead cards in fights where you don't want them, which is intentional.
- One implant per node. Implanting an already-converted node replaces the previous type.
- **Protected nodes:** ENTRY, ROOT, and any node flagged by an objective (TARGET, CONTROLLER, BACKDOOR) can't be converted. Nothing can be converted *into* ENTRY, ROOT or DATA.
- **Noise:** installing an implant adds +4 Alert (when Addendum 01's Alert exists).

### RAM upkeep (flag: `implantRamUpkeep`, paired control)
- Each converted node you own reserves **1 RAM for the rest of the contract**, which reduces the RAM available for daemons in every fight.
- New network action `UNINSTALL <node>`: free, doesn't use the tick's action, reverts the node to its original type and frees the RAM.
- This ties map strategy to the rig: each conversion costs you daemon capacity, and RAM upgrades now matter in two places.

### REIMAGE (flag: `reimage`, paired control)
- New sysop map intent `REIMAGE <node>`, telegraphed like CONTEST. Next tick the node reverts to its original type unless you `REINFORCE` it.
- Sysop targeting priority: converted nodes first, then the usual CONTEST logic.

### Node types

Existing types that implants can create: **RELAY, REPAIR, VIRUS.**

New types that only exist through conversion:

| Type | Effect while you own it |
|---|---|
| **BOUNCE** | Trace drift −1 per BOUNCE owned (drift can't go below 0) |
| **CACHE** | +4 Storage. If the sysop takes the node, you immediately lose random cards until you're back within Storage |
| **SNARE** | The next sysop CONTEST or REIMAGE aimed at it fails, and the sysop skips its following intent. The SNARE then reverts to its original type (single use) |
| **FAB** | Every 2 ticks, adds 1 random IMPLANT card to your deck (only if Storage has room) |

Keep the total number of node types at about 8 or fewer, so the map stays readable.

### Implant cards

| Card | Cost | Noise | Rarity | Notes |
|---|---|---|---|---|
| IMPLANT: VIRUS | 1 | 2 | Common | A forward Payload supply line |
| IMPLANT: RELAY | 1 | 1 | Common | |
| IMPLANT: BOUNCE | 1 | 1 | Common | |
| IMPLANT: REPAIR | 1 | 1 | Uncommon | |
| IMPLANT: SNARE | 1 | 0 | Uncommon | |
| IMPLANT: CACHE | 2 | 1 | Uncommon | |
| IMPLANT: FAB | 2 | 2 | Rare | Watch for snowballing |

**First test subset:** VIRUS, RELAY, BOUNCE only, in Takeover contracts. This needs nothing from Addendum 01.

### Sleeper implants (flag: `sleeperImplants`, category `core`, requires Addendum 01 access/GHOST)
- An implant can also be installed on a node you **GHOST** (access without claiming). The node stays sysop-owned, but the implant's effect applies **to you**, quietly. No capture Alert, and no RAM upkeep while it's a sleeper.
- CACHE can't be a sleeper. All other types can.
- New sysop intent (SUSPICIOUS or ACTIVE only): `AUDIT <node>`, telegraphed. If the node holds a sleeper, the implant is removed and Alert +10. REINFORCE doesn't block an audit; sleepers survive only by not being audited.

### Sysop implants (flag: `sysopImplants`, category `difficulty`)
- New sysop intent `CONVERT <own node> → <type>`, telegraphed. Sysop-only types:

| Type | Effect while the sysop owns it |
|---|---|
| **ICE NEST** | Fights on nodes adjacent to it start with +1 ICE program |
| **TRACER** | Trace drift +1 |
| **FIREWALL GRID** | Adjacent sysop nodes get +5 FIREWALL |

- If you capture a sysop-converted node, it reverts to its original type (and you can then implant it yourself).
- This is the "map attacks back" escalation, intended for later contracts and higher ascensions.

### Playtest questions
- Does placing an implant feel like a decision or a chore?
- Do conversion strategies dominate? (Use the sim with `--compare implants`.)
- Is REIMAGE pressure in the right range: threatening, but not so constant that conversion is pointless?

---

## 3. Auto-pressure experiment (flag: `autoPressure`, category `experiment`, default off)

### The question
Should the network fight itself between your fights, the way an auto-battler does? Entropy mode felt alive because something was happening everywhere at once. This experiment tests whether a little of that improves the game, or muddies the map as a tactical puzzle.

### Rules
- Every non-ENTRY, non-ROOT node holds a **pressure** value from −10 to +10, shown on the map as a small bar.
- Each tick, after production and before the sysop phase, each node changes by:
  `Δ = Σ(adjacent player-owned weights) − Σ(adjacent sysop-owned weights)`
  Weights: VIRUS = 2, all other types = 1. (Sysop TRACER/ICE NEST don't add weight, for now.)
- At **+10**, a neutral node flips to the player, and a sysop node flips to **neutral** (never directly to the player; the Kernel/Payload rule still applies to full captures). The pressure then resets to 0.
- At **−10**, the reverse: a player node flips to neutral (ENTRY is exempt), and a neutral node flips to the sysop.
- Fights and intents still override pressure. Capturing a node resets its pressure to 0.
- Tuning knobs: the threshold, the weights, and a per-tick cap on |Δ|.

### Evaluation
- Run the sim with `--compare autoPressure` across several seeds and bots. Look at contract length, win rate, and how many ownership changes came from pressure vs fights.
- Playtest questions: Does the network feel alive? Do fights still feel like they matter most? Can you still read the map and plan a tick ahead?
- **Outcomes:** keep it as core, move it to an ascension/difficulty flag, keep it for specific contract types, or drop it.

---

## 4. Difficulty and progression structure

Mechanics come in through three separate dials. All of them use the RuleSet layers from §1.

### 4.1 Within a run (run-stage layer)
A draft escalation for a 3-contract run:

| Contract | Introduces |
|---|---|
| 1 | MVP rules + player implants (if enabled). Teaches the core |
| 2 | Alert/stealth objectives become available on the board; the sysop gets AUDIT |
| 3 | `sysopImplants` on; the map fights back |

### 4.2 Across runs (ascension layer)
One rule per level, cumulative. Only `difficulty`-category flags and tuning go here. Draft ladder:

| Level | Change |
|---|---|
| A1 | Elite ICE appear more often |
| A2 | Every contract starts with Alert +20 |
| A3 | Trace drift +1 |
| A4 | `sysopImplants` from contract 2 onward |
| A5 | REIMAGE needs 2 REINFORCEs to block |
| A6 | One fewer Virus node per map |
| A7 | A CORRUPT SECTOR in your starting deck |
| A8 | Every contract has at least 1 modifier |
| A9 | `autoPressure` on, with the sysop weighted ×1.5 (if the experiment survives) |
| A10 | Sysop gets 2 map intents per tick |

### 4.3 Per contract (contract layer)
Some mechanics exist only in certain objectives or modifiers, such as CRASH in Partition (Addendum 01). This is already data-driven through objectives and modifiers.

### Principle
**Difficulty mechanics can be held back. Balance controls can't.** If a mechanic exists to keep another one in check (REIMAGE and RAM upkeep for implants), it ships wherever that mechanic is enabled. The `requires` metadata in §1 enforces this.

---

## 5. Milestones

Ordering relative to Addendum 01 will be decided after the MVP playtest. Suggested:

- **Now / by end of M4: Rule sets.** RuleSet, flag metadata, layering, the replay header, the CLI/sim flags, and `carrier rules`. Since the MVP has no optional mechanics yet, this is mostly scaffolding: tuning flows through RuleSet.
- **I1 — Implants (Takeover only):** IMPLANT card type, VIRUS/RELAY/BOUNCE, RAM upkeep, UNINSTALL, REIMAGE. Sim comparison. *Can come straight after M4, before any of Addendum 01.*
- **I2 — Full implant set:** REPAIR, SNARE, CACHE, FAB; implant rewards and FAB production.
- **I3 — Auto-pressure experiment:** behind its flag; sim comparison + playtest; decide where it lives.
- **I4 — Sysop implants:** CONVERT, ICE NEST / TRACER / FIREWALL GRID, as a difficulty flag.
- **I5 — Sleeper implants:** after Addendum 01's M5 (needs access/GHOST and Alert), with the AUDIT intent.
- **With multi-contract runs (Addendum 01, M8):** the run-stage and ascension layers, `--ascension`, and the A1–A10 draft.

---

## 6. Open questions (defaults in bold)

1. Should an implant take effect on CLAIM only, or also when you win the fight and choose GHOST? (**CLAIM only**, unless `sleeperImplants` is on.)
2. RAM upkeep of 1 per implant: too harsh with a starting RAM of 6? (**Try 1**; the sim will show it.)
3. Should UNINSTALL be free, or cost the tick's action? (**Free.**)
4. Should auto-pressure affect sysop nodes at all, or only neutral nodes? (**Both, but sysop nodes only drop to neutral.**)
5. Is the ascension ladder ordered sensibly? (**Draft only**; reorder after playtesting.)

---

## 7. Working agreements

The same as the kickoff, plus one: **no new gameplay mechanic without a flag.** When adding one, register it in `flags.json` with its category and `requires`, add on/off tests, and note in `docs/design/decisions.md` where it's intended to live (core, contract, run stage or ascension).
