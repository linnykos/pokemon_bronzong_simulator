# 0007 — The window closes at the end of turn 2, and that moment is recorded in full

The draft of `docs/03_decision_tree.md` §7 left the door open to a turn-3 distribution
("the policy should still make the best available play, because part 6 may later want
the turn-3 distribution"). Kevin closed it, 2026-08-29: *"No, you don't need to record
past the end of Turn 2 right now. (But please be thorough in the end of Turn 2, since
I would like to (in the future) assess what the board state by the end of Turn 2)"*.
**The simulator therefore plays and records the player's own turns 1 and 2 and stops.
In exchange, the end-of-turn-2 board state is recorded in full rather than summarised.**

This is the natural companion to ADR 0004. That record fixes the *bar* at turn 2; this
one fixes the *window* at turn 2, which is a separate claim — the bar could have been
turn 2 while the engine kept playing, exactly as the draft assumed it might.

**Considered and rejected:** recording turn 3, to learn how many misses were "one turn
away". It is genuinely informative and it was still declined, because it makes every
replicate longer, forces a decision tree for a turn the project has never specified
(§8's non-goals are written for turns 1–2 only, and Dusknoir's damage plan starts to
matter on turn 3), and answers a question nobody is currently asking. Turn 3 remains
addable later; nothing here forecloses it beyond a re-run.

**Consequences.**

- **The policy must play a doomed turn 2 properly.** Once the metric is lost the
  replicate's remaining value is entirely in the board state it leaves behind, so
  "the replicate is already a miss" is never a licence to stop playing well. The
  reason changed even though the instruction did not.
- **`format_trace()` grew from a one-line `end` summary to an eight-line block**
  naming every zone: board (with attached Energy, damage, and the turn each Pokémon
  was played or evolved), hand, discard, deck size, Stadium, Prizes, the turn's spent
  resources, the Item-lock state, and the Basic that led at setup. ADR 0006's
  compactness concern is preserved but re-priced — the trace cap moved from 12 lines
  to 16, and the snapshot is a *fixed* cost per trace, unlike the per-turn lines,
  which grow with how much the policy does.
- **The snapshot names the prized cards, labelled as ground truth.** ADR 0003 forbids
  the *policy* from reading the prizes; it does not forbid the *analysis* from
  recording them, and "both Bronzong prized" is the single line that separates a
  variance miss from a decision defect. The label is written into the trace file
  itself so that the field's existence is never mistaken for permission to read it
  from part 5.
