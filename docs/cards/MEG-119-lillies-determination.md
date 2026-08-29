# Lillie's Determination

- **Set / number:** Mega Evolution (MEG) #119
- **Regulation mark:** I
- **Category:** Trainer — **Supporter**

## Effect

> Shuffle your hand into your deck. Then, draw 6 cards. If you have exactly 6
> Prize cards remaining, draw 8 cards instead.

## Notes for the simulator

- **Draws 8 on turn 1 and turn 2**, since neither player has taken a Prize
  that early. This is the deck's main engine card for the window we care about.
- It **shuffles the hand away first**, so playing it discards nothing but does
  cost every card currently held — the decision logic must play everything it
  wants to keep (bench Basics, Rare Candy, etc.) *before* playing this.
- Being a Supporter, it is **unavailable on turn 1 when going first**. This is
  the single largest asymmetry between going first and going second for this
  deck.
- 4 copies.

**Verified:** limitlesstcg.com/cards/meg/119, 2026-08-29.
