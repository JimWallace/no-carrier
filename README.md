# NO CARRIER

A hacking deckbuilder set in an alt-1990s, played through a green-phosphor
terminal. Working title.

You sit at a beige computer in the mid-90s. Each contract sends you into a
small corporate network. You take it over node by node while the sysop fights
back and a global Trace meter climbs. Each node you break into is a card
fight, played with the programs in your cyberdeck. Take the root node and you
win. Let Trace fill and you get NO CARRIER.

The design brief is [docs/design/kickoff.md](docs/design/kickoff.md).

## Build and run

Needs Swift 6.4 on macOS 15 or later, or Linux.

```bash
swift build
```

```bash
swift run carrier --help
```

```bash
swift test
```

Print some generated machines (M1, the procgen readout):

```bash
swift run carrier gen --seed 1994 --count 6
```

Play a whole contract (M3, the MVP): take the network node by node and
capture ROOT before Trace fills. On the map, press a node number to attack
it; type `HELP` for the other commands.

```bash
swift run carrier play
```

Play one node fight on its own (M2). Press a number key to run that card, or type its
name (Tab completes) and press Return. `END` ends the turn, `LOGOUT` leaves,
`HELP` lists your hand.

```bash
swift run carrier fight
```

```bash
swift run carrier fight --role sysop
```

Play many contracts headless with a bot, to check the tuning (M4). Use a
release build; 500 contracts take about a second.

```bash
swift build -c release
```

```bash
.build/release/carrier sim --runs 500 --bot greedy
```

`--seed`, `--record FILE` and `carrier replay FILE` reproduce a session.
`--content DIR` plays with a copy of `Sources/CarrierContent/Content/` for
tuning without a rebuild.

## Status

A prototype, built milestone by milestone and playtested between them. See
the milestone table in [CLAUDE.md](CLAUDE.md).
