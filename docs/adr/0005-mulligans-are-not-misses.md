# 0005 — A mulligan is not a miss; it is an orthogonal metric

An opening hand with no Basic Pokemon is redrawn, and it is the redraw that gets
played. **The simulator therefore never counts a mulligan against the decklist**:
the hit rate is computed over games as actually played, and a game that took two
mulligans and then hit on turn 2 is a hit, full stop. Kevin's decision.

**Considered and rejected:** treating a mulligan as a failed opening. It is
defensible — a list that mulligans often really is worse, and the opponent draws
a bonus card each time — but it conflates two different questions into one
number, and the conflated number cannot be acted on: it moves when either the
Basic count or the combo consistency changes, and the reader cannot tell which.

**Consequences.** Two mulligan figures are reported **beside** the hit rate and
never folded into it: `mulligan_rate` (fraction of replicates needing at least
one) and `mean_mulligans`. They are orthogonal in the sense that matters — a
decklist can be tuned to improve one while worsening the other, and that
trade-off should be visible rather than averaged away. Raising the Basic count
lowers the mulligan rate and typically costs slots that the combo wants; this
design lets that show up as two numbers moving in opposite directions instead of
one number not moving.

Note the mulligan rate is a **lower bound on the real cost**: each of our
mulligans also hands the opponent a bonus card, which is not modelled at all
(see the `Opening hand` entry in `CONTEXT.md`).
