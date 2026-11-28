# NO CARRIER — Addendum 03: Cracking Codes Instead of Fighting

> Status: **exploring.** The maintainer's direction (2026-11-28): replace the
> Slay the Spire–style fight with a code-matching puzzle inspired by
> Mastermind. Only the first prototype (§3) is built. Everything else is a
> list of ideas to test, not a plan.

## 1. The idea

Breaking into a server means matching its hidden code. You don't wear down
health bars; you put programs on your board in an order that matches the
code, and the server tells you how close you are.

- **The server has a hidden code:** a row of slots, each holding one symbol.
- **Your board is a row of slots** the same length as the code.
- **Each card shows a symbol.** You place cards from your hand onto the
  board and rearrange them.
- **A guess submits the board.** The server answers as in Mastermind:
  - **HIT:** right symbol, right slot.
  - **NEAR:** right symbol, wrong slot.
  It gives counts, not which slots.
- **Every guess raises the alarm.** Crack the code before the alarm fills.
  If it fills, you get NO CARRIER.

The map, the contracts, the sysop and procedural generation stay. This
replaces the fight, not the game.

## 2. Words

Plain deckbuilder words for design talk (agreed 2026-11-28):

| Word | Meaning |
|---|---|
| Deck | Every card you own |
| Draw pile | Cards waiting to be drawn |
| Hand | Cards you can play now |
| Discard pile | Cards you've replaced or thrown away |
| Board | The row of slots you build your guess on |
| Energy | Spent to place, swap or drop a card; refilled each turn |
| Alarm | Rises with each guess; full means NO CARRIER |
| Code | The server's hidden row of symbols |

## 3. The first prototype (built): `carrier crack`

One lock, no map, no rewards, no deckbuilding. The only question: **is
matching a code with cards fun?**

Rules (every number is in `crack.json`):

- The code is **4 slots** from **6 symbols** (`A E K R X Z`). A symbol
  appears at most **2** times.
- The starter deck is **14 cards**: 2 of each symbol, 1 DIAL and 1 PROBE.
- **At the start of each turn, draw until your hand has 5 cards.** Cards you
  don't use stay in your hand.
- **3 energy a turn.** Playing a card costs 1, swapping two slots costs 1,
  and dropping a card from your hand costs 1. A card you place over another
  sends the old one to the discard pile.
- **DIAL:** goes on the board like a symbol card, showing A. Turning it costs
  1 energy a step along `A E K R X Z`, the short way round (the list wraps,
  so A to Z is one step). It goes back to A when it leaves the board.
- **PROBE:** played on a slot, it shows that slot's symbol in the code, then
  goes to the discard pile. The board shows what probes found on a `KNOWN`
  line.
- **A guess ends the turn.** The board stays as it is. Empty slots are
  allowed and match nothing.
- **Each guess adds 15 alarm; 100 is NO CARRIER**, so you get 7 guesses.
- When the draw pile is empty, the discard pile is shuffled back into it.

Energy 3 against 4 slots means the first guess can't fill the board, and
no later turn can change every slot. That's on purpose: it makes you choose
which slots to test.

### Tuning (2026-11-28)

`carrier crack --sim N` plays N cracks with a bot. The bot keeps every code
that fits the feedback so far, uses probes, and moves its board toward the
code that fits with the fewest changes. It stands in for a careful player.
The full sweep is in `docs/playtest/2026-11-28-crack-tuning.md`. What it
showed:

- **The guess limit is the main dial.** With 10 guesses the bot won 98%;
  with 7, 68%; with 5, 16%.
- **A probe is worth about two guesses.** At 7 guesses, one probe lifts the
  bot from 68% to 88%.
- **More symbols is a cliff, a longer code is a slope.** 8 symbols instead
  of 6 drops the bot to 28%; a 5-slot code only to 83%. Harder servers
  should grow longer before they get more symbols.
- **Dropping matters.** Before the bot learned to drop useless cards, it won
  26%: a kept hand clogs. A player who never drops will have a bad time,
  which HELP should say.
- **The default** (7 guesses, 1 probe, 1 dial) puts the bot at 89%, about
  5.7 guesses a crack.

## 4. Questions for the first playtest

1. Is it fun at all? Does rearranging after feedback feel like hacking, or
   like homework?
2. Is 3 energy too tight, or just right?
3. Do the cards in your hand get in the way ("I know it's an R and I have
   no R")? Is that tension good or just annoying?
4. Is 10 guesses too many or too few?
5. Counts (Mastermind) or a mark under each slot (Wordle)? Counts are
   harder; which is more fun here?

## 5. Ideas to test next (not built)

Feedback tuning, the first thing the maintainer wants to explore:

- **Counts by default, cards that buy more.** For example, a program that
  makes the next guess mark each slot, or reveals one slot.
- **Partial feedback:** only HIT, or only the count for one symbol.
- **Delayed or noisy feedback** from tougher servers.

Cards beyond one symbol:

- **Wildcards** that count as any symbol. (A DIAL, built, is the cheaper
  cousin: any symbol, at a price.)
- **Big cards** that cover 2 or 3 slots with a fixed run of symbols.
- **Movement cards:** a free swap, or shift the whole row by one.
- **Lock cards:** pin a confirmed slot so the server can't disturb it.
- **Symbol probes:** is this symbol in the code at all? (The slot PROBE is
  built.)

What the server does back (the job ICE does now):

- **Rotate** the code one slot every few guesses.
- **Scramble** two cards on your board.
- **Lie** with one feedback mark.
- **Blacklist** a symbol for a turn.
- **Decoy** slot that doesn't count.
- **Escalate:** each wrong guess raises the alarm more.

Harder servers: longer codes, more symbols, several codes in a row (one per
security layer).

Deck mechanics from the earlier talk (The Bazaar): card sizes, a deck limit
that counts size, upgrading hand size, a duplicate upgrading a card rather
than adding a copy.

## 6. Servers (built: three prototypes)

A server differs in three ways: the shape of its lock, how it answers, and
what it does back. Each is a profile in `crack.json`
(`carrier crack --server <id>`):

| | KIOSK TERMINAL | CORPORATE HOST | SYSOP ROOT |
|---|---|---|---|
| Symbols | 4 (`A E K R`) | 6 | 6 |
| Code | 4 slots | 5 slots | 4 slots |
| Alarm a guess | 15 (7 guesses) | 14 (8 guesses) | 8, then +2 more each guess (8 guesses) |
| Feedback | a mark per slot (`H N -`) | HIT and NEAR counts | HIT count only |
| Interference | none | SCRAMBLE every 2 turns | ROTATE every 3 turns |
| Bot wins | 98% | 92% | 69% |

- **Feedback styles.** `slots` puts a mark under each slot: `H` right symbol,
  `N` in the code elsewhere, `-` not there (Wordle). `counts` is Mastermind.
  `hits` gives the HIT count only.
- **Escalation.** Each guess costs `escalation` more alarm than the one
  before it. The screen shows the next guess's cost.
- **SCRAMBLE** swaps two of the player's board slots at random.
- **ROTATE** moves the code one slot right, the last wrapping to the first.
  Old feedback stays true of the code as it was; what probes found moves
  with it.
- **Each program acts at the end of every Nth turn, after the guess.** The
  screen shows when (`SERVER: ROTATE IN 1`).
- **Caution on ROTATE:** the bot follows a rotation perfectly, so its 69%
  overstates what a person will manage. Removing ROTATE barely changed the
  bot's rate; for a human it is probably the hardest part of the root.

Later, these profiles become what the generator assigns from a machine's
traits (OS family sets the feedback style, modem the alarm, RAM the code
length, CPU the interference), and SCAN shows a server's profile before the
player commits.

## 7. The run and rewards (built)

`carrier crack` now plays a **run**: KIOSK TERMINAL, then CORPORATE HOST,
then SYSOP ROOT. The deck carries from crack to crack. After each crack but
the last there is a reward:

- **Take** one of 3 cards from the reward pool, **remove** a card from your
  deck, or **skip**.
- **The next server is shown** with its profile (slots, symbols, feedback,
  interference), so you choose for the lock you will face.
- **The deck limit is 15.** The starter deck is 14, so the first card you
  take fills it; after that, a reward can only remove or skip.
- **A deck cannot shrink below hand size + the next code's length.**

`carrier crack --server <id>` still plays a single crack.

### HOLD

`H` ends the turn without a guess: the alarm rises by 4 (`alarm.hold`), the
server's programs still act, and the hand is drawn back up. It costs less
than a guess but tells you nothing, so it is for turns where your board is
not worth guessing.

### Reward cards

Every card explains itself in ten words or fewer (`CrackCard.rules`, built
from the card's numbers; a test holds the limit). A card that says THIS
SLOT is played on a slot (`1 3`); any other on its own (`1`).

**Keywords** (CODE, SLOT, BOARD, GUESS, ALARM, ENERGY, SCRAMBLE, ROTATE) are
bold in card text, and each has a ten-word explanation in `crack.json`:
on hover in a mouse frontend, with `? WORD` in the terminal.

| Card | Cost | Rules text |
|---|---|---|
| A, E, K... | 1 | SHOWS A. |
| DIAL-A | 1 | SHOWS A. TURN IT TO ANY SYMBOL IN PLACE. |
| PROBE | 1 | REVEALS THIS SLOT OF THE CODE. |
| SNIFF | 0 | IS THIS SLOT'S SYMBOL ANYWHERE IN THE CODE? |
| COUNT | 0 | HOW MANY OF THIS SLOT'S SYMBOL ARE IN THE CODE? |
| LOCK | 0 | SCRAMBLE CANNOT MOVE THIS SLOT'S CARD. |
| DEBUG | 0 | NEXT GUESS MARKS EACH SLOT. |
| SPOOF | 0 | NEXT GUESS COSTS 50% ALARM. |
| SHIFT | 0 | MOVES YOUR WHOLE BOARD ONE SLOT RIGHT. |
| OVERCLOCK | 0 | +1 ENERGY NOW. |

### What the card values showed

`carrier crack --sim N --values` adds each reward card to the starter deck
alone and reports the bot's win rate against none, per server (1000 runs):

| Card | KIOSK | CORPORATE | ROOT |
|---|---|---|---|
| (none) | 100% | 94% | 70% |
| PROBE | -1 | +2 | +13 |
| COUNT | -1 | 0 | +9 |
| SPOOF | 0 | +3 | +4 |
| SNIFF | -1 | -2 | +4 |
| DEBUG | -1 | -2 | +2 |
| SHIFT | -1 | -6 | +1 |
| OVERCLOCK | 0 | 0 | 0 |
| DIAL-A | 0 | -1 | -1 |
| LOCK | -1 | -3 | -10 |

- **Energy is the bottleneck.** With the first costs (1 or 2 energy for most
  cards), nearly every card was a loss: an energy spent on a card is a slot
  not changed. Making utility cards free is what made them worth taking.
- **A card that does nothing against this server costs 5 to 10 points:** it
  sits in a hand of 5, and dropping it costs energy. That is the hard
  choice the rewards want, since the next server is shown: LOCK is good
  only where SCRAMBLE is, SHIFT where ROTATE is.
- **Information is worth most where feedback is thinnest.** On SYSOP ROOT
  (hits only), PROBE and COUNT are the best cards in the pool.
- **The bot undersells situational cards.** It uses LOCK and SHIFT simply;
  a person may do better.

## 8. Where it lives

The prototype is its own command and its own content file (`crack.json`).
It does not touch `carrier fight`, `carrier play`, the golden transcripts or
the rule set. When it joins contracts, it goes behind a flag (addendum 02,
§1) and its numbers move under the rule set.
