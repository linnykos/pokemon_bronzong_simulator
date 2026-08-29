# Surfer

- **Set / number:** Surging Sparks (SSP) #187 — also reprinted in Ascended
  Heroes (ASC) #200, the same card
- **Regulation mark:** H — **Standard 2026 legal**
- **Category:** Trainer — **Supporter**
- **In decklists:** none yet — imported as a **candidate**.

## Effect

> Switch your Active Pokémon with 1 of your Benched Pokémon. If you do, draw
> cards until you have 5 cards in your hand.

## Notes for the simulator

**This card addresses the deck's suspected bottleneck head-on.** Getting Bronzong
*Active* — not drawing it — is the constraint (Salvatore fixes timing, not
positioning). Surfer switches and refills in one card.

### It is a refill, not a draw-5

"Draw until you have 5" means the draw is `max(0, 5 - hand size)` **after** the
switch, and Surfer itself has already left the hand. With a 6-card hand it draws
**nothing** and is a strictly worse Switch. Its value is highest when played
late in the turn on a nearly empty hand. The policy must therefore sequence it
correctly — dump the hand first, Surfer last — and the simulator must compute the
draw from the post-switch hand size, not a fixed 5.

### It competes with Salvatore, and that is the real tension

Both are Supporters, and only **one Supporter may be played per turn**. Going
second on turn 1 with Bronzor on the Bench, the player needs *both* a switch and
an evolve — and cannot have both from Supporters. The resolutions are:

- Lead Bronzor from setup, so no switch is needed → Salvatore is free to be the
  Supporter. **This is why the opening placement decision matters so much.**
- Use **Switch** (an Item) for the positioning and keep the Supporter for
  Salvatore. Strictly better than Surfer for the turn-1 line, minus the draw.
- Play Surfer and give up the turn-1 kill, evolving normally on turn 2.

So Surfer does **not** stack with the Salvatore turn-1 line; it is an alternative
to it, and mainly strengthens the turn-2 line and the going-first branch.

### Other

- Unplayable on turn 1 **going first**, like every Supporter.
- The switch is mandatory-if-able in the sense that the draw is conditional on it
  ("If you do") — with an empty Bench, Surfer does nothing at all.

**Verified:** limitlesstcg.com/cards/ssp/187, 2026-08-29.
