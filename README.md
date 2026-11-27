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

## Status

A prototype, built milestone by milestone and playtested between them. See
the milestone table in [CLAUDE.md](CLAUDE.md).
