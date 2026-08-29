# Ultra Ball

- **Set / number:** Mega Evolution (MEG) #131
- **Regulation mark:** I
- **Category:** Trainer — **Item**

## Effect

> You can use this card only if you discard 2 other cards from your hand.
> Search your deck for a Pokémon, reveal it, and put it into your hand. Then,
> shuffle your deck.

## Notes for the simulator

- Finds **any** Pokémon, including Bronzor, Bronzong, and Latias ex.
- The **discard-2 cost is a real constraint** and the decision logic must
  model it honestly: with a 3-card hand it is unplayable, and it can force
  discarding a card the turn-2 line needs. The policy must decide what it is
  willing to pitch (dead Boss's Orders and surplus Duskull first; never the
  only Psychic Energy or the only Bronzong).
- Discarded Pokémon and basic Energy are recoverable with Night Stretcher,
  which softens the cost slightly.
- An **Item**: shut off in the `item_lock` scenario.
- 4 copies.

**Verified:** limitlesstcg.com/cards/meg/131, 2026-08-29.
