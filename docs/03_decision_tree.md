# Part 3 — The Turn 1–2 Decision Tree

**Status: reviewed by Kevin, 2026-08-29 — §9 records the answers.** This is the
English specification of what the player does, which part 5 will implement as the
policy. Nothing here is code yet. Two of §9's answers were *"decide it from the
simulation logs"*, so §3's lead order and §6's use of Ciphermaniac's are written as
defaults the traces are expected to overturn or confirm.

Companion file: `docs/03a_card_playbook.md` gives the per-card rules — when each card
is played, what it searches for, what it discards. This file gives the *shape* of the
turn; that one gives the *content* of each play.

**Goal.** Attack with Evolution Jammer on or before the player's own turn 2
(ADR 0004). Going first and going second are separate branches with separate numbers
(ADR 0002).

---

## 1. Decompose the goal

The target event (`docs/01_rules_standard.md` §5.1) needs four things true at once at
the attack step. Treat them as four independent sub-goals, because they compete for
different resources and fail for different reasons:

| # | Sub-goal | Satisfied by | Scarce resource it consumes |
|---|---|---|---|
| **A** | A **Bronzor** is in play | Setup placement, Poké Pad, Ultra Ball, Buddy-Buddy Poffin*, Brock's Scouting, Telepathic Psychic Energy* | a search card |
| **B** | **Bronzong** is on it | Hilda, Salvatore, Poké Pad, Ultra Ball, Brock's Scouting, or drawn | the Supporter slot, usually |
| **C** | Bronzong is **Active** | Led Bronzor at setup, Switch, Surfer, Latias ex + retreat, Buneary's Run Around | the Supporter slot, or an Item, or the retreat — or, for Run Around, the turn's Energy attachment (§4.2) |
| **D** | A **`[P]` source** is attached | Basic Psychic or Telepathic Psychic Energy | **the turn's one Energy attachment** |

\* printing-dependent — Poffin needs a ≤70 HP Bronzor, Telepathic needs a `[P]` one.

**C is the sub-goal that actually fails.** A, B, and D each have many redundant outs;
C has few, and the cheapest one — *lead Bronzor as the Active at setup* — has to be
chosen before any card is drawn. This is the single most important claim in this
document and part 6 should test it rather than assume it.

## 2. The three resource conflicts

Almost every hard choice on turns 1–2 is one of these three.

**The Supporter slot (one per turn).** Six Supporters want it: Hilda (fetches
Bronzong + Energy), Salvatore (fetches *and* evolves), Lillie's Determination (draw 8
early), Brock's Scouting (2 Basics *or* 1 Evolution), Ciphermaniac's Codebreaking
(stack 2 on top), Surfer (switch + refill). Only one is played. Going first, **none**
can be played on turn 1.

**The Energy attachment (one per turn).** Sub-goal D needs it. So does Enriching
Energy's draw-4, and so does Telepathic Psychic Energy's search-2-Basics. Attaching
the `[P]` source to **Bronzor on turn 1** is usually right: it carries through
evolution, and it frees turn 2's attachment. Attaching Telepathic Psychic Energy to a
`[P]` Bronzor on turn 1 does both jobs at once — pays D *and* searches two Basics.

**The Active spot (one Pokémon).** Bronzor wants it for sub-goal C. Mega Kangaskhan ex
wants it to use Run Errand (draw 2). Flutter Mane wants it for Midnight Fluttering.
Budew wants it to attack Itchy Pollen. These are mutually exclusive on turn 1 unless a
free switch exists.

## 3. Setup: which Basic leads

Decided before any information arrives, and it largely determines whether sub-goal C
is free or expensive.

**Lead Bronzor whenever one is in the opening hand.** It costs nothing — no card, no
Supporter slot, no Energy — and it satisfies C outright. Every alternative to leading
Bronzor costs a card that could have gone to A, B, or D instead.

**The no-Bronzor order below is a default, not a ruling** (Kevin, 2026-08-29: *"I'm
not entirely sure, but this is one of the things that we'll have to optimize based on
the simulation logs."*). It has the same evidentiary status as the §1 claim that C is
the sub-goal that actually fails: a prior to be tested, not a fact. Two consequences
for parts 5 and 6 —

- the lead order is a **policy parameter** that part 6 varies across runs, not a
  constant compiled into the policy;
- every trace records **which Basic actually led**, so the order can be re-derived
  from logs rather than re-argued.

**If no Bronzor is in hand**, lead in this order, and bench everything else:

1. **Mega Kangaskhan ex** — Run Errand draws 2 on turn 1 from the Active spot, and
   with Latias ex benched it retreats for free afterwards. Best combination of
   "does something now" and "gets out of the way later".
2. **Buneary** — *going second only*. Run Around switches into Bronzor once Bronzor is
   found, without spending the Supporter slot or the retreat — but it is **not free**:
   it costs `[C]`, i.e. the turn's Energy attachment, and ends the turn (§4.2). Going
   first it cannot attack, so the option does not exist at all.
3. **Duskull** — 60 HP, retreat 1, free under Skyliner. Harmless.
4. **Budew** — only when the `item_lock` scenario is being played from our side.
5. **Meowth ex** — **never lead it.** Last-Ditch Catch triggers only when it is played
   from hand *onto the Bench*; leading it as the Active wastes the Ability entirely.
6. **Flutter Mane / Latias ex** — lead only if nothing else is available. Latias ex is
   far more valuable benched, where Skyliner still works and it is not exposed.

**Bench everything else that is a Basic**, with two ordering notes: bench **Latias ex**
early (Skyliner is passive and makes every later retreat free), and bench **Meowth ex**
from hand rather than at setup **only if** the deck still holds a Supporter worth
finding — at setup its Ability does not trigger at all, so a setup Meowth ex is a
wasted Ability either way. Prefer to hold it and bench it on turn 1.

## 4. Turn 1 — going second

The strong branch. Supporters are legal, attacking is legal, and with Salvatore the
whole combo can happen now.

**4.1 If the turn-1 kill is live, take it.** It is live when, after drawing:
Bronzor is Active (or can be made Active for free), **Salvatore** is in hand, a
`[P]` source is in hand, and Bronzong is not fully prized. Sequence:

1. Play all free Items first — Poké Pad, Buddy-Buddy Poffin, Ultra Ball — to find the
   `[P]` source or a Bronzor if either is missing. **Do this before Salvatore**, since
   Salvatore shuffles.
2. If Bronzor is benched rather than Active, use **Switch** (an Item — it does not
   cost the Supporter slot). Do *not* use Surfer here: it would consume the Supporter
   slot that Salvatore needs. **Settled** (Kevin, 2026-08-29), on two grounds: the
   Supporter-slot argument, and the plainer one that **no decklist currently runs
   Surfer** — `docs/cards/SSP-187-surfer.md` records it as a candidate only, so today
   the choice is moot. It becomes live only if a Surfer list is added, and the ranking
   should then be re-checked from the logs rather than assumed to have survived.
3. Play **Salvatore** → fetch Bronzong, evolve the Bronzor.
4. Attach the `[P]` source to Bronzong.
5. Attack Evolution Jammer. **Turn ends immediately.**

Note step 4 is after step 3 only for clarity; the attachment may equally go on Bronzor
before evolving. What matters is that the attack is last, because attacking ends the
turn.

**4.2 If the turn-1 kill is not live, build for turn 2.** Do not attack with anything
else unless the attack is free of cost to the plan — an attack ends the turn, which
forfeits every remaining play. The two exceptions worth taking, and they are **not**
symmetric:

- **Buneary's Run Around**, when Bronzor is benched and no Switch is available: it
  puts Bronzor Active for turn 2. **It is a last resort** (Kevin, 2026-08-29), because
  it costs more than the turn. Run Around costs `[C]`
  (`docs/cards/PFL-083-buneary.md`), so it consumes **the turn's one Energy
  attachment** — the same resource sub-goal D needs — and the attached Energy then
  **rides Buneary to the Bench** when the switch resolves, where it can never pay for
  Evolution Jammer. So:
  - take it only after every other play, and only when C has no other out this turn
    (no Switch, no free retreat under Latias ex);
  - **pay it with Enriching Energy** where possible — it is `[C]`, it is not a `[P]`
    source, and attaching it draws 4, so the stranded card is the one we could most
    afford to strand;
  - if the only Energy in hand is a `[P]` source, **decline Run Around**, unless a
    second `[P]` source is in hand. Otherwise turn 2 arrives with Bronzong Active and
    nothing legal to attach — trading a failure of C for a failure of D.
- **Budew's Itchy Pollen**, if we are the disruption side — same logic, take it last,
  but note Itchy Pollen has **no Energy cost** (`docs/cards/ASC-016-budew.md`), so it
  costs only the turn. None of the Energy reasoning above applies to it.

Otherwise the turn-1 build order is:

1. Bench every Basic in hand (free, and grows the board for later searches).
   Bench **Meowth ex** here to trigger Last-Ditch Catch → fetch the Supporter that
   turn 2 will want (usually **Hilda**).
2. Play free search Items — **Poké Pad** first (no cost), then **Buddy-Buddy Poffin**,
   then **Ultra Ball** only if its two-card discard is affordable.
3. Get Bronzor Active if it is not: **Switch**, else free retreat under Latias ex.
4. Play the Supporter — see §6 for which.
5. Attach the `[P]` source to **Bronzor**, so turn 2's attachment is free.
   Prefer **Telepathic Psychic Energy** here if Bronzor is the `[P]` printing, since
   the attach also searches two Basics onto the Bench.
6. Play a Stadium if holding one and it is not disruptive to us.

## 5. Turn 1 — going first

The weak branch, and the one the deck is built to survive rather than exploit.
**No Supporter, no attack.** Turn 1 is purely Items, Energy, benching, and retreating,
and the whole turn exists to set up turn 2.

1. Bench every Basic in hand, **Meowth ex included** — its Ability is not a Supporter,
   so it still works, and the Supporter it finds is played on turn 2. This makes
   Meowth ex disproportionately valuable on this branch.
2. Play free search Items — Poké Pad, Buddy-Buddy Poffin — targeting **Bronzor first**
   (sub-goal A), then whatever is missing.
3. **Ultra Ball**, if affordable, is the only Item that finds **Latias ex**.
4. Get Bronzor Active: **Switch**, else free retreat under Latias ex. Doing this on
   turn 1 is strongly preferred, because turn 2 needs its Supporter slot for Hilda or
   Salvatore, not for Surfer.
5. Attach the `[P]` source to Bronzor.
6. **Pokégear 3.0**, if in the list — it is the only Item that digs for a Supporter,
   which is exactly what this branch cannot otherwise do. Play it *last*, and never
   after a Ciphermaniac's stack, because it shuffles.

## 6. Choosing the Supporter

Applies on turn 1 going second, and on turn 2 on both branches. Evaluate in order and
play the first that applies:

| Priority | Play | When |
|---|---|---|
| 1 | **Salvatore** | Turn 1 going second, and the kill is live (§4.1). Never otherwise on turn 1 — its exemption is wasted on turn 2. |
| 2 | **Hilda** | Bronzong or the `[P]` source is missing. Fetches both in one card; the single most efficient Supporter for sub-goals B and D. |
| 3 | **Brock's Scouting** | Bronzor is missing *and* Latias ex is wanted — Basics mode gets both, and it is the only free way to find Latias ex. Otherwise use Evolution mode for Bronzong only if Hilda is gone. |
| 4 | **Lillie's Determination** | Hand is weak and nothing above applies. Draws **8** while both players still have 6 Prizes. **Play everything else first** — it shuffles the hand away. |
| 5 | **Surfer** | Bronzor is benched, no Switch, and no Salvatore line this turn. Solves C and refills. Play last in the turn so the refill is large. |
| 6 | **Ciphermaniac's Codebreaking** | **`P2T1` only** — going second, on our first turn — and only when nothing above applies. It stacks two cards on top, of which turn 2 draws exactly **one**. Never followed by any shuffling card. |

**Why Ciphermaniac's is confined to `P2T1`** (Kevin, 2026-08-29). Three facts fence it
into exactly one cell of the design:

- **Going first, turn 1**: no Supporter may be played at all
  (`docs/01_rules_standard.md` §6), so the card cannot be played.
- **Turn 2, either branch**: the draw step has already happened when the Supporter is
  played, so both stacked cards sit on top of a deck the measured window never draws
  from again. Inside the metric it does literally nothing.
- **`P2T1`**: no evolution is legal on your own first turn (`§5`), absent Salvatore.
  So a Bronzong in hand is dead this turn regardless, and the Supporter slot has no
  better *immediate* conversion — which is exactly what makes spending it on next
  turn's draw defensible here and nowhere else.

Kevin's caveat stands: even within `P2T1` this "should depend heavily on the context
on my field and hand." So, like the §3 lead order, treat the choice as a **logged
decision** — the policy records that it fired and what it stacked, and part 6 decides
from traces whether it should have.

## 7. Turn 2 — both branches

By now sub-goals A and D should be done. Turn 2 resolves B and C and attacks.

1. Play free Items first (they may still find what is missing) — but **not** anything
   that shuffles if a Ciphermaniac's stack is pending and undrawn.
2. Resolve **C** if still open: Switch, free retreat under Latias ex, or Surfer.
3. Resolve **B**: evolve Bronzor → Bronzong from hand, or fetch it with Hilda /
   Salvatore / Brock's Scouting.
4. Resolve **D** if still open: attach a `[P]` source. Remember Enriching Energy is
   **not** one.
5. **Attack Evolution Jammer.**

**The window closes at the end of turn 2, and nothing past it is recorded** (Kevin,
2026-08-29; ADR 0007). There is no turn 3 in the simulator: no turn-3 play, no turn-3
distribution, no "how many misses would have hit next turn".

If the target event is unreachable this turn, the replicate is a **miss** — but the
policy must still play the turn out properly, for a different reason than the one
previously given here: the **end-of-turn-2 board state is recorded in full** and will
be analysed later, so a turn played sloppily once the metric is lost corrupts that
record. The snapshot (`R/trace_claude.R` → `format_trace()`) captures, as ground truth
at the moment the window closes:

| Group | Fields |
|---|---|
| Board | Active and each Benched Pokémon — the full evolution stack, attached Energy, damage, and the turn it was played or evolved |
| Zones | hand, discard, deck size, Stadium in play, Prizes remaining |
| Hidden | prized card identities, labelled **ground truth** — analysis-only, and never readable by the policy (ADR 0003) |
| Turn | Energy attached this turn, Supporter played this turn, whether Items were locked |
| Setup | which Basic led, so the §3 order can be settled from logs |

## 8. Explicit non-goals for turns 1–2

Recorded so the policy is not written to chase them:

- **Do not evolve Dusknoir** with Rare Candy on turn 2 in preference to Bronzong.
  Dusknoir is the deck's damage plan, not its lock plan, and the metric measures only
  the lock.
- **Do not use Dusclops/Dusknoir's Cursed Blast**, which Knocks Out the user.
- **Do not play Boss's Orders.** It only moves the opponent's Pokémon and cannot
  advance any sub-goal.
- **Do not play Special Red Card.** It is unplayable above 3 opposing Prizes.
- **Do not attack with anything other than Evolution Jammer**, except the two cases in
  §4.2, because attacking ends the turn.

## 9. Answers from Kevin, 2026-08-29

All five questions this file previously asked are answered. Two are *settled*; two are
deliberately **deferred to the simulation logs**, which makes them part 6's job, not
Kevin's; one corrected a factual error in this document.

| # | Question | Answer | Status |
|---|---|---|---|
| 1 | §3 lead order | Not sure — optimize it from the simulation logs. | **Deferred to logs.** Lead order is a policy parameter; the trace records the lead. See §3. |
| 2 | §4.1 Switch vs Surfer | Switch, on the gut-feeling grounds that no list currently runs Surfer. | **Settled for now**, re-checkable from logs if a Surfer list is ever added. See §4.1. |
| 3 | §6 Ciphermaniac's on turn 1 | Only as the going-second player on our own first turn — we cannot evolve Bronzor that turn anyway — and even then it depends heavily on field and hand. | **Settled to one cell** (`P2T1`); the within-cell choice is logged, not asserted. See §6. |
| 4 | §4.2 declining Run Around | Only when there is really nothing else to do, since it also sacrifices an Energy. | **Settled.** It corrected this file: Run Around costs `[C]`, i.e. the turn's attachment, and strands it on the Bench. See §4.2. |
| 5 | Recording past turn 2 | No — stop at turn 2, but be thorough at the *end* of turn 2 so the board state can be assessed later. | **Settled.** No turn 3 anywhere; the end-of-turn-2 snapshot is widened instead. See §7. |

### Now empirical questions for part 6, not questions for Kevin

- **The §3 lead order** — which non-Bronzor lead maximises the hit rate, per cell.
  Kangaskhan-first is only the current default.
- **Ciphermaniac's within `P2T1`** — which board and hand states make stacking better
  than Hilda, Lillie's, or Brock's Scouting.

Both belong with the §1 claim that **C is the sub-goal that actually fails**: three
priors this document asserts and the traces are supposed to adjudicate.

Note `docs/03a_card_playbook.md` still carries **four** unanswered questions of its
own — Ultra Ball discard priority, the Telepathic Psychic Energy target, whether
Mystery Garden is worth modelling, and Rare Candy → Dusknoir on a lost turn 2.
