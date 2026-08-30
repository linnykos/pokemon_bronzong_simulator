# Pokémon TCG Bronzong Simulator — Context

A Monte Carlo simulator for Pokémon TCG opening hands and early-turn play. This
file records what this project's words mean; it does not describe what we do with
them. Decisions live in `docs/adr/`; rules live in `docs/01_rules_standard.md`.

Entries marked **[unconfirmed]** are Claude's coinages and need Kevin's sign-off
before later sessions treat them as settled.

## Game structure

**Turn**:
One player's own turn, numbered **per player**: `P1T2` is the first player's
second turn. Global order is P1T1 → P2T1 → P1T2 → P2T2. A bare "turn 2" always
means the player's own second turn, never the second turn of the game.
_Avoid_: round, global turn

**Going first / going second**:
Which side of the opening coin flip the simulated player is on. It is not a
strategy choice in the simulator — both are simulated, and results are reported
separately, because the first player may play no Supporter and may not attack.
_Avoid_: on the play, on the draw

**Opening hand**:
The 7 cards a player holds once all mulligans have resolved, before any Pokémon
are placed.

**Known divergence, needs Kevin's call.** The real rule also grants **1 bonus
card per mulligan the *opponent* took**, so a real opening hand is sometimes 8 or
9 cards. The simulator models only one player, so it has no opponent mulligan
count and always produces exactly 7. This biases every consistency estimate
slightly **downward** — the direction is at least safe, but the size is unknown.
Fixing it means either modelling an opposing decklist or drawing the bonus count
from an assumed distribution.
_Avoid_: starting hand, test hand (see **Replicate**)

**Prized**:
Among the 6 cards set aside face down at setup. A prized card is both unavailable
for the whole measured window and **unknown to the player** — those are two
separate facts and the simulator must honour both.
_Avoid_: buried, out of the deck

## The target

**Target event**:
The thing being measured. At the attack step: a Bronzor is in play and eligible to
evolve, Bronzong TEF 69 is on it, that Bronzong is **Active**, it has at least one
`[P]` source attached, and nothing prevents it attacking. Attacking with Evolution
Jammer is the whole event — having Bronzong in play is not.
_Avoid_: getting Bronzong out, setting up Bronzong

**On time**:
**The primary outcome.** The target event was achieved on or before the player's
**own second turn** — the same fixed bar going first and going second, and for
every decklist. A turn-1 Salvatore kill and a turn-2 conventional line both count
as on time; that is deliberate (ADR 0004).
_Avoid_: success, hit, by turn 2

**Earliest legal turn**:
The earliest turn on which the target event is *possible at all* for a given
decklist and coin flip — turn 1 for a Salvatore list going second, turn 2
otherwise. **This is a property of the game, not the metric.** It was considered
as the outcome's denominator and rejected, because it makes the headline number
mean different things for different lists. Use it to reason about what is
achievable, never to score.
_Avoid_: the first turn possible (as a metric)

**Turn achieved**:
The turn number on which the target event actually occurred in a replicate, or
`NA` if it never did. Recorded on every replicate. This is where Salvatore's
turn-1 speed is visible, since **on time** is designed not to price it.

## Cards and decks

**Bronzor**:
**Ambiguous on its own — always qualify by set and number.** Three different
cards share the name: TEF 68 (Psychic, 80 HP), PRE 66 (Metal, 70 HP), and SSP 126
(Metal, 60 HP). All three evolve into Bronzong TEF 69, but only the two Metal ones
are fetchable with Buddy-Buddy Poffin and only the Psychic one is findable with
Telepathic Psychic Energy. A sentence that says "Bronzor" without a printing is
under-specified.

**`[P]` source**:
A card that can pay Evolution Jammer's `[P]` cost. Exactly two qualify: basic
Psychic Energy (SVE 5 / MEE 5) and Telepathic Psychic Energy (POR 88).
**Enriching Energy is not a `[P]` source** despite being an Energy card — it
provides `[C]`. Counting all Energy as `[P]` sources is the single easiest way to
overstate a list's consistency.
_Avoid_: energy, psychic energy (when the special counts too)

**Decklist**:
A specific 60-card multiset — the unit of comparison. Identified by its
**contents**, not its filename: two files with the same multiset in a different
line order are one decklist, not two.
_Avoid_: list, deck (when the physical deck's shuffled order is meant)

**Deck**:
The shuffled, ordered pile a player draws from during a game, after prizes are
removed. Contrast **Decklist**, which is unordered and has 60 cards.

**Shell** *[unconfirmed]*:
The cards present in identical counts across every candidate decklist. Not a
variable; the fixed background against which the variables are compared.

**Whiff** *[unconfirmed]*:
A search that resolves without finding its target, because every copy is prized or
already gone. A whiff is **information the player earns** — it is how a real
player learns a card is prized — and the policy is entitled to act on it.
_Avoid_: fail, brick

## Simulation

**Measured window**:
Setup through the end of the player's **own turn 2**. Nothing after it is played,
decided, or recorded (ADR 0007) — there is no turn 3 in the simulator. Used
throughout this file and already load-bearing before it was defined. Distinct
from the **on time** bar, which is when the target event must happen: the bar
could have been turn 2 while the engine played on, and deliberately is not.
_Avoid_: horizon, simulation length

**Replicate**:
One simulated game: shuffle, prizes, mulligans, setup, and play through the
measured window. The unit the outcome is counted over. Kevin's original phrase
"test hand" refers to this, but a replicate is a whole game to the decision point,
not just an opening hand.
_Avoid_: test hand, trial, iteration

**Scenario**:
A named model of opponent behaviour — `clear` (opponent does nothing) or
`item_lock` (opponent leads Budew and attacks with Itchy Pollen). A scenario
constrains us; it is not an opposing decklist.

**Cell**:
A (decklist, scenario, going-first-or-second) triple. **The unit at which results
are reported, and never pooled across** — see `docs/adr/0002`.
_Avoid_: condition, arm, group

**Policy**:
The code that makes the player's in-game choices. Distinguished from the rules
engine, which decides what is *legal*; the policy decides what is *done*. The
policy may read only the **belief state**, never ground truth — see
`docs/adr/0003`.
_Avoid_: strategy, AI, agent

**Belief state**:
What the player knows at a given moment, as opposed to the true game state.
Holds the hand, the board, the discard, and everything learned from resolved
effects. Two facts about it are easy to get wrong and are the whole reason it
exists separately: deck **contents** become known at the first deck search and
stay known, while deck **order** is never known and is destroyed again by the
reshuffle after every search.
_Avoid_: game state, knowledge

## Measurement and traces

**Mulligan**:
A redraw forced by an opening hand with no Basic Pokémon. **Never counted as a
miss** (ADR 0005) — the redrawn hand is the one played. Reported as two
orthogonal metrics, `mulligan_rate` (share of replicates needing at least one)
and `mean_mulligans`, always beside the hit rate and never folded into it.
_Avoid_: bad opening, failed start

**Trace**:
A compact account of one replicate from setup to the end of turn 2, kept for a
small **stratified** sample of replicates and written to `results/*_traces.txt`.
Because the sample is deliberately over-weighted toward misses, a trace file is
**not representative of the outcome distribution** and no rate may be computed
from it.
_Avoid_: log, sample (bare)

**Blocking sub-goal**:
Which of the four sub-goals in `docs/03_decision_tree.md` §1 — A Bronzor in
play, B Bronzong on it, C Bronzong Active, D a `[P]` source attached — was still
unmet when the window closed. Reported as the **set** of unmet sub-goals, never
as one: because the letters run A–D, reporting only the first meant C could
appear only when A and B both held, which hid the very hypothesis the project
exists to test. `first_unmet` is kept as a sortable rollup and is named so that
nobody reads it as the cause.
_Avoid_: failure reason, cause

**Unused out**:
A card **still in hand** at the end of a missed replicate that could have
advanced the blocking sub-goal. The distinguishing signal of a **decision**
defect rather than a deck defect: the card was there and was not played, so the
fix belongs in `docs/03_decision_tree.md`, not in the 60 cards.
_Avoid_: dead card, missed play

**Event level**:
Log entries are level 1 (a semantic action a player would recognise — "play
Hilda", "evolve into Bronzong") or level 2 (an implementation primitive — a zone
move, a shuffle, a draw). Traces keep level 1 only; keeping both makes the trace
unreadable, which defeats its purpose.
