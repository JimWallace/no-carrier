# Crack tuning by simulation (2026-11-28)

`carrier crack --sim 1000 --seed 1` (2000 runs for the last table) on
copies of `crack.json`. The bot (`CrackBot` in `CarrierSim`) keeps every
code that fits the feedback, plays a probe on the slot it knows least
about, moves the board toward the fitting code that needs the fewest
changes, and drops cards it does not need. A human may do better or worse;
the comparisons between rows are what matter.

Before the bot dropped cards it won 26% of the baseline: a kept hand with
the wrong symbols never changes.

## The baseline and one change at a time (10 guesses)

| Change | Win | Mean guesses |
|---|---|---|
| Baseline: energy 3, hand 5 | 98% | 6.8 |
| No limits (energy 9, hand 8) | 100% | 5.1 |
| Energy 2 | 92% | 7.6 |
| Energy 4 | 99% | 6.4 |
| Hand 4 | 93% | 7.5 |
| Hand 6 | 100% | 6.2 |
| +1 probe | 100% | 6.0 |
| +2 probes | 100% | 5.6 |
| +2 dials | 99% | 6.3 |
| +2 dials, turning free | 100% | 5.7 |
| 8 symbols | 47% | 8.7 |
| Code length 5 | 100% | 6.9 |

Energy and hand size cost the bot about 1.7 guesses against no limits.

## The guess limit

| Guesses | Win | With 1 probe | With 2 probes |
|---|---|---|---|
| 10 | 98% | | |
| 8 | 86% | | |
| 7 | 68% | 88% | |
| 6 | 38% | 67% | 75% |
| 5 | 16% | | |

## Candidates for the default (7 guesses)

| Deck | Win | Mean guesses |
|---|---|---|
| +2 dials | 81% | 5.8 |
| +1 probe +1 dial (**chosen**) | 89% | 5.7 |
| +1 probe +2 dials | 91% | 5.6 |
| +1 probe +1 dial, 8 symbols | 28% | 6.2 |
| +1 probe +1 dial, code length 5 | 83% | 6.0 |

## Decisions

- Default: 7 guesses (alarm +15), starter deck 12 symbol cards + 1 DIAL +
  1 PROBE.
- Harder servers: a longer code first; more symbols is a much bigger jump.
