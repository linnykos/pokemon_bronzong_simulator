# 0003 — The policy may not read hidden information

The simulator holds the full game state, so it would be far simpler and faster to let
the decision logic read the prize pile and the deck order directly — choosing the
search target that is actually findable, never wasting a card on a whiff. We forbid
it. The policy may read only what a real player knows at that moment: their hand,
the board, the discard, and what they have learned from resolved effects. A search
whose targets are all prized must resolve as a **whiff**, and the whiff is then
legitimate information the policy may act on.

**Considered and rejected:** an oracle policy that peeks. It is easier to write and
would still rank decklists, but the numbers it produces are not consistency estimates
of anything — a large share of what makes a 1-of Latias ex or a 2-of Bronzong
unreliable *is* the prizing and the ordering, and a peeking policy prices that at
zero. Since prizing is the very risk the six decklists differ in exposure to, the
oracle would systematically flatter thin lines.

**Consequence:** the policy needs a belief state (what has been seen, what has been
ruled out) separate from the ground-truth game state, and this separation has to be
built in from the start — retrofitting information-hiding onto a policy that reads
ground truth is a rewrite, not a patch. It also means the simulator cannot be
validated by checking that it always makes the objectively optimal play; it should
sometimes make a play that hindsight shows was wrong.

## Required mechanics

Specified by Kevin on 2026-08-29. These are the concrete rules the belief state must
implement.

1. **Deck contents are unknown until the first deck-search card is played.** The
   policy does not begin the game knowing which cards are prized. It learns that only
   by looking through the deck — searching reveals the deck's contents, and what is
   *missing* from them is what is prized or already gone. Until then the policy must
   reason over the full decklist minus what it has actually seen.
   > *Interpretation to confirm: Kevin's wording was "should NOT immediately know
   > what's benched before the first deck-search card is played." Read as prize/deck
   > contents, since that is the knowledge a deck search actually confers. Flagged in
   > case something else was meant.*
2. **Deck order is never known.** No effect in these decklists shows the top of the
   deck, so the policy has no ordering information at any point. The one card that
   *creates* ordering knowledge is Ciphermaniac's Codebreaking, which places two known
   cards on top — that knowledge is real and the policy may use it.
3. **The deck is reshuffled, unknown to the policy, after every deck search.** Any
   ordering knowledge is destroyed by a search that shuffles. This is what makes
   Pokégear 3.0 after a Ciphermaniac's stack a mistake, and the policy must model it
   as one. Note the asymmetry the belief state has to represent: a shuffle destroys
   knowledge of **order** but not knowledge of **contents** — having seen the deck
   once, the player still knows what is in it.
