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

### Turn-1 legality — **RESOLVED: Salvatore works on your first turn**

Confirmed by the player, 2026-08-29. Salvatore overrides **both** evolution
timing restrictions: "played this turn" *and* "your first turn of the game".

This is consistent with the card text: the effect grants two permissions — on a
Pokémon "put down when you were setting up", and on one "put into play this
turn". The second covers the played-this-turn restriction. The first covers
setup Pokémon, which on turn 2 and later are *already* freely evolvable — so
that clause is only meaningful as a licence to evolve on your **first turn**.

**Consequence — the turn-1 kill:** going **second**, with Salvatore, the line is

1. Bronzor in the Active spot (led from setup, or switched into on turn 1);
2. play **Salvatore** → search **Bronzong**, evolve Bronzor;
3. attach a `[P]` Energy (basic Psychic or Telepathic Psychic);
4. attack **Evolution Jammer** — **on turn 1**,

which locks the opponent's evolutions on their *own first turn*, before they
have evolved anything at all.

**Going first this line does not exist**, because the first player can play no
Supporter and cannot attack. So:

| | Salvatore list (2,3,4,5,7) | No-Salvatore list (1,6,8) |
|---|---|---|
| **Going second** | **turn 1** | turn 2 |
| **Going first** | turn 2 | turn 2 |

The "earliest possible turn" is therefore a function of both the decklist and
the coin flip, and the metric in part 6 must be computed per cell rather than
pooled. See `docs/01_rules_standard.md` §5.

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
