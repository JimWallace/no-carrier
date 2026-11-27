# NO CARRIER — Addendum 01: Contract Objectives

> Builds on `docs/design/kickoff.md`. **Don't start this until the MVP (M3) has been playtested** and the user gives the go-ahead. Everything here is a first draft for tuning. Put numbers in data, not code.

---

## 1. Design goal

Contracts should differ in **how you play**, not only in what counts as winning. The test for every objective: **does it change which cards you want in your deck?** If contract choice pulls deckbuilding in different directions, picking a contract becomes a strategic decision, much like choosing a path on the Slay the Spire map.

A contract is defined as:

```
Contract = Objective × Organization × Modifiers (+ map template, payout)
```

This resolves kickoff Open Question 1 in favour of **an open BBS contract board** (see §7).

---

## 2. New foundation systems

Most objectives need three new systems. Build them first, as their own milestone (M5).

### 2.1 Noise and Alert

**Alert** is how aware the sysop is of you. It's separate from **Trace**, which is how close the sysop is to finding you (the fail condition). Alert is a per-network meter from 0 to 100 with three states:

| State | Alert | Sysop behaviour | Base Trace drift per tick |
|---|---|---|---|
| DORMANT | 0–29 | No map intents | 0 |
| SUSPICIOUS | 30–69 | Defensive intents only (HARDEN, SPAWN ICE, SCAN) | +1 |
| ACTIVE | 70–100 | Full MVP intents (CONTEST, HARDEN, SPAWN ICE, SWEEP, REVOKE) | +3 |

- **Every card has a Noise value.** Playing it adds that much to Alert.
- **Capturing a node** adds +10 Alert. **Gaining access** (see 2.2) adds +3.
- **Decay:** −3 Alert per tick while DORMANT or SUSPICIOUS, but only if you made no noise that tick. **ACTIVE is sticky:** no decay, and only cards can lower it.
- ICE inside fights behaves as normal in every state (it's automated). The sysop's *map* behaviour is what changes.
- The UI shows the exact Alert number plus a state banner. (Whether it should be fuzzier is an open question.)
- **MVP compatibility:** each objective sets `startAlert`. Takeover starts at 70 (ACTIVE), which reproduces MVP behaviour exactly.

**Noise values for existing cards (first guesses):**

| Card | Noise | Card | Noise |
|---|---|---|---|
| BRUTE.EXE | 2 | PROXY | 0 |
| OVERFLOW | 1 | PROXY CHAIN | 1 |
| STACK SMASH | 2 | SPOOF | 0 (and Alert −2) |
| SUDO | 0 | HONEYPOT | 1 |
| SETUID | 1 | PROBE / GREP / CRON / DEFRAG | 0 |
| INJECT | 1 | SNIFFER.DMN | 1 on play |
| PHISH | 0 | FIREWALL.DMN | 1 on play |
| FORKBOMB | 3 | KEYLOGGER.DMN / CLOAK.DMN | 0 |
| DICTIONARY | 1 per cycle | PAYLOAD | 2 |

### 2.2 Access vs. ownership

Add a new node state, **ACCESSED**: the player has breached the node but hasn't claimed it.

- **To gain access, breach FIREWALL + AUTH only.** No Kernel, so **no Payload is needed, even on sysop-owned nodes.** At the end of a fight where you've breached Auth, choose `CLAIM` (continue to Kernel if there is one; capture) or `GHOST` (take access and leave).
- **Adjacency** for `ATTACK` counts from owned **or** accessed nodes. You can slip through a network without owning it.
- Accessed nodes give **no production** and no relay bonus.
- An ACTIVE sysop gains a new intent, `REVOKE <node>`, which removes your access unless you reinforce the node.
- This sets up the core choice: **ghost through or claim and get loud.**

### 2.3 Fog of war

A node can be in one of three visibility states:

- **HIDDEN:** not shown.
- **DETECTED:** shown as `[????]`, with type, OS and hardware unknown. A node becomes DETECTED when it's adjacent to a node you own or have accessed.
- **SCANNED:** everything known. You get there through a new network action, `SCAN <detected node>` (uses the tick's action, +2 Alert), through PROBE during a fight, or by contract intel.

Each objective sets `fog: on | off | partial`. Takeover uses `off` (MVP behaviour).

---

## 3. Objectives

Common fail conditions, unless an objective says otherwise: Trace ≥ 100, Integrity 0, ENTRY lost.
New network action for every objective: `JACK OUT`, which ends the contract voluntarily and is scored as a success only if the objective is complete.

### 3.1 TAKEOVER (exists)
- **Win:** capture ROOT.
- **Config:** `startAlert 70`, `fog off`. Identical to the MVP.
- **Leaves logs:** yes, on every captured node (see §6).
- **Rewards:** a balanced deck heavy on Payload.

### 3.2 EXFILTRATION
- **Fantasy:** steal a file without being noticed.
- **Setup:** one DATA node is flagged `TARGET` and holds a file of 6–12 MB. Its location is known (DETECTED). `startAlert 0`, `fog on`.
- **Transfer layer:** in the TARGET fight, the KERNEL layer is replaced by a **TRANSFER** bar. Once Firewall and Auth are breached, the transfer advances automatically at the start of each turn at the target's baud rate (2400: 1 MB/turn, 9600: 2, 14.4K: 3, 28.8K: 4). ICE escalates each turn you stay. When the transfer is complete, you can `LOGOUT` with the file.
- **Win:** have the file and `JACK OUT`.
- **Payout tiers** by Alert at JACK OUT: DORMANT = full plus a "clean" bonus, SUSPICIOUS = full, ACTIVE = 50% and leaves logs.
- **Rewards:** quiet cards, Alert reduction, transfer acceleration.

### 3.3 SABOTAGE
- **Fantasy:** plant a logic bomb.
- **Setup:** a new node type, `CONTROLLER`, which is sysop-owned and has a Kernel. Its location is known. `startAlert 30`, `fog partial`.
- **Plant:** breach the CONTROLLER's Kernel with Payload. The bomb is armed, a 3-tick timer starts, and Alert jumps to ACTIVE.
- **Defuse:** each tick, the sysop telegraphs `DEFUSE <controller>`. It succeeds unless you `REINFORCE` the controller that tick.
- **Win:** the timer runs out. The contract succeeds automatically and you're disconnected.
- **Rewards:** lots of Payload, burst damage. It's a sprint, then a short hold.

### 3.4 BACKDOOR
- **Fantasy:** establish persistence.
- **Setup:** 2–3 nodes are flagged `BACKDOOR` (any type, known locations). `startAlert 50`. Once you own the first BACKDOOR node, the sysop goes ACTIVE and gets **2 intents per tick**.
- **Win:** own every BACKDOOR node at the same time for 5 consecutive ticks.
- **Rewards:** Proxies, daemons, Repair/Relay control. The sysop's counterattacks are the main pressure.
- *Post-MVP hook:* a successful Backdoor could give a free accessed node in a later contract on the same organization.

### 3.5 PARTITION
- **Fantasy:** take down the infrastructure.
- **New action:** `CRASH <node>`. You fight the node, but only the **FIREWALL needs breaching**. On a win, the node goes **OFFLINE** (removed from the graph) for 4 ticks, then reboots to its previous owner. Every card played in a CRASH fight has +1 Noise.
- **Win:** at the end of any tick, the sysop-owned region connected to ROOT contains no RELAY nodes.
- **Config:** `startAlert 40`, `fog off`.
- **Rewards:** bandwidth and cheap, fast fights. It's a graph puzzle about which links to cut.

### 3.6 RECON
- **Fantasy:** map the network for a client.
- **Setup:** `startAlert 0`, `fog on`, hard limit of 12 ticks.
- **Win:** every node SCANNED, then `JACK OUT`.
- **Payout:** scaled by Alert, as in Exfiltration. Lower risk and lower pay. A good early contract in a run.
- **Rewards:** draw, PROBE, light decks.

### 3.7 CLEANUP (needs multi-contract runs, §6)
- **Fantasy:** erase your tracks from an earlier job.
- **Setup:** regenerates a network you hit earlier (same seed), with `LOG` markers on the nodes where you left logs. An `AUDIT` timer runs: Tick limit = number of logs × 2 + 2.
- **New action:** `WIPE <node>`. You need access (FW + AUTH), and winning the fight removes that node's logs.
- **Win:** every log wiped before the audit.
- **Reward:** reduces run Heat (§6).

### 3.8 RIVAL (later, design still open)
- A third faction: a rival hacker AI with its own ENTRY, using sysop-like rules, racing you to ROOT. Rival-vs-sysop clashes are resolved abstractly (strength comparison).
- **Win:** you capture ROOT first. **Fail:** the rival does.
- Build it last. It's the most expensive objective, and it needs the faction code to generalize beyond player/sysop.

---

## 4. Modifiers

Modifiers are data-driven: tuning overrides plus a small set of hooks. A contract has 0–2 of them, and harder contracts have more.

| Modifier | Effect |
|---|---|
| GHOST CLAUSE | The contract fails if Alert reaches ACTIVE |
| HONEYPOT | 1–2 nodes are traps: capturing or accessing one sets Alert to ACTIVE and adds Trace +20. PROBE or SCAN reveals them |
| NIGHT SHIFT | Alert gains are halved until tick 8, then doubled |
| AUDIT | Hard tick limit |
| PAYPHONE | Trace drift ×2, but no logs are left |
| HARDENED | Every security layer +25% |
| FIBER BACKBONE | All machines run at 28.8K: faster Trace, faster transfers |
| INSIDER | Start with one extra node ACCESSED and SCANNED |
| NO VIRUS | No Virus nodes on the map |

---

## 5. New cards

These support the objectives. Add them to the reward pool when their objective ships.

| Card | Type | Cost | Noise | Effect |
|---|---|---|---|---|
| COMPRESS | Script | 1 | 0 | +3 MB transfer progress this turn |
| SCRUB.SH | Script | 1 | 0 | Alert −5; exhaust |
| GHOST.DMN | Daemon (RAM 2) | 1 | 0 | The first card you play each turn has Noise 0 |
| WIPE.SH | Script | 1 | 0 | Remove 1 log from this node; Alert −3 |
| DDOS | Exploit | 2 | 4 | 4 dmg ×3; double damage vs FIREWALL |
| NULL ROUTE | Proxy | 1 | 0 | 4 shield; ICE TRACE intents −2 this turn |

---

## 6. Logs and Heat (run-level consequences)

Requires multi-contract runs.

- **Logs:** at the end of a contract, a node gets a log if you captured it, or if Noise ≥ 6 was generated in a fight on it. Logs are recorded per organization and network seed.
- **Heat:** a run-level meter. Each log left behind adds Heat. Heat raises `startAlert` and Trace drift in later contracts, and Cleanup contracts start appearing on the board.
- Result: noisy play has consequences across the whole run, and quiet play pays off beyond a single contract.

---

## 7. The BBS contract board

Between contracts, the player dials into a BBS and picks one of 2–3 listed contracts. These are generated from objective × organization × modifiers, with risk and payout shown.

```
] -=[ THE DEAD LINE BBS ]=-   MSG BASE 3: JOBS
]
] 1. MERIDIAN TRUST    EXFIL     RISK **   $1,200  [GHOST CLAUSE]
] 2. KESTREL ONLINE    TAKEOVER  RISK ***  $2,000
] 3. ST. JEROME UNIV.  RECON     RISK *      $400  [NIGHT SHIFT]
]
] SELECT JOB #, OR (Q)UIT >_
```

- **Payout:** cash, to be spent in a shop added later, plus **Rep**, which unlocks higher-risk contracts on the board.
- Contract choice should be visible against your current deck: a loud deck should look at that Exfil job and wince.

---

## 8. Implementation notes

- **Objective** becomes a type with `setup(map, rng)`, `evaluate(state) -> ObjectiveStatus` (in progress / complete / failed + reason) and `payout(state)`. Contract definitions go in `Resources/objectives.json`, modifiers in `Resources/modifiers.json`.
- **Modifiers** = tuning overrides + a small enum of hooks (onTick, onCapture, onAlertStateChange, …). Avoid arbitrary scripting.
- **Noise** is a field on every card definition (default 0).
- **New events:** `AlertChanged`, `AlertStateChanged`, `NodeRevealed`, `AccessGained/Revoked`, `ObjectiveProgress`, `NodeOffline/Online`, `LogRecorded`.
- **Regression guard:** with `startAlert 70` and `fog off`, the M3 golden transcripts must still pass unchanged. Takeover must behave exactly as the MVP did.
- **Sim:** add per-objective bots (a stealth bot that prefers GHOST and quiet cards, a loud bot that claims everything). `carrier sim` reports results per objective, including how often each Alert state was reached.

---

## 9. Milestones (continuing from the kickoff)

**M5 — Foundations:** Noise/Alert, Access/GHOST/CLAIM, fog of war, SCAN, JACK OUT, Noise values on all cards. Takeover regression passes. *Playtest question: does Noise make card choices more interesting, or just more fiddly?*

**M6 — Exfiltration:** TARGET node, the TRANSFER layer, payout tiers, COMPRESS / SCRUB.SH / GHOST.DMN / NULL ROUTE. *Playtest question: does a stealth contract feel genuinely different from Takeover?*

**M7 — Sabotage + Backdoor + modifier framework:** CONTROLLER, the DEFUSE intent, BACKDOOR holds, and 4 modifiers (GHOST CLAUSE, HONEYPOT, NIGHT SHIFT, INSIDER).

**M8 — Runs:** BBS board, 3-contract run, cash/Rep (stub shop), logs and Heat, Integrity carrying between contracts.

**M9 — Recon, Partition, Cleanup:** CRASH/OFFLINE, WIPE, AUDIT.

**Later — Rival.**

---

## 10. Open questions (defaults in bold)

1. Should Alert be shown as an exact number or fuzzy? (**Exact + state banner.**)
2. Should an ACTIVE sysop ever calm down? (**No.** Only cards lower Alert once it's ACTIVE.)
3. Does Integrity carry between contracts in a run? (**Yes, partially:** rest at the hub heals.)
4. Does Exfil require "carrying" the file back to ENTRY, Descent-style? (**No for now.** LOGOUT with the file is enough. Revisit if Exfil feels too short.)
5. Are CRASHed nodes too strong in non-Partition contracts? (**CRASH is only available in Partition** until playtested.)

---

## 11. Working agreements

The same as in the kickoff: build milestone by milestone, keep content and tuning in data, log judgment calls in `docs/design/decisions.md`, end each milestone with how to play it and specific playtest questions, and say so plainly if something isn't fun.
