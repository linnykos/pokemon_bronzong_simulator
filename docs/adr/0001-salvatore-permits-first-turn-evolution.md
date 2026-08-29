# 0001 — Salvatore is taken to permit evolving on your first turn

**Status:** accepted. Confirmed by Kevin twice — initially on 2026-08-29, then reaffirmed ("yes, I'm confident of this") when this record was reviewed the same day.

Salvatore (TEF 160) plainly overrides "you can't evolve a Pokémon the turn it came
into play". Whether it also overrides the separate rule "you can't evolve on your
first turn of the game" decides whether the target event is reachable on turn 1 or
only on turn 2, and therefore what this whole project measures. Web sources checked
on 2026-08-29 contradicted each other and none was authoritative. **Kevin confirmed
that it does work on turn 1**, and the simulator is built on that.

The textual argument agrees: the card grants two permissions — on a Pokémon "put
down when you were setting up", and on one "put into play this turn". The second
covers the played-this-turn restriction; the first covers setup Pokémon, which on
turn 2 and later are already freely evolvable. That clause is redundant unless it
licenses evolving on your **first** turn.

**Caveat, and why this record exists.** This remains the only load-bearing rules fact
in the project with no citable public source — Kevin's confidence is the citation.
Recorded so that a future session knows it rests on domain expertise rather than a
document, and knows exactly what to re-check if a ruling ever contradicts it. An
official ruling filed in `additional_context/` would retire the residual risk.

**Consequence.** The earliest turn on which the target event is *possible* becomes a
function of the decklist and the coin flip rather than a constant. Note that ADR 0004
subsequently decided **not** to make that varying floor the primary outcome — the
headline metric is fixed at the player's own turn 2 precisely so that Salvatore and
non-Salvatore lists stay comparable. Salvatore's turn-1 capability shows up in the
recorded turn-of-achievement instead.
