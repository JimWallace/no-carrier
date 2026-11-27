# NO CARRIER — Project Kickoff Brief

> Working title. A hacking deckbuilder set in an alt-1990s, played through a green-phosphor terminal.
> This brief is for Claude Code to bootstrap the repo and build a playable MVP.
> **Process:** prototype → playtest → adjust, in small iterations. Build the smallest thing that can be played, then let playtesting decide what comes next. All numbers here are first guesses for tuning, not specifications.

*This is the original brief, kept as written. Choices made where it was ambiguous, and changes after playtests, are in [decisions.md](decisions.md).*

---

## 1. The pitch

You're a hacker at a beige computer in the mid-90s. Each **contract** sends you into a small corporate network. You take it over node by node, entropy-style (Descent 3's Entropy mode), while the sysop fights back and a global **Trace** meter climbs. Each node you break into is a **card fight**, in the style of Slay the Spire, played with the programs in your **cyberdeck**. Take the root node and you win. Let Trace fill and you get **NO CARRIER**.

**Inspirations:** Slay the Spire 1 and 2 (combat, intents, rewards), Descent 3 Entropy mode (node production, virus carrying, territory), Hacknet / NetHack / *if else heart.break* (terminal fantasy, typed commands), Cyberpunk 2077 (cyberdeck as upgradeable rig), the Apple //e green screen (aesthetic).

---

## 2. Core structure (three layers)

1. **Run.** A sequence of contracts with downtime in between (shop, rest, upgrades). *The MVP has one contract only.*
2. **Network (contract).** A small node graph of 8–10 nodes, played in **ticks**. Each tick usually contains one node fight. Win by capturing the ROOT node.
3. **Node (fight).** A turn-based card fight against the machine's security layers and its ICE programs.

Pacing rule: **one network tick per node action.** The map advances together with the fights, so the player never has separate overworld bookkeeping turns.

---

## 3. Network layer (Entropy mode)

### Node ownership
Each node is owned by the **player**, the **sysop**, or nobody (**neutral**). The player starts with an ENTRY node. The sysop starts with ROOT and 2–3 nodes around it. Everything else starts neutral.

### Node types (while owned by the player)
| Type | Effect |
|---|---|
| ENTRY | Your foothold. Losing it = contract failed. |
| RELAY | +2 starting Proxy (shield) in every fight, per Relay owned |
| REPAIR | +3 Integrity per tick |
| VIRUS | Adds 1 **PAYLOAD** card to your deck per tick (only if Storage has room) |
| DATA | One-time reward on capture: choose a hardware upgrade (see §5) |
| ROOT | Capture it to win the contract (boss fight) |

### The virus-carrying rule (the key idea)
In Descent 3 you had to physically carry virus to enemy rooms. Here, **nodes owned by the sysop have a KERNEL security layer that only PAYLOAD cards can damage.** PAYLOAD only comes from Virus nodes, and it's consumed when played. So the player constantly weighs carrying more virus against clogging the deck with cards that are useless in neutral fights. Neutral nodes have no Kernel.

### A tick
1. **Player action.** Bandwidth = 1 action per tick to start. Choose one:
   - `ATTACK <node>`: must be adjacent to a node you own. Starts a fight.
   - `REINFORCE <node>`: cancels a sysop CONTEST on one of your nodes.
2. **Resolve** the fight, if there was one.
3. **Production:** Repair, Virus and similar nodes produce.
4. **Sysop phase:** resolve the intent announced last tick, then **telegraph the next one** (map-level intents, like Slay the Spire enemy intents):
   - `CONTEST <node>`: the node flips to the sysop next tick unless reinforced (sysop targets nodes adjacent to its own territory)
   - `HARDEN <node>`: +5 to one of that node's security layers
   - `SPAWN ICE <node>`: adds an ICE program to that node
   - `SWEEP`: Trace +8
5. **Trace** +3 (base drift).
6. **Check:** Trace ≥ 100 → NO CARRIER (contract failed). ROOT captured → contract complete.

### Map generation (MVP)
Start with 3–4 **hand-authored graph templates** (8–10 nodes; ENTRY on one side, ROOT about 3–4 hops away). Procgen fills in node types and machines. At least one neutral VIRUS node must be within 2 hops of ENTRY. Procedural topology comes later.

```
 [ENTRY]──[RELAY]──[VIRUS]
    │        │        │
 [DATA]──[REPAIR]──[s:RELAY]══[s:ROOT]
             │        ║
          [VIRUS]══[s:DATA]          s: = sysop-owned   ══ sysop links
```

---

## 4. Node fights (card combat)

### Security layers ("HP")
Damage goes to the current outer layer. **Excess damage carries over from Firewall to Auth, but stops at Kernel.**
- **FIREWALL** → **AUTH** → **KERNEL** (sysop-owned nodes and ROOT only; PAYLOAD-only)
- Breaching every layer = node captured.
- First-guess HP: neutral FW 10–20 / AUTH 10–20; sysop nodes add KERNEL 8–16; ROOT FW 30 / AUTH 30 / KERNEL 24.

### Player resources in a fight
- **Cycles** (energy) = deck CPU, refilled every turn. Start: 3.
- **RAM**: daemons (persistent programs) take up RAM while running. Start: 6.
- **Hand**: draw 5 per turn and discard the hand at end of turn (as in Slay the Spire).
- **Proxy** (shield): absorbs ICE attacks and resets each turn.
- **Integrity** (HP): **persists across the whole contract.** Start: 40.
- **Trace**: ICE TRACE intents add straight to the *global* network Trace.

### Turn order
Start of turn: draw 5, refill cycles, daemons trigger → player plays cards → `END` → discard hand → ICE carries out its telegraphed intents → ICE shows its next intents.

### Leaving a fight
- `LOGOUT` (any time): leave the fight, node unchanged, Trace +10.
- Integrity 0 → **run over** (MVP default; see Open Questions).

### Weakness tags
Exploit cards carry tags: `OVERFLOW`, `PRIVESC`, `INJECT`, `SOCIAL`. Each OS family is weak (×1.5, rounded down) or resistant (×0.5) to certain tags. `PROBE` reveals these. Before that, the UI shows `???`.

### ICE (enemy programs)
The machine's **CPU tier sets how many intents per turn**, and **RAM sets how many ICE programs it can run** (see §6).

| ICE | Intent pattern (cycles) |
|---|---|
| SENTRY | TRACE 3 → ATTACK 4 |
| BLACKICE | ATTACK 8 → ATTACK 5 + HARDEN 3 |
| WATCHDOG | PURGE DAEMON (removes your largest daemon) → ATTACK 5 |
| GATEKEEPER | HARDEN 5 → INJECT MALWARE (adds CORRUPT SECTOR to your discard pile) |
| THE OPERATOR (ROOT boss) | Two phases; mixes all of the above; TRACE ramps in phase 2 |

### Rewards
Capturing a node offers 1 card from a choice of 3, or skip. **Storage caps deck size** (start: 20). If you're full, you must delete a card to add one.

---

## 5. The cyberdeck (player rig)

| Component | Effect | MVP start |
|---|---|---|
| CPU | Cycles per turn | 3 |
| RAM | Daemon capacity | 6 |
| Storage | Max deck size | 20 |
| Modem | Network actions per tick (bandwidth) | 1 |
| Chassis | Max Integrity | 40 |
| Firmware chips | Relics | *post-MVP* |

**DATA node rewards (MVP):** pick one of +1 CPU, +2 RAM, +4 Storage, +10 max Integrity. This tests the rig-upgrade fantasy early.

Card upgrades are shown as version numbers: `OVERFLOW v1.0` → `v1.1`. *(Upgrading is post-MVP.)*

### Starter deck (10)
4× BRUTE.EXE, 4× PROXY, 1× PROBE, 1× SPOOF

### MVP card pool (first guesses; express as data so they can be tuned)
| Card | Type | Cost | Effect |
|---|---|---|---|
| BRUTE.EXE | Exploit | 1 | 6 dmg |
| OVERFLOW | Exploit [OVERFLOW] | 1 | 5 dmg |
| STACK SMASH | Exploit [OVERFLOW] | 2 | 13 dmg |
| SUDO | Exploit [PRIVESC] | 1 | 4 dmg; +6 if current layer is AUTH |
| SETUID | Exploit [PRIVESC] | 2 | 10 dmg |
| INJECT | Exploit [INJECT] | 1 | 3 dmg ×2 |
| PHISH | Exploit [SOCIAL] | 1 | 7 dmg; Trace +1 |
| FORKBOMB | Exploit | 2 | 3 dmg ×4 |
| DICTIONARY | Exploit | X | 5 dmg per cycle spent |
| PROXY | Proxy | 1 | 5 shield |
| PROXY CHAIN | Proxy | 2 | 12 shield |
| SPOOF | Proxy | 1 | 3 shield; Trace −2 |
| HONEYPOT | Proxy | 1 | 4 shield; if ICE attacks this turn, deal 4 back |
| PROBE | Script | 0 | Reveal weak/resist tags; draw 1; exhaust |
| GREP | Script | 1 | Draw 2 |
| CRON | Script | 1 | Next turn +2 cycles |
| DEFRAG | Script | 1 | Delete a Malware card from hand/discard; draw 1 |
| SNIFFER.DMN | Daemon (RAM 2) | 1 | Start of turn: 3 dmg |
| FIREWALL.DMN | Daemon (RAM 2) | 1 | Start of turn: 4 shield |
| KEYLOGGER.DMN | Daemon (RAM 3) | 2 | Exploits deal +2 dmg |
| CLOAK.DMN | Daemon (RAM 2) | 1 | ICE TRACE intents −1 |
| PAYLOAD | Payload | 1 | 8 dmg to KERNEL only; playable only when KERNEL is the current layer; **consumed** (removed from deck permanently) |
| CORRUPT SECTOR | Malware | — | Unplayable; removed after fight |
| TRACER | Malware | — | Unplayable; if in hand at end of turn, Trace +2; removed after fight |

---

## 6. Procedural generation

Seeds are hierarchical (run → network → node → filesystem), and everything is generated lazily.

### OS families (allusive names, never real ones)
| Family | Versions | Weak | Resist | Filesystem flavour |
|---|---|---|---|---|
| Panes | 3.11, 95, NT 4 | OVERFLOW | — | `C:\PANES\SYSTEM32`, `C:\AUTOEXEC.BAT` |
| Linnet | 1.2, 2.0 | PRIVESC | SOCIAL | `/etc/passwd`, `/var/log`, `/home/*` |
| Lunaris | 2.5, 7 | INJECT | OVERFLOW | `/opt`, `/export/home`, `/usr/local` |
| Cortland System | 7, 7.5 | SOCIAL | PRIVESC | `System Folder:Extensions`, `Desktop Folder` |
| OpenVAULT (ROOT only) | 6.2 | SOCIAL | OVERFLOW, PRIVESC | `SYS$SYSTEM:`, `[USERS.*]` |

### Hardware
- **CPU** (tier → ICE intents/turn: T1 = 1, T2 = 1 with stronger ICE, T3 = 2): M486DX2/66, Pentagon 90, PowerChip 601, 68040/33, SPARK-10, Omega 21064
- **RAM** 4–64 MB → number of ICE programs (1 + RAM/24, max 3) and scales layer HP
- **Modem** 2400 / 9600 / 14.4K / 28.8K baud → multiplier on TRACE intents (×1, ×1, ×1.5, ×2)
- **Hostname / org**: generated from org templates (University, Bank, ISP, Corp) that also drive filesystem flavour

### Filesystems (MVP: flavour only)
Small generated trees, shown through `PROBE` output and in `carrier gen`. *Filesystem-as-game-board, where cards target directories and processes, is post-MVP.*

---

## 7. Interface and aesthetic

- **Apple //e green-phosphor monochrome.** 40-column layout by default; 80-column mode is a later unlock (a nod to the //e 80-column card). Inverse video for highlights, flashing text for alerts.
- **Your hand is your command vocabulary.** A card can be played by number key **or** by typing its name (tab completion, case-insensitive). You can only type what's in your hand. Playing a card echoes it as a command, with output scrolling below. *Build both input modes from the start; comparing them is a playtest question.*
- Font: draw an original bitmap font *in the style of* the Apple II; don't copy the character ROM.
- MVP is a terminal (TUI) app. CRT shader, sound (disk clacks, modem handshake, the beep) and Godot come later.

```
] CORTLAND SYSTEM 7.1  //  MERIDIAN TRUST  //  NODE 4
] 68040/33  16MB  14.4K BAUD          TRACE [#####.....]
]
] ICE: SENTRY   INTENT: TRACE +3
] SECURITY:  FIREWALL [###...]  AUTH [######]  KERNEL [######]
]
] >PROBE
] WEAK: SOCIAL   RESIST: PRIVESC
] >_
]
] CYCLES 2/3   RAM 2/6   DECK 14/20   INTEGRITY 31/40
] [1] BRUTE.EXE  [2] PROXY  [3] PAYLOAD  [4] PHISH  [5] SPOOF
```

---

## 8. Technical architecture

### Platform decision
- **Language:** Swift 6.
- **Game logic in a pure Swift package with no engine imports.** It's testable headless with `swift test` and playable in a TUI.
- **Presentation later via SwiftGodot** for a native Steam build (macOS / Windows / Linux / Steam Deck). SwiftGodot is still experimental but adequate for a project this size. A web build isn't a target, because Swift → WebAssembly via Emscripten isn't ready for GDExtension yet.
- **Do not start on Godot until the MVP has been playtested.**

### Repo layout
```
Package.swift
Sources/
  CarrierCore/    rules, state, actions, events, RNG — no I/O, no Foundation randomness
  CarrierGen/     procgen: OS families, hardware, orgs, filesystems, map templates
  carrier-cli/    TUI frontend + subcommands (play, fight, gen, sim, replay)
Resources/        cards.json, ice.json, os_families.json, hardware.json, maps/*.json, tuning.json
Tests/
  CarrierCoreTests/
  CarrierGenTests/
docs/
  design/         this brief, design notes, decisions log
  playtest/       dated playtest notes
godot/            (empty until post-MVP)
```

### Core principles
- **Pure reducer:** `apply(_ action: Action, to state: GameState) -> (GameState, [Event])`. State is made of value types. The frontend only sends Actions and renders Events. A future Godot frontend will consume the same Event stream.
- **Determinism:** a custom seeded PRNG (e.g. xoshiro256** or SplitMix64) with its **state stored in GameState**. Never use `SystemRandomNumberGenerator`, `Date`, or anything order-dependent. **Swift `Dictionary`/`Set` iteration order is randomized per process**, so use arrays or sorted keys wherever order affects outcomes. Integer arithmetic only in rules.
- **Replays:** seed + action log reproduces a game exactly. `carrier replay <file>` exists so playtest bugs can be reproduced.
- **Content as data:** cards, ICE, OS families, hardware, map templates and tuning constants live in JSON. Card *effects* are a small composable Swift enum (`damage(n, tag)`, `shield(n)`, `draw(n)`, `trace(Δ)`, `ifLayer(...)`, …) referenced from JSON. Balance changes should rarely need code changes.
- **Dependencies:** keep them minimal. `swift-argument-parser` is fine; do the TUI with raw ANSI + termios (macOS/Linux) rather than a framework, unless that turns out to be painful.

### CLI subcommands
- `carrier play [--seed N]`: full contract (the MVP)
- `carrier fight [--seed N] [--machine ...]`: single-fight sandbox
- `carrier gen [--seed N] [--count 20]`: print generated machines and filesystems (a procgen readout to check the flavour)
- `carrier sim --runs 1000 --bot greedy|random [--seed N]`: headless runs; prints win rate, average Trace at end, cause of failure, card pick rates
- `carrier replay <file>`

### Testing
- Unit tests for every rule (layer carry-over, Kernel-only Payload, weakness math, RAM limits, Storage cap, sysop CONTEST/REINFORCE).
- **Golden-transcript tests:** fixed seed + fixed action list → the event log matches a stored snapshot.
- Procgen snapshot tests (same seed → same machine).
- CI: `swift build` + `swift test` on macOS and Linux.

---

## 9. Milestones

Each milestone ends with something **playable or inspectable** and a short playtest note in `docs/playtest/`.

**M0 — Bootstrap**
- Create the repo. **Copy development setup from the Chickadee repo** (the user will give its path or URL): `CLAUDE.md` conventions, `.claude/` agents, commands and settings, CI workflow patterns, issue/PR templates, and the nightly steward setup. Strip everything web-, LTI- or course-specific. **Do not copy `.claude/settings.local.json`, `.env`, or any secrets.** Ask the user when unsure whether something applies.
- Write a new `CLAUDE.md` for this project that reflects §8's principles (pure core, determinism, content as data, no Godot yet).
- SwiftPM skeleton, CI green, this brief committed at `docs/design/kickoff.md`.

**M1 — Core types + procgen readout**
- PRNG, GameState, Action/Event, content loading from JSON.
- CarrierGen: machines (OS, hardware, org, hostname, small filesystem).
- `carrier gen` works. *Playtest question: does it feel like 1994?*

**M2 — One fight, playable**
- Full combat loop in the TUI: draw, cycles, cards, daemons/RAM, layers, ICE intents, Trace, PROBE, LOGOUT.
- Both input modes (number keys + typed commands with tab completion).
- `carrier fight` works. *Playtest questions: is a 10-card starter deck interesting against one machine? Typing vs clicking?*

**M3 — One contract, playable (= MVP)**
- Network map rendering, ticks, ownership, production, Payload carrying, sysop intents, REINFORCE, card rewards, DATA hardware upgrades, ROOT boss, win/lose.
- `carrier play` works end to end. *Playtest questions: is the map interesting at this size? Does Payload carrying create real decisions? Is Trace pressure about right?*

**M4 — Simulation + balance tooling**
- Bots (random, greedy), `carrier sim`, summary report. Use it to sanity-check tuning between human playtests.

**Post-MVP backlog (don't build yet; playtesting will set the order)**
Multi-contract runs and the BBS hub (shop/rest), card upgrades (v1.1), firmware relics, procedural map topology, filesystem-as-board, more OS families/ICE/cards, the map attacking more aggressively in later contracts, the 80-column unlock, SwiftGodot frontend with CRT shader and sound, Steam integration.

---

## 10. Open questions (current defaults in bold)

1. **Run structure:** 3 fixed acts vs an open BBS contract board? (**Deferred**; the MVP is one contract.)
2. **Integrity 0:** ends the run, or only costs the node + a big Trace hit? (**Ends the run**; LOGOUT is the soft-fail path. Revisit after the M3 playtest.)
3. **Should RAM also affect hand size**, or only daemons? (**Daemons only.**)
4. **Bandwidth:** does 1 action per tick feel too slow? (**1**; upgrades are post-MVP.)
5. **Typed vs clicked play:** keep both, or lean into one? (**Both**; decide from playtests.)
6. **Title:** NO CARRIER is a placeholder.

---

## 11. Working agreements for Claude Code

- Work milestone by milestone, in small commits/PRs. Don't build ahead into the backlog.
- Keep tuning numbers in `Resources/tuning.json` and content JSON, never hard-coded.
- When a rule here is ambiguous, pick the simplest reading, implement it, and record the choice in `docs/design/decisions.md`. Ask only when the choice would be expensive to reverse.
- At the end of each milestone: summarize what's playable, how to run it, and the specific playtest questions for the user.
- If an idea in this brief turns out to be unfun or unworkable once it's playable, say so. That's the point of prototyping.
