# Part 3 — The Turn 1–2 Decision Tree

**Status: this file is the specification, and `R/decision_claude.R` follows it.**
Kevin edits here; the code is realigned afterwards, never the other way round
(`CLAUDE.md` → *The decision documents are the specification*). As of 2026-08-30
the two agree, so any divergence from here is a deliberate edit rather than drift.

**This file states the tree as it stands, in the present tense, and nothing else.**
A rule written as a **default** rather than a ruling says so in place and carries a
`DT-nn` entry in §9; §3's lead order is the largest of them. Where a rule is
**specified and not implemented**, it says that in place too.

How a rule came to read the way it does is not here — that is `HISTORY_kevin.md`,
or an ADR this file cites by number.

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
| **C** | Bronzong is **Active** | Led Bronzor at setup, Latias ex + retreat, Switch, Surfer, Buneary's Run Around, Cursed Blast (§8) | the Supporter slot, or an Item, or the retreat — or, for Run Around, the turn's Energy attachment (§4.2); ordered in §4.3 |
| **D** | A **`[P]` source** is attached | Basic Psychic or Telepathic Psychic Energy | **the turn's one Energy attachment** |

\* printing-dependent — Poffin needs a ≤70 HP Bronzor, Telepathic needs a `[P]` one.

**C is the sub-goal that actually fails.** A, B, and D each have many redundant outs;
C has few, and the cheapest one — *lead Bronzor as the Active at setup* — has to be
chosen before any card is drawn. This is the single most important claim in this
document and part 6 should test it rather than assume it.

## 2. The four resource conflicts

Almost every hard choice on turns 1–2 is one of these four.

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

**Bench space (five slots, and one of them is spoken for).** Do not overfill the
Bench; one slot, realistically, is saved for Latias ex. This is the conflict that
constrains the other three, and a body on the Bench is not free:

- **A benched Basic cannot be un-benched.** Playing it converts a card that still had
  options — an Ultra Ball discard, a Lillie's redraw — into a body that does nothing
  unless it is Latias ex, Meowth ex, or the Bronzor itself.
- **Latias ex needs a slot**, and it is the one Basic whose mere presence advances a
  sub-goal (Skyliner → C).
- Filling the Bench early is therefore a **cost paid for nothing** in most hands. The
  rule everywhere below is: bench a Pokémon when the body does work *this turn* or the
  next, and otherwise leave it in hand.

## 3. Setup: which Basic leads

Decided before any information arrives, and it largely determines whether sub-goal C
is free or expensive.

**Lead Bronzor whenever one is in the opening hand.** It costs nothing — no card, no
Supporter slot, no Energy — and it satisfies C outright. Every alternative to leading
Bronzor costs a card that could have gone to A, B, or D instead.

**The no-Bronzor order below is a default, not a ruling** — it is to be optimized from
the simulation logs (DT-03). It has the same evidentiary status as the §1 claim that C
is the sub-goal that actually fails: a prior to be tested, not a fact. Two consequences
for parts 5 and 6 —

- the lead order is a **policy parameter** that part 6 varies across runs, not a
  constant compiled into the policy;
- every trace records **which Basic actually led**, so the order can be re-derived
  from logs rather than re-argued.

**If no Bronzor is in hand**, lead in this order — and, per the rule below, bench
none of the rest:

1. **Mega Kangaskhan ex** — Run Errand draws 2 on turn 1 from the Active spot, and
   with Latias ex benched it retreats for free afterwards. Best combination of
   "does something now" and "gets out of the way later".
2. **Buneary** — *going second only*. Run Around switches into Bronzor once Bronzor is
   found, without spending the Supporter slot or the retreat — but it is **not free**:
   it costs `[C]`, i.e. the turn's Energy attachment, and ends the turn (§4.2). Going
   first it cannot attack, so the option does not exist at all.
3. **Duskull** — 60 HP, retreat 1, free under Skyliner. Harmless.
4. **Budew** — only when the `item_lock` scenario is being played from our side.
   **This condition can never be true as the project is currently set up**, so
   Budew's rank here has never been exercised: `item_lock` models the *opponent's*
   Budew locking us, and we are never the disruption side (`CLAUDE.md` →
   *Scenarios*). Either the condition or the scenario list needs to change before
   this line means anything.
5. **Meowth ex** — **never lead it.** Last-Ditch Catch triggers only when it is played
   from hand *onto the Bench*; leading it as the Active wastes the Ability entirely.
6. **Flutter Mane / Latias ex** — lead only if nothing else is available. Latias ex is
   far more valuable benched, where Skyliner still works and it is not exposed.

**Bench nothing at setup.** Place the Active and stop; every other
Basic stays in hand, where benching it later is a *decision* taken with information
rather than a placement made blind. Latias ex included — Skyliner does nothing before
our first turn anyway, and benching it on turn 1 costs the same nothing. Meowth ex in
particular must be held: its Ability triggers only on being played from hand onto the
Bench, so a setup Meowth ex is a wasted Ability outright.

**Why this is safe here, and why it would not be in a real game.** An empty Bench
means a Knocked Out Active loses the game on the spot. Inside this window it cannot
happen: the only damage either scenario deals is Itchy Pollen's 10, and the smallest
body we would ever lead is Duskull's 60 HP. Do not carry this rule past turn 2 or into
a scenario that can attack for real.

## 4. Turn 1 — going second

The strong branch. Supporters are legal, attacking is legal, and with Salvatore the
whole combo can happen now.

**4.1 If the turn-1 kill is live, take it.** It is live when, after drawing:
Bronzor is Active (or can be made Active for free), **Salvatore** is in hand, a
`[P]` source is in hand, and Bronzong is not fully prized. Sequence:

1. Play the free Items — Poké Pad, Buddy-Buddy Poffin, Ultra Ball — to find the `[P]`
   source or a Bronzor if either is missing. **The order against Salvatore does not
   matter**: a shuffle costs nothing when every play involved is a *search*. Only two
   orderings actually bind anywhere in this document, and neither is this one: a
   pending **Ciphermaniac's** stack versus any shuffling card (§5, §7), and
   **Lillie's Determination**, which shuffles the hand into the deck and so must come
   after everything you meant to play (§6).
2. If Bronzor is benched rather than Active, move it — see **§4.3** for the ladder.
   Within *this* line the Supporter slot is Salvatore's, so Surfer is unavailable
   whatever the hand looks like: playing it does not lose the switch, it loses the
   turn-1 kill. **Switch beats Surfer here on the simpler ground too — no decklist
   runs Surfer at all**, so Switch is the operative second rung in every list that
   exists today.
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
  puts Bronzor Active for turn 2. **It is a last resort**, because
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
  **Specified and not implemented**, for the same reason as the §3 Budew lead: we
  are never the disruption side in either modelled scenario.

Otherwise the turn-1 build order is:

1. Take the free Abilities — see §4.5. Run Errand first of all, since it changes
   the hand every later step reads.
2. Bench **selectively** — see §4.4. Not every Basic in hand.
3. Play free search Items — **Poké Pad** first (no cost), then **Buddy-Buddy Poffin**,
   then **Ultra Ball** only if its two-card discard is affordable.
4. Get Bronzor Active if it is not — the ladder in §4.3.
5. Play the Supporter — see §6 for which.
6. Attach the `[P]` source to **Bronzor**, so turn 2's attachment is free — but
   **only while sub-goal D is unmet**. Once the Bronzor that will attack already
   carries a `[P]` source, the attachment is spent and a second Energy buys
   nothing: D is paid, and Evolution Jammer costs one `[P]` and no more. A second
   Telepathic in hand is **not** a reason to attach for the search's sake, because
   the fetch fills Bench slots §4.4 is holding for Latias ex.

   Prefer **Telepathic Psychic Energy** for the attachment that *does* pay D, if
   Bronzor is the `[P]` printing, since the attach also searches two Basics onto
   the Bench. That preference is a tie-break and never a reason to decline: on a
   Metal Bronzor the Telepathic still pays D and simply fires nothing, which is
   still worth doing. **Take both targets, even when only one is wanted** — every
   card pulled out of the deck also *thins* it, and a thinner deck is a better
   chance the next draw is the Bronzong the turn is missing. Bench space is the
   only cap (§4.4).
7. Play a Stadium if holding one and it is not disruptive to us. None of the four
   advances a sub-goal, so this is for the end-of-turn-2 board record (§7) rather
   than for the metric; **Mystery Garden is excluded**, since its text would cost
   a `[P]` source to draw.

**4.3 Moving Bronzor into the Active spot.** Stated once here; §5 and §7 use the same
ladder. Take the first that is available:

1. **Free retreat under Latias ex.** Skyliner zeroes the retreat of every *Basic* we
   control, and on turns 1–2 the Active is almost always a Basic. The retreat is the
   turn's, it is otherwise unused, and it costs no card — so **do not spend a Switch
   while Skyliner covers the Active**, and **keep the Switch in hand** rather than
   holding the retreat back for a second reposition the turn will not need.
   Unavailable if something locks the retreat, and — the case that matters later —
   Skyliner does **not** cover a Stage 1, which is exactly how a Dusclops gets
   stuck (§8).
2. **Switch.** An Item, so it costs no Supporter slot; the right answer whenever the
   retreat is not free — including the turn on which the retreat has already been
   spent.
3. **Surfer.** Costs the Supporter slot, so it loses to Switch by default — **except
   on a nearly empty hand**, where "draw until you hold 5" makes it a switch *and* a
   refill and it can be the better card outright. Never in the §4.1 kill line, where
   the slot is Salvatore's.
4. **Buneary's Run Around** — last resort only, and read §4.2 first: it spends the
   turn's Energy attachment and strands it on the Bench.
5. **The Cursed Blast escape** — the last door, spelled out in §8. A Dusclops or
   Dusknoir Active uses its own Ability and Knocks itself Out, and we choose the
   Bronzor from the Bench as the replacement Active; from a **Duskull** Active,
   Rare Candy reaches a Dusknoir first. It costs the Pokémon and a Prize from our
   opponent's pile, and it is right anyway when the alternative is a turn that
   cannot attack at all.

**The ladder is walked after the searches, not before them.** Find out what the
deck will give you first — a Poké Pad that turns up the Bronzong changes which rung
is worth taking — then move. Where the retreat and a Switch are both available the
retreat goes first regardless, so the ordering question is only ever about
*information*, never about which mover to spend.

**4.4 What to bench, and when.** The Bench is a scarce resource (§2), so benching is a
play to be justified, not a reflex. Bench:

- **Latias ex — always, at the first opportunity.** It is the one Basic whose presence
  alone advances a sub-goal, and it makes step 1 of §4.3 free for the rest of the game.
- **Meowth ex — when a specific Supporter is wanted and is not in hand**, since
  Last-Ditch Catch fetches exactly that (usually **Hilda**). If the Supporter we want
  is already in hand, benching Meowth ex buys a wasted Ability and a spent slot.
- **A Bronzor**, when none is in play — that is sub-goal A, and benching is its
  cheapest out.
- **Everything else only when Lillie's Determination is this turn's Supporter**, and
  then *before* playing it. Lillie's shuffles the **hand into the deck**, so any
  Pokémon still in hand is buried; putting them on the Bench first keeps them
  This is the one case where filling the Bench is correct.

**4.5 Free Abilities, taken before anything else.** §2 notes that Mega Kangaskhan
ex wants the Active spot for Run Errand; this is the step that actually uses it.

- **Run Errand — every turn Kangaskhan is Active.** Draw 2, once per turn, and it
  costs nothing, so there is no state in this window where two more cards are
  unwanted. Take it **first**: every later decision reads the hand, and §4.3 is
  about to retreat or Switch Kangaskhan out of the only spot the Ability works.
- **Last-Ditch Catch** is not here because it fires on *benching* Meowth ex, which
  is a §4.4 decision rather than a free action.

Skipping Run Errand is not a small thing. A Kangaskhan lead measured without the
two-card draw comes out near the bottom of the lead table at 40.9%; with it, the
same lead reaches 55.8%. A lead order measured with a card's Ability switched off
is measuring the policy, not the deck.

## 5. Turn 1 — going first

The weak branch, and the one the deck is built to survive rather than exploit.
**No Supporter, no attack.** Turn 1 is purely Items, Energy, benching, and retreating,
and the whole turn exists to set up turn 2.

1. Take the free Abilities first (§4.5), then bench selectively, per §4.4 —
   **Meowth ex is the exception worth taking here**. Its
   Ability is not a Supporter, so it works on a turn when no Supporter may be played,
   and the card it finds is played on turn 2. That makes Meowth ex disproportionately
   valuable on this branch, and it is the one branch where benching it is close to
   automatic: the Supporter we want is by definition not playable yet.
2. Play free search Items — Poké Pad, Buddy-Buddy Poffin — targeting **Bronzor first**
   (sub-goal A), then whatever is missing.
3. **Ultra Ball**, if affordable, is the only Item that finds **Latias ex**.
4. Get Bronzor Active — the §4.3 ladder, so free retreat before Switch. Doing this on
   turn 1 is strongly preferred, because turn 2 needs its Supporter slot for Hilda or
   Salvatore, not for Surfer.
5. Attach the `[P]` source to Bronzor.
6. **Pokégear 3.0**, if in the list — it is the only Item that digs for a Supporter,
   which is exactly what this branch cannot otherwise do. Play it *last*, and never
   after a Ciphermaniac's stack, because it shuffles.

## 6. Choosing the Supporter

Applies on turn 1 going second, and on turn 2 on both branches.

**Rank by what each Supporter can actually solve, not by how many sub-goals are
open.** Every card below closes a specific, known set of the four, and the slot goes
to whichever closes the most of what is *currently* missing. Counting open sub-goals
and thresholding on the count is the wrong instrument: two hands with three sub-goals
open can want different Supporters, because the Supporters differ in which three they
can reach.

| Solves | Card |
|---|---|
| **B**, bypassing evolution timing | Salvatore |
| **B and D** together | Hilda |
| **A**, and **C** via Latias ex | Brock's Scouting, Basics mode |
| **B** | Brock's Scouting, Evolution mode |
| **C**, plus a refill | Surfer |
| any *one* of B, C, D — and only into turn 2's draw | Ciphermaniac's Codebreaking |
| nothing directly; replaces the hand | Lillie's Determination |

Evaluate in order and play the first that applies:

| Priority | Play | When |
|---|---|---|
| 1 | **Salvatore** | Turn 1 going second, and the kill is live (§4.1). |
| 2 | **Salvatore, on turn 2** | B is unmet and a `[P]` source is already secured — in hand or attached — so Hilda's second search would add nothing. Salvatore fetches Bronzong **and puts it on the Bronzor**, which also beats Hilda outright when the only Bronzor reached play *this* turn and so cannot be evolved from hand (ADR 0001). |
| 3 | **Hilda** | Bronzong or the `[P]` source is missing, **and she can actually fetch what is missing**. Fetches both in one card; the single most efficient Supporter for sub-goals B and D. Once she is chosen she takes **both** searches whatever the hand holds — see `docs/03a_card_playbook.md`. |
| 4 | **Brock's Scouting** | **Basics mode** when a Bronzor is missing **or sub-goal C is blocked** — Basics mode is the only free way to find Latias ex, and with the line stuck on the Bench that is the missing piece. **Evolution mode** for Bronzong when B is unmet and **Hilda is gone** — neither in hand nor believed to be in the deck — since while Hilda is reachable the slot is worth more to her, who fetches the Bronzong *and* an Energy. |
| 5 | **Lillie's Determination** | Hand is weak — **four cards or fewer**, a policy default rather than a ruling, like the §3 lead order — and nothing above applies. Draws **8** while *we* still hold 6 Prizes. **Play everything else first** — it shuffles the hand into the deck — and **bench the Pokémon you want to keep before playing it** (§4.4), or they are buried with the rest of the hand. |
| 6 | **Surfer** | Bronzor is benched and the §4.3 ladder has got that far — no free retreat, no Switch, no Salvatore line this turn. Solves C and refills. Play last in the turn so the refill is large; on a nearly empty hand it can be the better card even against a Switch. |
| 7 | **Ciphermaniac's Codebreaking** | **`P2T1` only** — going second, on our first turn — and only when **exactly one** of B, C and D is missing, since it delivers exactly one card into turn 2's draw. Two missing pieces are one more than it can fix. |
| 8 | **The fallback: never end a turn with the slot unspent.** | Nothing above fired, and a Supporter in hand is legal and would change the board or the hand at all. Play it. Order: Lillie's, then a Hilda who can still fetch *one* of her two targets, then Brock's, then Salvatore, then Ciphermaniac's. |

**Priority 8 is the rule that makes the rest of the table safe.** One Supporter may
be played per turn and an unplayed one carries no credit into the next; a slot left
idle is a resource destroyed, not saved. So the thresholds above — Hilda's "can fetch
something", Lillie's four-card hand, Ciphermaniac's single missing piece — are about
*which* Supporter to prefer, never about whether to play one. If a Supporter would
improve the position even slightly, it is played.

Two guards, and only two. The fallback fires **after** every other play of the turn
has resolved, so Lillie's never shuffles away a card the turn still meant to use; and
it never plays a card that cannot legally resolve at all.

**And then the turn is assembled again, over whatever it drew.** Bench, evolve,
position, attach — the four steps of §7 run a **second time** after the fallback
Supporter, because a Supporter played at the end of a turn whose cards are never
played increases nothing, and the window closes at the end of turn 2 with no later
turn to spend them on. This is the difference between the fallback being worth 10
points and worth 15: without the second pass it does nothing at all on turn 2.

The second pass changes no rule, only when the rules are read. Everything it does is
a play the turn was always allowed to make — one evolution, one attachment, one
retreat — and each is still capped at once per turn by the rules rather than by the
number of passes.

**Why Ciphermaniac's is confined to `P2T1`.** Three facts fence it into exactly one
cell of the design:

- **Going first, turn 1**: no Supporter may be played at all
  (`docs/01_rules_standard.md` §6), so the card cannot be played.
- **Turn 2, either branch**: the draw step has already happened when the Supporter is
  played, so both stacked cards sit on top of a deck the measured window never draws
  from again. Inside the metric it does literally nothing.
- **`P2T1`**: no evolution is legal on your own first turn (`§5`), absent Salvatore.
  So a Bronzong in hand is dead this turn regardless, and the Supporter slot has no
  better *immediate* conversion — which is exactly what makes spending it on next
  turn's draw defensible here and nowhere else.

Within `P2T1` the choice still depends on the board and the hand, which is what the
single-missing-piece gate encodes. **Stack the missing piece first.** Where the one
gap is C, that means stacking a **Switch** — Ciphermaniac's is the only card in the
deck that can fetch a Trainer, so it is the only route from a want-list entry for
Switch to the card itself. The policy records that Ciphermaniac's fired and what it
stacked, so part 6 can judge the within-cell choice from traces.

## 7. Turn 2 — both branches

By now sub-goals A and D should be done. Turn 2 resolves B and C and attacks.

1. Play free Items first (they may still find what is missing) — but **not** anything
   that shuffles if a Ciphermaniac's stack is pending and undrawn. Every search Item
   in the deck shuffles, so in practice the whole step is skipped.

   > **This rule currently costs and saves nothing — 52.6% with it and 52.6%
   > without** (1,000 replicates, going second, decklist2), and it is worth knowing
   > why before deciding whether to keep it. Ciphermaniac's sits at §6 priority 6
   > and is rarely played, so the rule seldom fires at all. It is also weaker than
   > it reads: the stack is placed on `P2T1`, **turn 2's draw step takes the first
   > of the two cards**, and the second is reachable inside the measured window
   > *only* through a draw effect — Run Errand (§4.5) or Enriching Energy. Absent
   > one of those, the guard protects a card the window can never see, at the cost
   > of a search.
2. Resolve **C** if still open — the §4.3 ladder: free retreat under Latias ex, then
   Switch, then Surfer. If the Active is a Dusclops or a Duskull and none of those is
   available, the Cursed Blast route in §8 is the last door.
3. Resolve **B**: evolve Bronzor → Bronzong from hand, or fetch it with Hilda /
   Salvatore / Brock's Scouting.
4. Resolve **D** if still open: attach a `[P]` source. Remember Enriching Energy is
   **not** one. **If D is already met, attach nothing** — the Bronzong needs one
   `[P]` and the second Energy pays for a search whose fetches fill Bench slots for
   a game the window is about to end (§4.2 step 6).
5. **Play the Supporter if the slot is still unspent** — §6 priority 8. A turn that
   is about to miss is exactly the turn where the slot is otherwise wasted, and a
   turn that is about to hit loses nothing by spending it after every other play.
6. **Run steps 2 to 4 again** on what step 5 drew or fetched. This is the pass that
   makes step 5 worth playing: the eight cards Lillie's draws on turn 2 have no
   later turn to be spent on, so a turn that does not read them has spent the
   Supporter for nothing.
7. **Attack Evolution Jammer.**

**The window closes at the end of turn 2, and nothing past it is recorded** (Kevin,
2026-08-29; ADR 0007). There is no turn 3 in the simulator: no turn-3 play, no turn-3
distribution, no "how many misses would have hit next turn".

If the target event is unreachable this turn, the replicate is a **miss** — but the
policy must still play the turn out properly, because the **end-of-turn-2 board state
is recorded in full** and will be analysed later, so a turn played sloppily once the
metric is lost corrupts that record. The snapshot (`R/trace_claude.R` →
`format_trace()`) captures, as ground truth at the moment the window closes:

| Group | Fields |
|---|---|
| Board | Active and each Benched Pokémon — the full evolution stack, attached Energy, damage, and the turn it was played or evolved |
| Zones | hand, discard, deck size, Stadium in play, Prizes remaining |
| Hidden | prized card identities, labelled **ground truth** — analysis-only, and never readable by the policy (ADR 0003) |
| Turn | Energy attached this turn, Supporter played this turn, whether Items were locked |
| Setup | which Basic led, so the §3 order can be settled from logs |

## 8. Explicit non-goals for turns 1–2

Recorded so the policy is not written to chase them:

- **Do not evolve Dusknoir** with Rare Candy on turn 2 *in preference to* Bronzong.
  Dusknoir is the deck's damage plan, not its lock plan, and the metric measures only
  the lock. **One exception, below.**
- **Do not use Dusclops/Dusknoir's Cursed Blast** for what it is printed to do — 5 or
  13 damage counters is irrelevant to a metric that ends on turn 2. **The self-Knock
  Out is a different matter entirely** — it is an out for sub-goal C, and the escape
  below is where it belongs.

### The Cursed Blast escape — an out for sub-goal C

**Take it whenever the ladder reaches it, on either branch.** A Prize to the opponent
and a Dusclops are a real price, and they are worth paying: the alternative is a turn
that cannot attack at all, and the metric prices a turn-2 miss the same whichever way
the board looked when it happened. It is not reserved for going second, and it is not
a line to take only when it falls in your lap — where the position exists, the escape
is the play.

The mechanism is the self-Knock Out, not the damage. Cursed Blast reads *"If you use
this Ability, this Pokémon is Knocked Out"*, and after a Knock Out **the player whose
Pokémon was Knocked Out chooses which of their Benched Pokémon is promoted**
(`docs/01_rules_standard.md` §7). So Cursed Blast is a switching effect that costs no
Switch, no Supporter slot, no retreat, and no Energy — it costs the Pokémon.

It is the **last** door in the §4.3 ladder, rung 5, taken only when every other rung
is unavailable. Two routes:

- **Dusclops or Dusknoir already Active** — use its own Ability directly. No card
  spent at all.
- **Duskull Active** — **Rare Candy** → Dusknoir, then Cursed Blast. Rare Candy is why
  this route exists: Dusknoir evolves from Dusclops, and Rare Candy is the only way to
  reach it from the Basic in one turn. Costs the Rare Candy and the Dusknoir.

Why the Active gets stuck in the first place: **Skyliner zeroes the retreat cost of
Basics only**. A Duskull Active retreats free under Latias ex, so this route is for
when Latias ex is absent; a **Dusclops** Active is a Stage 1 and retreats for 2 even
with Latias ex in play, which is the case this escape exists for.

Two things that look like traps and are not:

- **Our own Prize count is untouched.** The opponent takes a Prize, from *their* pile.
  Ours still reads 6, so **Lillie's Determination still draws 8** on the same turn.
- **The Bench must not be empty.** With no Pokémon to promote we simply lose, which is
  also why §3's bench-nothing-at-setup rule does not extend past this window.
- **Do not play Boss's Orders.** It only moves the opponent's Pokémon and cannot
  advance any sub-goal.
- **Do not play Special Red Card.** It is unplayable above 3 opposing Prizes.
- **Do not attack with anything other than Evolution Jammer**, except the two cases in
  §4.2, because attacking ends the turn.

## 9. Open questions — the register

Every rule this document states as a **default** rather than a ruling, numbered so
an answer can name what it settles and a scenario can name what it probes.
`docs/03b_scenarios.md` poses many of these as concrete positions instead of
prose; the `S-nn` references point there.

Answer in place — a sentence is enough, and "leave it" is an answer. An entry that
gets answered is **folded into the section it governs and struck from this list**,
so the register always reads as what is still open.

### The goal and the resources (§1–§2)

- **DT-01.** §1 asserts **C is the sub-goal that actually fails**. Over 1,000
  replicates going second the unmet tally is A 82 / B 271 / C 328 / **D 445**, and
  D is the largest. D can only be met once B and C are, so the ordering is not
  clean evidence — but is the claim still the right one to build around, or is the
  real constraint *the turn's single Energy attachment*?

### Setup (§3)

- **DT-03.** Rank the non-Bronzor leads. The current order is a guess, and the
  measured rates on decklist2 going second are Latias ex 65.6%, Kangaskhan 55.8%,
  Budew 53.7%, Duskull 49.4%, Meowth ex 46.2%, Buneary 40.2%, Flutter Mane 35.7%.
- **DT-07.** §3's Budew entry is conditioned on a case this project cannot
  produce. Delete the condition, change the scenario list, or leave Budew ranked
  where it is by default?

### The Supporter (§6)

- **DT-16.** Surfer beats Switch "on a nearly empty hand". How empty? No decklist
  runs Surfer, so this only binds if one does.
- **DT-18.** Is there a Supporter you would play that this table never reaches?
- **DT-24.** The §6 priority 8 fallback plays a Supporter on every turn one is
  legal. Is there a hand where holding one back is right after all — a Lillie's
  on a turn 1 whose hand you would rather keep for turn 2's draw?
- **DT-25.** Priority 2 puts Salvatore ahead of Hilda on turn 2 when a `[P]`
  source is already secured. Is that the right discriminator, or should it be the
  evolution-timing case alone — the only thing Hilda genuinely cannot do?

### Turn 2 and the non-goals (§7–§8)

- **DT-21.** The **pending-stack guard** (§7 step 1) costs nothing and saves
  nothing measurable. Keep it as correct-by-construction, or drop it as a rule
  that only ever forfeits a search?
- **DT-23.** §8 forbids Rare Candy → Dusknoir on turn 2 *in preference to*
  Bronzong. On a turn where Bronzong is provably unreachable, the replicate is
  already a miss — does the board state it leaves behind matter enough to take the
  evolution anyway? Note the Cursed Blast escape (§4.3 rung 5) now takes exactly
  that line when it buys sub-goal C, so this is the residual case where it buys
  nothing.
