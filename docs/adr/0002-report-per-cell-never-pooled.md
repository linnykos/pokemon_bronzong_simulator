# 0002 — Results are reported per (decklist, scenario, first/second) cell, never pooled

Because Salvatore lifts the first-turn evolution ban (ADR 0001) but the player going
first may neither play a Supporter nor attack, the earliest legal turn for the target
event is **turn 1 for a Salvatore list going second and turn 2 in every other case**.
A single pooled "consistency" number per decklist would therefore average two
different questions together, and would penalise a Salvatore list for the ~50% of its
games in which its defining card cannot be used at all. We report each
(decklist, scenario, going-first-or-second) cell separately.

**Considered and rejected:** one headline number per decklist. Simpler to read and to
rank, but it makes Salvatore lists look worse the better Salvatore is, which is
exactly backwards.

**Consequences.** The registry schema in part 6 is keyed by the cell, not the
decklist, so per-decklist comparisons are always conditional on a coin-flip
assumption that must be stated. Every replicate also records the **actual turn
achieved**, not just a hit/miss flag.

**Amended 2026-08-29 by ADR 0004.** This record originally proposed a primary outcome
of "on time", defined relative to each cell's own earliest legal turn. Kevin rejected
that in favour of a fixed turn-2 denominator. The stratification decided here — report
per cell, never pool — stands unchanged; only the outcome definition moved. See
ADR 0004.
