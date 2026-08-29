# 0004 — The primary outcome is Evolution Jammer by the player's own turn 2

ADR 0002 originally proposed measuring each cell against its own **earliest legal
turn** — turn 1 for a Salvatore list going second, turn 2 everywhere else. Kevin
rejected that denominator: it makes the headline number mean a different thing for
different decklists, so a Salvatore list and a non-Salvatore list can no longer be
put side by side. **The primary outcome is instead fixed: did the player attack with
Evolution Jammer on or before their own second turn?** The same definition applies
going first and going second, so every cell's number answers the same question.

**The two coin-flip branches are still reported as separate numbers** — ADR 0002 is
unchanged and this record does not merge them. What is shared between them is the
*definition* of success (turn 2), not the statistic: a run produces a going-first rate
and a going-second rate, always, and they are never averaged into one figure. Fixing
the definition is what makes the two numbers meaningful to compare; pooling them would
still be wrong.

**Going first** is unaffected by Salvatore either way — the first player may play no
Supporter and may not attack, so turn 1 is impossible regardless and turn 2 was always
the only floor.

**Going second**, this deliberately counts a turn-1 Salvatore kill and a turn-2
conventional line as the *same* success. That is the point: it isolates "does this
list assemble the combo in the window" from "does this list happen to own the card
that compresses the window."

**Considered and rejected:** the per-cell earliest-legal-turn denominator from
ADR 0002. It flatters Salvatore lists on the going-second cell by grading them against
a harder bar and then reporting the result as if it were the same measurement.

**Consequences.** Salvatore's turn-1 speed is invisible in the primary outcome by
design, so it must not be lost: every replicate records the **actual turn achieved**,
and the distribution over turns is reported alongside the headline rate. The turn-1
rate on the going-second cell is the natural secondary outcome and is where Salvatore's
value actually shows up — it is a real advantage (it locks the opponent's evolutions a
full turn earlier) that this project's primary metric is not designed to price.
