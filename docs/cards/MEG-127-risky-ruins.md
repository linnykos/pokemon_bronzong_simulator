# Risky Ruins

- **Set / number:** Mega Evolution (MEG) #127
- **Regulation mark:** I
- **Category:** Trainer — **Stadium**

## Effect

> Whenever any player puts a Basic non-`[D]` Pokémon onto their Bench during
> their turn, place 2 damage counters on that Pokémon.

## Notes for the simulator

- **It is disruptive to us, and inside this project only to us.** "Any player"
  includes this one, and every Basic these decks bench — Bronzor, Duskull, Latias
  ex, Meowth ex, Munkidori, Buneary, Dunsparce — is non-`[D]`. No opposing board
  is modelled, so the entire effect falls on our own Bench.
- §4.2 step 7 already says to play a Stadium only when **it is not disruptive to
  us**, so this one is never played. That is the same clause that keeps Mystery
  Garden out, and it means the two copies in decklist7 and decklist8 are two
  slots the measured window cannot use.
- **Nothing it does would change the metric even if it were played.** Twenty
  damage Knocks Out no Basic in these lists — the smallest is Duskull at 60 HP —
  and adding Itchy Pollen's 10 does not either. It would change the
  end-of-turn-2 board record, which is why it is worth naming rather than
  ignoring.
- The damage is therefore **modelled as not arising**, because the play that
  would cause it is declined. If a future rule ever plays it, the damage must be
  implemented in the same change.

**Verified:** limitlesstcg.com/cards/MEG/127, 2026-08-30.
