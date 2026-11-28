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
  appears at most **2** times, because the deck holds only 2 of each.
- The starter deck is **12 cards**, 2 of each symbol.
- **At the start of each turn, draw until your hand has 5 cards.** Cards you
  don't use stay in your hand.
- **3 energy a turn.** Placing a card costs 1, swapping two slots costs 1,
  and dropping a card from your hand costs 1. A card you place over another
  sends the old one to the discard pile.
- **A guess ends the turn.** The board stays as it is. Empty slots are
  allowed and match nothing.
- **Each guess adds 10 alarm; 100 is NO CARRIER**, so you get 10 guesses.
- When the draw pile is empty, the discard pile is shuffled back into it.

Energy 3 against 4 slots means the first guess can't fill the board, and
no later turn can change every slot. That's on purpose: it makes you choose
which slots to test.

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

- **Wildcards** that count as any symbol.
- **Big cards** that cover 2 or 3 slots with a fixed run of symbols.
- **Movement cards:** a free swap, or shift the whole row by one.
- **Lock cards:** pin a confirmed slot so the server can't disturb it.
- **Probe cards:** is this symbol in the code at all?

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

## 6. Where it lives

The prototype is its own command and its own content file (`crack.json`).
It does not touch `carrier fight`, `carrier play`, the golden transcripts or
the rule set. When it joins contracts, it goes behind a flag (addendum 02,
§1) and its numbers move under the rule set.
