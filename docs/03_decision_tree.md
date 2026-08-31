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

**The Supporter slot (one per turn).** Seven Supporters want it: Hilda (fetches
Bronzong + Energy), Salvatore (fetches *and* evolves), Lillie's Determination (draw 8
early), Gwynn (draw up to 6, paid for in spare Pokémon), Brock's Scouting (2 Basics
*or* 1 Evolution), Ciphermaniac's Codebreaking (stack 2 on top), Surfer (switch +
refill). Only one is played. Going first, **none** can be played on turn 1.

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

**The no-Bronzor order below is measured, not asserted** (ADR 0008). It is a
**policy parameter** — `LEAD_ORDER_LIST` in `R/decision_claude.R` — chosen by
varying it and reading the cell rate, and it will move again whenever the policy
learns a play that changes what a lead is worth. Every trace also records **which
Basic actually led**, but that per-lead table is a fact about the policy and is
never the answer to the order: the hand holding a Kangaskhan is not the hand
holding a Duskull, so it compares leads across different hands.

**Read the size before the ranking. The lead order is worth about a point.**
Across every candidate order the going-second rate spans well under two points,
against the twenty-three that came from the Supporter rules. It is worth getting
right and it is not where the deck is won.

**If no Bronzor is in hand**, lead in this order — and, per the rule below, bench
none of the rest:

| | Going second | Going first |
|---|---|---|
| 1 | **Latias ex** | **Mega Kangaskhan ex** |
| 2 | Mega Kangaskhan ex | Duskull |
| 3 | Duskull | Budew |
| 4 | Budew | Buneary |
| 5 | Flutter Mane | Flutter Mane |
| 6 | **Buneary** | Latias ex |

- **Latias ex leads going second.** Skyliner works from the Bench, so leading it
  looks like a waste — but leading it gets the free retreat online on turn 1 with
  no card spent and no Bench slot spent, and turn 1 going second is the turn that
  has the most to do. It costs nothing that a benched Latias ex would have given.
- **Mega Kangaskhan ex** — Run Errand draws 2 from the Active spot, and with Latias
  ex in play it retreats for free afterwards. Best combination of "does something
  now" and "gets out of the way later", and the best lead on the branch where no
  Supporter may be played.
- **Duskull** — 60 HP, retreat 1, free under Skyliner. Harmless, and a `[P]` body a
  Telepathic can be attached to.
- **Budew** — the `item_lock`-from-our-side case this project cannot produce; see
  DT-07. Its rank here is measured like the rest and does not depend on that case.
- **Flutter Mane** — Midnight Fluttering wants the Active spot that Bronzor wants.
- **Buneary is last going second**, which reverses the reasoning that first put it
  second. Its whole case is Run Around, and §4.2 then makes Run Around a **last
  resort** — it spends the turn's Energy attachment and strands the Energy on the
  Bench. A lead whose one virtue the rest of the tree declines to use is not a
  virtue. Going first it cannot attack at all, so the case never existed there.
- **Meowth ex — never lead it**, on either branch and at no rank. Last-Ditch Catch
  triggers only when it is played from hand *onto the Bench*; leading it as the
  Active wastes the Ability outright. This is a ruling, which is why it is absent
  from the table rather than last in it, and why ADR 0008's search does not
  include it as a candidate.

**A Basic the table does not name ranks last, and among those the choice is
arbitrary.** Munkidori and Dunsparce are unranked, and so is Meowth ex — so a
hand holding only unranked Basics leads whichever comes first in hand, which is
an accident of the shuffle rather than a decision. That is tolerable for
Munkidori against Dunsparce and **not** tolerable for Meowth ex, whose exclusion
above is a ruling: it should lose every such tie, not tie. **A default rather
than a ruling** (DT-28).

**The two branches differ only where the evidence differs.** Going second the
search moved two names and the change confirms out of sample twice. Going first
every candidate order lands within a fifth of a point of every other, so the order
stands as it was rather than being replaced by the largest of twenty noisy
numbers.

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

**And the line can be abandoned partway.** The five steps above are entered on the
liveness test, but the free Items in step 1 can make the line dead while it is
running — a search that takes the last Bronzong out of the *deck*, or an Ultra
Ball that discards the Salvatore once its protection lapses with it. At each of
four points — the Bronzor no longer Active, the Salvatore no longer in hand or
the slot spent, no legal Salvatore target, or a Salvatore that resolved without
producing a Bronzong Active — the turn **falls through to §4.2 and is played out
as an ordinary build**, with the Items it has already spent. That is a recovery
path rather than a plan, and it exists because the alternative was a crash.

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
  - with two `[P]` sources and no Enriching, **strand the basic Psychic and keep
    the Telepathic**. Buneary is Colorless, so a Telepathic attached to it fires
    no search and the card is wasted twice over — the `telepathic_on_colorless`
    motif, produced by the very play the motif exists to warn about.
  - **which benched Pokémon it switches into is unstated**, and the ladder is
    taken to promote a **Bronzong** ahead of a bare Bronzor everywhere else
    (§4.3). Run Around currently takes the first member of the line it finds.
    **A default rather than a ruling.**
- **Budew's Itchy Pollen**, if we are the disruption side — same logic, take it last,
  but note Itchy Pollen has **no Energy cost** (`docs/cards/ASC-016-budew.md`), so it
  costs only the turn. None of the Energy reasoning above applies to it.
  **Specified and not implemented**, because we are never the disruption side in
  either modelled scenario — `item_lock` is the opponent's Budew locking us, and
  there is no cell in which it is ours. DT-07 is whether to add one.

Otherwise the turn-1 build order is:

1. Take the free Abilities — see §4.5. Run Errand first of all, since it changes
   the hand every later step reads.
2. Bench **selectively** — see §4.4. Not every Basic in hand.
3. Play free search Items — **Poké Pad** first (no cost), and **every copy of it in
   hand**, since a free search held back is a free search thrown away; then
   **Buddy-Buddy Poffin**, then **Ultra Ball** only if its two-card discard is
   affordable.

   **Poffin and Ultra Ball are played once each, and only Poké Pad repeats.**
   For Ultra Ball that is defensible on cost — a second one is four discarded
   cards. For **Poffin it is not**: it is free, and the Poké Pad reasoning
   applies to it word for word. The asymmetry is **a default rather than a
   ruling** (DT-29), and it binds on decklist7 and decklist8, the only lists
   running two Poffin.
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

   **Which body, when the line has more than one.** Prefer a **`[P]` printing**
   over a Metal one, because the Telepathic's search fires only on a `[P]`
   recipient — the same tie-break the playbook states for choosing between a
   Metal and a `[P]` Bronzor, applied to the board rather than to the hand. It
   binds in decklist7 and decklist8, which pair TEF 68 with the Metal PBL 63.
   **What is still unwritten is the case where one of them already carries the
   `[P]` source** and the other does not — see S-39, which is what that costs.

   **Three exceptions, and between them the attachment is never left idle.**

   - **A second Bronzong carrying nothing takes the spare `[P]` source.** Where the
     Pokémon that will attack is already paid and a *second* Bronzong is in play
     with no Energy on it, the spare goes there: two Bronzong each holding a `[P]`
     source is a second attacker, and the end-of-turn board is what records it.
     This is about a **Bronzong** and never about a Bronzor. A Bronzor with an
     Energy on it is not an attacker, and the Bench slots a Telepathic search would
     fill are worth more than the Energy — which is why an already-paid line with
     only a Bronzor beside it attaches nothing.
   - **With no Bronzor or Bronzong anywhere, a Telepathic goes onto any `[P]`
     body to fire its search.** The two Basics it fetches are sub-goal A's
     cheapest out, and a turn with no line in play has nothing better to spend
     the attachment on. The Energy is stranded on a body that will not attack,
     which is a real cost — and **S-39 is the position where that cost is
     wrong**, because the search is what puts the Bronzor into play, one step
     too late to receive it. **A default rather than a ruling**, and the one
     this bank most wants an answer to. The recipient among several `[P]` bodies
     is the Active first, then Bench order, which nothing chooses on purpose.
   - **Enriching Energy takes an attachment that nothing else can use.** It is
     `[C]`, so it never pays D and never displaces a `[P]` source — but where no
     `[P]` source can be attached at all this turn, the attachment is otherwise
     destroyed, and attaching Enriching draws **4**. Play it **last**, after every
     `[P]` source and after Run Around (the clause above) have had their claim on
     the attachment, and put it on a body that is **not** the attacker — Latias ex
     first, then another `[C]` attacker — since `[C]` on the Bronzong buys nothing
     the metric can spend, while `[C]` on a Latias ex is at least an attack cost
     some later turn could pay.
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

**Promote a Bronzong ahead of a bare Bronzor.** Promoting the Bronzong meets
sub-goal C outright; promoting the Bronzor leaves C unmet and needs an evolution
that may not be available. Among two bare Bronzor the choice is currently
arbitrary, which is the same gap §4.2 step 6 names for the attachment.

**Rung 3 is switched off on the first walk of the turn.** §4.2 step 4 runs the
ladder *before* the Supporter is chosen, and Surfer costs the Supporter slot — so
spending it there would pre-empt a choice §6 has not made yet. Surfer becomes
available again on the later walks, after §6 has had its say. It is also
unavailable inside the §4.1 kill line, where the slot is Salvatore's. **No
decklist runs Surfer**, so none of this is exercised today; it is written down
because §4.3 otherwise reads as five rungs always live.

**4.4 What to bench, and when.** The Bench is a scarce resource (§2), so benching is a
play to be justified, not a reflex. Bench:

The bullets below are also the **order they are evaluated in** — Latias ex, then a
Bronzor, then Meowth ex, then everything else ahead of Lillie's — which matters
only when fewer slots remain than bodies wanting them.

- **Latias ex — always, at the first opportunity, and exactly one.** It is the one
  Basic whose **presence** alone advances a sub-goal, and presence is satisfied by
  the first copy: a second adds nothing and spends the slot §2 calls the fourth
  scarce resource. decklist7 and decklist8 run two. "In play" here means the
  Active spot as well as the Bench — §3 now leads Latias ex going second, so the
  copy already in play is often the Active one.
- **Meowth ex — when a specific Supporter is wanted and is not in hand**, since
  Last-Ditch Catch fetches exactly that (usually **Hilda**). If the Supporter we want
  is already in hand, benching Meowth ex buys a wasted Ability and a spent slot.
  **And *wanted* means playable**: on turn 1 the fetch is for turn 2 and always
  cashes, including going first where no Supporter is legal today but one is
  tomorrow — but on **turn 2 with the Supporter slot already spent**, the fetched
  card can never be played at all, and benching for it trades a Bench slot for a
  card that sits in hand while the turn misses.
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

**A free Item that closes the gap is played before the slot is considered at all.**
The table below chooses *which* Supporter, and it is only ever asked about a gap
the Items have already failed to close. Where a Poké Pad can fetch the Bronzong
for nothing, it fetches the Bronzong, and the Supporter slot then goes to whichever
card is worth more with B already met — which is a different question from the one
it would have answered a moment earlier. This is why the ladder in §4.3 and the
searches in §4.2 step 3 both run ahead of step 5, and it is the reason a hand
holding Salvatore, Hilda **and** a Poké Pad plays the Poké Pad.

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
| nothing directly; adds to the hand, at the price of 2 spare Pokémon | Gwynn |

Evaluate in order and play the first that applies:

| Priority | Play | When |
|---|---|---|
| 1 | **Salvatore** | Turn 1 going second, and the kill is live (§4.1). |
| 2 | **Salvatore, on turn 2** | B is unmet and a `[P]` source is already secured — in hand or attached — so Hilda's second search would add nothing. Salvatore fetches Bronzong **and puts it on the Bronzor**, which also beats Hilda outright when the only Bronzor reached play *this* turn and so cannot be evolved from hand (ADR 0001). |
| 3 | **Hilda** | Bronzong or the `[P]` source is missing, **and she can actually fetch what is missing**. Fetches both in one card; the single most efficient Supporter for sub-goals B and D. Once she is chosen she takes **both** searches whatever the hand holds — see `docs/03a_card_playbook.md`. |
| 4 | **Brock's Scouting** | **Basics mode** when a Bronzor is missing **or sub-goal C is blocked** — Basics mode is the only free way to find Latias ex, and with the line stuck on the Bench that is the missing piece. **Evolution mode** for Bronzong when B is unmet and **Hilda is gone** — neither in hand nor believed to be in the deck — since while Hilda is reachable the slot is worth more to her, who fetches the Bronzong *and* an Energy. |
| 5 | **Surfer** | Bronzor is benched and the §4.3 ladder has got that far — no free retreat, no Switch, no Salvatore line this turn. Solves C and refills. Play last in the turn so the refill is large; on a nearly empty hand it can be the better card even against a Switch. |
| 6 | **Ciphermaniac's Codebreaking** | **`P2T1` only** — going second, on our first turn — **sub-goal A must be met**, and only when **exactly one** of B, C and D is missing, since it delivers exactly one card into turn 2's draw. Two missing pieces are one more than it can fix. |
| 7 | **The draw Supporters — Gwynn, then Lillie's Determination** | Nothing above applies and the hand needs replacing. **Gwynn** discards up to 2 Pokémon without a Rule Box and draws 3 for each, so it **keeps the hand**; it is worth the slot only when a spare Pokémon exists to pay with, since discarding nothing draws nothing. **Lillie's** shuffles the hand into the deck and draws **8** while *we* still hold 6 Prizes, on a hand of **four cards or fewer**. Gwynn goes first exactly when Lillie's would bury a piece the turn still needs — a Bronzong, a `[P]` source, or the Switch that answers an open sub-goal C; otherwise Lillie's, which draws more. **Play everything else first** and **bench the Pokémon you want to keep before Lillie's** (§4.4). The four-card gate and the Gwynn discriminator are both defaults rather than rulings (DT-27). |
| 8 | **The fallback: never end a turn with the slot unspent.** | Nothing above fired, and a Supporter in hand is legal and would change the board or the hand at all. Play it. Order: the draw Supporters, then a Hilda who can still fetch *one* of her two targets, then Brock's, then Salvatore, then Ciphermaniac's. |

**Why the draw Supporters sit at 7 rather than at 5, which is where they read as
belonging.** Both replace cards; neither solves a named sub-goal. So the only
question is what they are competing with, and at `P2T1` that is
**Ciphermaniac's** — which is a *tutor* for the one card the turn is missing,
against Lillie's *eight random cards out of forty*. A tutor beats a lottery when
the target is one named card, and the difference is not small: moving the draw
Supporters ahead of Ciphermaniac's costs **1.92 points, with a standard error of
0.22** (4,000 paired replicates, decklist2, going second). Ciphermaniac's own
paragraph below already said this — *"it is not the answer to a hand missing three
things; there Lillie's, which replaces the whole hand, is"* — and the ranking now
says it too.

**Priority 8 is the rule that makes the rest of the table safe.** One Supporter may
be played per turn and an unplayed one carries no credit into the next; a slot left
idle is a resource destroyed, not saved. So the thresholds above — Hilda's "can fetch
something", Lillie's four-card hand, Gwynn's spare Pokémon, Ciphermaniac's single
missing piece — are about *which* Supporter to prefer, never about whether to play
one. If a Supporter would improve the position even slightly, it is played.

**Gwynn is the one card in the table where "play it anyway" has a floor.** Its text
reads *up to* 2, and discarding nothing draws nothing, so a Gwynn played on a hand
with no spare Pokémon spends the slot for zero cards. That is not the fallback being
generous; it is the fallback being wasted, so the fallback declines it and moves on.

**In the fallback the two draw Supporters swap places.** Priority 7 puts Gwynn
first, because there it is protecting a piece Lillie's would bury; by the time the
fallback runs, every play the turn meant to make has already been made and there
is nothing left to bury — so **Lillie's larger draw wins**, and Gwynn is the
second choice. Priority 7's own test runs first regardless, so a hand that still
holds a piece is still answered there. **A default rather than a ruling**, and the
other half of DT-27.

**A fallback Brock's Scouting has no mode rule.** Priority 4's two conditions have
by definition failed, so neither mode is *indicated* — and Basics mode is taken
whenever it has any legal target at all, which on a late turn is usually filler.
**A default rather than a ruling** (DT-31).

**Including on a turn that is already won.** With the evolution, the attachment and
the attack all secured, the slot still gets spent before the attack ends the turn:
eight fresh cards are a better record of where the game stood than a hand nobody
touched, and holding the Supporter back saves nothing, since the window closes at
the end of turn 2 (ADR 0007) and there is no later turn to carry it to. Lillie's is
played *before* attacking and *after* everything the turn still meant to do, which
is the same ordering priority 8 always uses.

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
a play the turn was always allowed to make, and each is still capped by the rules
rather than by the number of passes — **one attachment and one retreat per turn**.

**Evolution is not one of those caps, and this paragraph used to say it was.** The
rules cap evolution *per Pokémon*, not per turn: a turn may evolve a Bronzor in
the first pass and a second Bronzor in the second. That is not an accident to be
tidied away — §4.2 step 6's second-Bronzong exception presumes exactly two
Bronzong can exist on the same turn, and S-18 is the position where you asked for
them.

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

**What "missing" means here**, since the gate turns entirely on it: **B** is met
by a Bronzong in play *or in hand*; **D** by a `[P]` source in hand *or already
attached to the line*; and **C** by the line being Active, a free retreat, or a
playable Switch in hand — the §4.3 ladder's *free* rungs only. Surfer and Run
Around are deliberately excluded from that count even though §4.3 lists them as
rungs: both cost a resource the gate is trying to protect, so treating them as
"C is covered" would spend the stack on a gap that is not really closed.

**And sub-goal A must be met**, which the gate above now states. It is not
redundant: A unmet means no Bronzor in play, which forces C into the missing set,
so the "exactly one" test can be satisfied with C alone — and the stack would then
fetch a **Switch with nothing to switch to**. Declining is right; whether it would
be better still to stack the *Bronzor* is **a default rather than a ruling**
(DT-30).

**Two cards are stacked, and the second one is unstated.** The gaps go first, in
B / C / D order; the remaining two categories fill the second slot in the same
order. That second card is reached by turn 2's draw step only through a draw
effect, so it rarely matters — but it is chosen by an ordering nobody argued for.
The `P2T1` and single-gap gates also do **not** apply when Ciphermaniac's is
reached through the priority 8 fallback, where §6 says only "then Ciphermaniac's".

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
   **not** one. **If D is already met the attacker gets nothing more** — the
   Bronzong needs one `[P]` and a second Energy on the same body pays only for a
   search whose fetches fill Bench slots for a game the window is about to end. The
   two things the spare attachment *does* go to are in **§4.2 step 6**: a second
   Bronzong holding no Energy, and — once no `[P]` source can be attached at all —
   Enriching Energy on a body that is not the attacker.
5. **Play the Supporter if the slot is still unspent** — §6 priority 8. A turn that
   is about to miss is exactly the turn where the slot is otherwise wasted, and a
   turn that is about to hit loses nothing by spending it after every other play.
6. **Run steps 2 to 4 again** on what step 5 drew or fetched — and **benching
   again with them**, since a Basic among those cards is as placeable as one that
   was already in hand. This is the pass that makes step 5 worth playing: the
   eight cards Lillie's draws on turn 2 have no later turn to be spent on, so a
   turn that does not read them has spent the Supporter for nothing.
7. **Attack Evolution Jammer.**

**Two things about this list are truer of the intent than of the order.**

**Within a pass, B is resolved before C.** Steps 2 and 3 are numbered
positioning-then-evolution, and the turn actually evolves first and then
positions. The reason is concrete: a Bronzong made on the *Bench* and then left
there, with a Switch still in hand, is a decision defect the traces used to
report — positioning after the evolution promotes it in the same pass. The
numbering is kept as it stands because C really is the sub-goal the turn is built
around; the pass order is what the code follows. **A default rather than a
ruling** (DT-32), and the one place in this document where the step numbers are
not the play order.

**Step 5 is played before the first pass of steps 2 to 4, not after it.** The
Supporter is what *fetches* the pieces those steps need, so a turn that assembled
first and asked for help afterwards would attach and evolve with a hand it had
not finished improving. §4.2's build order — searches, ladder, Supporter, then
attachment — is what the turn follows on both branches. So the shape is really
*search → position → Supporter → assemble → assemble again*, and steps 2 to 4
appear twice for that reason rather than once at step 5's expense.

**Then, before the priority 8 fallback**, the Stadium (§4.2 step 7) and §8's
leftover Rare Candy are played — because §6 priority 8 says the fallback fires
after every other play, and a fallback Lillie's shuffles into the deck any card
those two still wanted. §4.4's bench-before-Lillie's rule cannot save the
Dusknoir §8 needs: it is a Stage 2, and only Basics can be benched. Pokégear,
Run Around and the Enriching Energy follow the fallback, in that order, each for
a reason its own section gives.

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
  the lock.

  **But once Bronzong is settled either way, the Rare Candy is played.** *Settled*
  means the evolution has happened, or the turn has established that it cannot: the
  Bronzong is on the Bronzor, or no Bronzong is reachable this turn at all. At that
  point the Rare Candy and the Dusknoir are two cards with nothing left to compete
  with, and a **benched Duskull** becomes a Dusknoir before the attack. The metric
  does not move — the turn was already won or already lost — but the end-of-turn
  board is recorded in full (ADR 0007) and a Dusknoir on it is worth more than a
  Rare Candy in hand. The order is what the non-goal is really about: Bronzong
  first, always; Dusknoir with what is left over. **Never onto the Active**, whose
  only job on turn 2 is to be the Bronzong, and **turn 2 only** — on turn 1 the
  Rare Candy and the Dusknoir are exactly the pair the §4.3 rung-5 escape needs,
  and spending them a turn early is how a turn-2 Duskull Active ends up with no
  door.
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

**The Dusknoir is searched for, not waited for.** Where this escape is the *only*
route to sub-goal C — a Duskull Active, a Rare Candy in hand, the line stranded on
the Bench, and no free retreat, no Switch and no Latias ex — **Dusknoir goes to the
front of the want-list**, exactly the way Latias ex does when C is blocked and the
escape is not available. Dusknoir is an Evolution Pokémon, so **Hilda fetches it**,
and so do Poké Pad, Ultra Ball and Brock's Scouting in Evolution mode. The
promotion is conditioned on **B already being secured** — a Bronzong in hand or in
play. With both B and C open, one search cannot close both, and the Bronzong is the
piece with no other route this turn.

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
  replicates going second the unmet tally is A 51 / B 153 / C 177 / **D 221**, and
  D is the largest. D can only be met once B and C are, so the ordering is not
  clean evidence — but is the claim still the right one to build around, or is the
  real constraint *the turn's single Energy attachment*? The shape is stable: the
  rate has moved more than twenty points without C and D changing places.

### Setup (§3)

- **DT-28.** A Basic §3's table does not name ranks last, and among several
  unranked Basics the lead is decided by hand order. Munkidori against Dunsparce
  is a genuine coin-flip; **Meowth ex is not**, since §3 rules it out entirely
  and it should lose every such tie rather than tie. Give the unranked bodies an
  order, or state that Meowth ex ranks below them?

- **DT-07.** §3's Budew entry was conditioned on the `item_lock`-from-our-side
  case, which this project cannot produce: `item_lock` models the *opponent's*
  Budew locking us, and we are never the disruption side (`CLAUDE.md` →
  *Scenarios*). The condition is gone and Budew now ranks on the same measured
  evidence as everything else — but the underlying question stands: should the
  scenario list gain a cell in which **we** are the disruption side, which would
  also make §4.2's Itchy Pollen exception mean something?

### Turn 1 (§4)

- **DT-29.** §4.2 step 3 plays **every** Poké Pad and **one** Buddy-Buddy Poffin.
  For Ultra Ball a cap of one is defensible on cost; for Poffin, which is free,
  the Poké Pad reasoning applies word for word. Should Poffin repeat too? It
  binds only on decklist7 and decklist8.
- **DT-32.** §7 numbers positioning at step 2 and the evolution at step 3, and
  the turn does them the other way round within each pass — a Bronzong made on
  the Bench and left there is a defect the traces used to report. Renumber the
  steps to match, or keep the numbering as a statement about which sub-goal the
  turn is built around?

### The Supporter (§6)

- **DT-30.** §6 priority 6 declines Ciphermaniac's when sub-goal **A** is unmet,
  because the stack would otherwise fetch a Switch with nothing to switch to.
  Declining is clearly better than that — but would stacking the **Bronzor** be
  better still, and turn the card into an out for A?
- **DT-31.** A **Brock's Scouting reached through the priority 8 fallback** has
  no mode rule: priority 4's two conditions have failed by definition, and Basics
  mode is taken whenever it has any legal target, which late in a turn is filler.
  Which mode should a fallback Brock's use? No decklist runs it today.

- **DT-16.** Surfer beats Switch "on a nearly empty hand". How empty? No decklist
  runs Surfer, so this only binds if one does.
- **DT-18.** Is there a Supporter you would play that this table never reaches?
- **DT-25.** Priority 2 puts Salvatore ahead of Hilda on turn 2 when a `[P]`
  source is already secured. **Narrowed:** where a free Item can close B the
  question does not arise, because the Item closes it and the slot moves on. What
  is still open is the residual — B unmet, a `[P]` source secured, **and no Item
  that can fetch the Bronzong**. Is `[P]`-secured the right discriminator there,
  or should it be the evolution-timing case alone, the only thing Hilda genuinely
  cannot do?
- **DT-27.** §6 priority 7 holds two draw Supporters and picks between them on
  one question: **would Lillie's bury a piece the turn still needs?** If so
  Gwynn, which keeps the hand; otherwise Lillie's, which draws more. No decklist
  ran a Gwynn before decklist7, so this has never been put to you as a position.
  Two sub-questions inside it: is *bury* the right discriminator, and which
  Pokémon count as spare enough to feed it — the Ultra Ball never-discard list
  is what the code currently reuses.
- **DT-26.** On a turn that is **already won**, the priority 8 fallback ranks
  Salvatore ahead of Ciphermaniac's, so a spare Salvatore puts a second Bronzong
  onto a benched Bronzor. Ciphermaniac's would stack two cards the window can
  never draw, so the order looks right on the board it leaves — but the choice is
  a default and the two cards are worth arguing about on a turn where nothing is
  at stake.

### Turn 2 and the non-goals (§7–§8)

- **DT-21.** The **pending-stack guard** (§7 step 1) costs nothing and saves
  nothing measurable. Keep it as correct-by-construction, or drop it as a rule
  that only ever forfeits a search?
- **DT-23.** §8 plays Rare Candy → Dusknoir once Bronzong is **settled either
  way**. The won-turn half is a ruling. The **lost**-turn half — Bronzong provably
  unreachable, the replicate already a miss — is written into §8 as a proposal
  and is not yet yours: does the board it leaves behind justify the evolution when
  nothing at all is at stake, or should a lost turn simply stop?
