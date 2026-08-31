# Dudunsparce

- **Set / number:** Temporal Forces (TEF) #129
- **Regulation mark:** H
- **Category:** Pokémon — **Stage 1**, evolves from Dunsparce
- **Type:** Colorless
- **HP:** 140

## Ability

**Run Away Draw**
> Once during your turn, you may draw 3 cards. If you drew any cards in this way,
> shuffle this Pokémon and all attached cards into your deck.

## Attacks

**Land Crush** — `[C][C][C]` — 90 damage

## Other

- **Weakness:** Fighting x2 | **Resistance:** none | **Retreat cost:** 3

## Notes for the simulator

- **Run Away Draw is a real draw engine and it genuinely is an Ability**, checked
  against a second source precisely because the sibling card JTG 120 was
  mis-rendered in the other direction.
- **Its window here is one turn wide.** Dunsparce must be benched on turn 1 and
  the evolution is legal only from turn 2, so at most one Run Away Draw ever
  fires inside the measured window, and only in a game that benched a Dunsparce
  it had no other use for. decklist8 runs one of each.
- It also **shuffles**, so it must not be used while a Ciphermaniac's stack is
  pending, and the belief state's known top-of-deck is destroyed by it.
- **Specified and not implemented**; see `docs/03a_card_playbook.md`. decklist8's
  rate is therefore a slight under-estimate, by one card.

**Verified:** limitlesstcg.com/cards/TEF/129 and
bulbapedia.bulbagarden.net/wiki/Dudunsparce_(Temporal_Forces_129), 2026-08-30.
