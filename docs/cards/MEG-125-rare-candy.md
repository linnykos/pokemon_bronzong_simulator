# Rare Candy

- **Set / number:** Mega Evolution (MEG) #125
- **Regulation mark:** I
- **Category:** Trainer — **Item**

## Effect

> Choose 1 of your Basic Pokémon in play. If you have a Stage 2 card in your
> hand that evolves from that Pokémon, put that card on the Basic Pokémon.
> (This counts as evolving that Pokémon.) You can't use this card during your
> first turn or on a Basic Pokémon that was put into play this turn.

## Notes for the simulator

- The card text states the timing restrictions explicitly, confirming
  `docs/01_rules_standard.md` §5: **not on your first turn**, and **not on a
  Basic played this turn**.
- In decklist1 it serves **Dusknoir only** — Mega Lopunny ex is a Stage 1 and
  cannot be reached with Rare Candy.
- It is an **Item**, so it is shut off by an opposing Budew's Itchy Pollen on
  our turn 2 (the `item_lock` scenario) and by our own Bronzong's Evolution
  Jammer on the opponent's turn.
- 4 copies.

**Verified:** limitlesstcg.com/cards/meg/125, 2026-08-29.
