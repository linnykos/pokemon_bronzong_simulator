# Basic Darkness Energy

- **Set / number:** Mega Evolution Energy (MEE) #7
- **Regulation mark:** none — Basic Energy carries no regulation mark and is
  always legal
- **Category:** Energy — **Basic**

## Effect

> Provides `[D]` Energy.

## Notes for the simulator

- **It is not a `[P]` source and cannot pay for Evolution Jammer**, which costs
  one `[P]`. The same trap as Enriching Energy arriving from the other direction:
  Enriching is an Energy card that is not `[P]`, and so is this.
- It **can** pay a `[C]` cost, so it is a legal payment for Buneary's Run Around
  and for Dunsparce's Trading Places — and it is the *cheapest* payment for
  either, because it is the Energy those attacks can strand on the Bench at the
  least cost. §4.2's "pay it with Enriching Energy where possible" therefore has
  a better option in decklist7 and decklist8. **Not implemented**; see
  `docs/03a_card_playbook.md`.
- Its real job in those lists is Munkidori's Adrena-Brain, which needs `[D]`
  attached — an Ability that moves damage counters, and therefore inert for a
  metric that ends on turn 2.
- Three copies in decklist7 and two in decklist8. Every one of them is a card
  that **cannot advance sub-goal D**, which is the thing to hold in mind when
  reading those two lists: their `[P]` base is four Telepathic Psychic Energy and
  nothing else.

**Verified:** the MEE Energy subset numbers the basic Energy in the standard
order, and #5 is the Psychic already recorded in `MEE-005-psychic-energy.md`;
#7 is Darkness, which is also how `decklists/decklist7.txt` and
`decklists/decklist8.txt` name it. 2026-08-30.
