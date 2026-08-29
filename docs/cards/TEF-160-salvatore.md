# Salvatore

- **Set / number:** Temporal Forces (TEF) #160
- **Regulation mark:** H
- **Category:** Trainer — **Supporter**
- **Appears in:** decklist2 (1), decklist3 (1). **Not** in decklist1.

## Effect

> Search your deck for a card that has no Abilities and evolves from 1 of your
> Pokémon, and put it onto that Pokémon to evolve it. Then, shuffle your deck.
> You can use this card on a Pokémon you put down when you were setting up to
> play or on a Pokémon that was put into play this turn.

## Notes for the simulator

### Legal targets in these decklists

The target must have **no Abilities**. In decklists 2 and 3 that means:

- **Bronzong** (TEF 69) — legal. Evolution Jammer is an *attack*, and Bronzong
  has no Ability, so it is a valid Salvatore target.
- **Mega Lopunny ex** (PFL 84) — legal, no Abilities.
- **Dusclops** and **Dusknoir** — **not** legal targets. Both have the Cursed
  Blast **Ability**, so Salvatore can never fetch them.

### The turn-1 question — [UNVERIFIED, DECISION-CRITICAL]

Salvatore explicitly overrides "you can't evolve a Pokémon the turn it came into
play". Whether it *also* overrides "you can't evolve on your first turn of the
game" determines whether the target event for decklists 2 and 3 is **turn 1 or
turn 2** — and therefore what this entire project measures.

**Textual argument that it does work on turn 1:** the effect grants two
permissions — on a Pokémon "put down when you were setting up", and on one "put
into play this turn". The second clause covers the played-this-turn restriction.
The first clause covers setup Pokémon — but on turn 2 and later a setup Pokémon
is *already* freely evolvable, so that clause is pure redundancy unless it is
there to license evolving on your **first turn**.

**Argument against:** the first-turn evolution ban is written as a separate rule
(`docs/01_rules_standard.md` §5), and Salvatore never names it. Cards that mean
to exempt themselves from first-turn rules usually say so outright — compare
Rare Candy, which states "You can't use this card during your first turn."

Web sources checked on 2026-08-29 contradict each other and none is
authoritative. **Ask the player before encoding this.**

If Salvatore *does* work on turn 1, then going second the line is:
Bronzor Active from setup → Salvatore fetches and evolves Bronzong → attach a
`[P]` Energy → attack Evolution Jammer **on turn 1**, locking the opponent's
evolutions on their own first turn.

### Playability constraint

Per the published Salvatore ruling, you may not play it unless a legal,
format-legal target actually exists — the game checks public zones. So the
simulator must not let the policy play Salvatore when, for example, both
Bronzong are already in the discard. A Salvatore that finds nothing is also
**information**: it tells the player the remaining copies are prized.

### Other

- As a Supporter it is unplayable on turn 1 **when going first**, so this line
  exists only going second — reinforcing that going second is correct for this
  deck.

**Verified:** limitlesstcg.com/cards/tef/160 and Bulbapedia "Salvatore (Temporal
Forces 160)", 2026-08-29 — effect text identical in both. The turn-1 ruling is
*not* resolved.
