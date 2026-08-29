# 0001 — Salvatore is taken to permit evolving on your first turn

**Status:** accepted, on an uncited premise — see the caveat below.

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

**Caveat, and why this record exists.** This is the only load-bearing rules fact in
the project with no citable source. If it is wrong, every "on time" number for a
Salvatore list going second is wrong, and the Salvatore-vs-no-Salvatore comparison —
the main thing the six decklists are testing — inverts. Getting an official ruling
into `additional_context/` would retire the risk cheaply.

**Consequence:** the earliest legal turn becomes a function of the decklist and the
coin flip rather than a constant, which forces the reporting structure in ADR 0002.
