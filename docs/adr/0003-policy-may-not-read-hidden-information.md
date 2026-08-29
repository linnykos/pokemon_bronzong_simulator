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
