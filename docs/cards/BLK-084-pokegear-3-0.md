# Pokégear 3.0

- **Set / number:** Black Bolt (BLK) #84
- **Regulation mark:** I — **Standard 2026 legal**
- **Category:** Trainer — **Item**
- **In decklists:** none yet — imported as a **candidate**.

## Effect

> Look at the top 7 cards of your deck. You may reveal a Supporter card you find
> there and put it into your hand. Shuffle the other cards back into your deck.

## Notes for the simulator

- **An Item that finds a Supporter**, which is precisely the gap in this deck's
  turn-1 going-first branch: the first player may play Items but no Supporters,
  so Pokégear digs on turn 1 for the Hilda or Salvatore to play on turn 2.
- **It is not a search — it is a look at 7.** The simulator must model it
  honestly as a peek at the top 7 of the *current* shuffled deck, which can
  whiff. It is not equivalent to a tutor, and its hit rate depends on how many
  Supporters remain in the deck. This is one of the few cards here where the
  policy's expected value genuinely depends on deck composition.
- It shuffles the other 6 back, re-randomizing the top of the deck — which
  **destroys a Ciphermaniac's Codebreaking stack**. The decision logic must not
  play Pokégear after setting up the top of the deck.
- **Printing note:** older printings exist (SVI 186, SSH 174) but SVI carries
  regulation mark **G** and rotated out in April 2026. BLK 84 (reg I) is the
  Standard-legal printing. Since legality attaches to the card rather than the
  printing, any physical copy may be played — the deck just has to cite a legal
  one.

**Verified:** limitlesstcg.com/cards/BLK/84, 2026-08-29; text corroborated by
the SSH/SVI printings.
