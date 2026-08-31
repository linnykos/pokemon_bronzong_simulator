# Part 3a — Card Playbook

**Status: this file is the specification, and the R follows it.** Kevin edits here;
the code is realigned afterwards, never the other way round (`CLAUDE.md` → *The
decision documents are the specification*). Per-card rules: what each card does in
the simulator, and what it should be aimed at. Companion to
`docs/03_decision_tree.md`, which gives the shape of the turn.

**Present tense only.** A rule written as a **default** rather than a ruling says so
in place and carries a `PB-nn` entry in the register at the bottom. How a rule came
to read the way it does is not here — that is `HISTORY_kevin.md`, or an ADR this
file cites by number.

Cards are grouped by the role they play. Anything not listed is inert for turns 1–2 and
needs no effect function beyond "is playable, does nothing to our sub-goals".

---

## Search priority — the one list

Almost every search card asks the same question: *what am I missing?* Rather than
repeat it per card, every search resolves against this ordered want-list, taking the
highest-priority item the card is legally able to fetch.

1. **Bronzor** — if none in play and none in hand (sub-goal A)
2. **A `[P]` source** — if none in hand and none attached (sub-goal D)
3. **Bronzong** — if none in hand and none in play (sub-goal B)
4. **Latias ex** — if not in play and Bronzor is not Active (sub-goal C)
5. **Switch** — if Bronzor is not Active and Latias ex is not in play (sub-goal C)
6. **Meowth ex** — if a Supporter is still wanted and Meowth ex is unplayed, and
   **only for a search that puts cards in hand**
7. **Duskull** — filler, and a legal Poffin/Telepathic target

**Item 4 moves to the front when sub-goal C is blocked**, and *blocked* is
prospective: the line is in play **or in hand**, it will sit on the Bench, and
neither a free retreat nor a Switch can move it. Reading it as "already benched"
is a turn too late — by the time the Bronzor has been played the searches that
could have found the mover are spent, and the position is unsalvageable. Latias ex
stops being a nice-to-have and becomes the missing piece, and only Ultra Ball and
Brock's Scouting can fetch it. That is also why Poké Pad ends up being the card
that finds Bronzong: it cannot fetch a Rule Box.

**And a `0` sits above item 1 when the Cursed Blast escape is the only route to C:
Dusknoir.** The condition is narrow and every clause of it matters — a **Duskull**
Active, a **Rare Candy** in hand, a Bronzor or Bronzong on the Bench, no free
retreat, no Switch, no Latias ex, no Dusknoir already in hand, and **B already
secured**. With all of that true the escape is the turn's only door and a Dusknoir
is the only thing that opens it, so it outranks even the Bronzor. With B *not*
secured the promotion does not apply: one search cannot close both gaps, and B has
no other route this turn either. Dusknoir is an Evolution Pokémon, so Poké Pad,
Ultra Ball, Hilda and Brock's Scouting in Evolution mode can all take it.

The rule for every search card is: *walk this list, skip anything this card cannot
legally fetch, take the first hit*. A search that finds nothing is a **whiff**, and the
whiff updates the belief state (ADR 0003) — the searched cards are now known.

**Two things the list does not chase, and why.**

- **A second Bronzor as insurance.** Insurance against a Knock Out that cannot
  happen inside this window — nothing either scenario does deals enough damage.
  **This is a rule about the card, not about the printing**: a list running two
  printings offers the multi-target cards one entry each, and Brock's, Poffin and
  Telepathic will take one of *each* unless the rule is enforced by name. It went
  unnoticed for as long as every list ran a single printing.
  It cost **1.4 percentage points** where it sat on the list (53.9% → 52.6%,
  1,000 replicates going second on decklist2), almost entirely through the
  hand-fetching cards spending themselves on it once the useful targets had
  whiffed, and it wastes the one attachment and the last Bench slot on the turns
  where it fires.
- **Meowth ex, for a search that benches.** Poffin and Telepathic put Basics **on
  the Bench**, not in hand, and **Meowth ex fetched onto the Bench never triggers
  Last-Ditch Catch** — the Ability fires only when it is played from hand. A
  search that "finds" Meowth ex that way spends a Bench slot and gets nothing, so
  item 6 applies only to Poké Pad, Ultra Ball and Brock's Scouting.

Each card may still want its own **stopping point** rather than only its own
legality filter — Poké Pad is free and can afford to reach item 7, Ultra Ball
costs two discarded cards. That is PB-01, still open.

---

## Search cards

**Poké Pad** (Item) — free, finds one Pokémon **without a Rule Box**.
Eligible: Bronzor (all printings), Bronzong, Duskull, Dusclops, Dusknoir, Buneary,
Flutter Mane, Budew. **Cannot** find Latias ex, Meowth ex, Mega Lopunny ex, Mega
Kangaskhan ex. Play early and freely; it has no cost. Shuffles.

**Every copy in hand is played, not just the first.** It costs nothing, so there is
no reason to stop at one: the first finds the Bronzor, the second finds the
Bronzong, and each resolves against the want-list as it stands *after* the one
before it. A copy held back is a free search thrown away, and the window has no
later turn to spend it on. Stop only when the want-list has nothing left the card
can legally fetch and still believes findable.

**Ultra Ball** (Item) — finds **any** Pokémon; requires discarding 2 other cards from
hand first. Play it only when the discard is affordable. **Discard priority** (first
listed goes first):
**Blissey ex** → Special Red Card → Boss's Orders → **Night Stretcher** →
**Ciphermaniac's Codebreaking, when it is not this turn's Supporter** → **Risky
Ruins** → **basic Darkness Energy** → surplus Duskull beyond 1 → Dusclops →
Dusknoir → surplus Rare Candy → the other Stadiums → Flutter Mane → **Munkidori**
→ **Dunsparce** → **Dudunsparce** → surplus Bronzong beyond 1.

The five entries new since decklist7 and decklist8 all rank on the same test —
*how reliably can this window convert the card?* **Blissey ex goes first of
everything** because it cannot be put into play at all in either list that runs
it. **Risky Ruins** and **basic Darkness Energy** rank above the Duskull line
because the first is a Stadium §4.2 step 7 always declines and the second cannot
pay sub-goal D. **Munkidori, Dunsparce and Dudunsparce** are bodies with nothing
to do in two turns. Among the Stadiums the order is Nighttime Mine → Jamming
Tower → Festival Grounds → Mystery Garden, which nothing chooses on purpose —
none of the four advances a sub-goal.

**Everything unlisted ties at the bottom and is spent in hand order.** That
includes every Supporter, every Item, every Energy, Mega Lopunny ex, and a
surplus Bronzor once a Salvatore has released it. A spare Poké Pad and a spare
Bronzor are genuinely different cards and the order between them is a coin-flip.
**A default rather than a ruling** (PB-19).

Night Stretcher and a Ciphermaniac's that will not be played rank above Rare Candy,
a Stadium and Dusknoir because they are the cards this window most reliably cannot
convert: Night Stretcher recovers from a discard that has barely started, and
Ciphermaniac's is legal in exactly one cell (`P2T1`) and dead everywhere else.

**Night Stretcher is spent freely only while nothing needs it.** The moment this
Ultra Ball is reaching for a surplus **Bronzong**, one Night Stretcher stops being
third on the order and becomes protected instead, because it is the card that turns
that Bronzong from lost into set aside. A discard that spends both is the one
ordering the list must never produce.

**Never discard:** the only `[P]` source, the only Switch when Bronzor is benched,
Salvatore on a live turn-1 kill, or **the Supporter §6 has chosen for this turn**.
That last one is the general form of the Salvatore clause: a Supporter about to be
played is not spare, and discarding it trades the whole Supporter slot for one
search.

**The line is protected by name, not by count.** *Every* Bronzor and *every*
Bronzong in hand is off the table, surplus copies included, and each is released
only by the card that undoes the discard:

- a **Bronzong** becomes discardable when a **Night Stretcher** is in hand and will
  itself survive this discard — that is what makes it a card put aside rather than
  a card lost, and it is the price worth paying to reach a Latias ex that unblocks
  sub-goal C. Night Stretcher outranks Bronzong on the order above, so protecting
  one copy of it is part of releasing the Bronzong, not separate from it;
- a **Bronzor** becomes discardable when **Salvatore** is in hand. Without
  Salvatore a fresh Bronzor cannot be evolved on the turn it is played (ADR 0001),
  so discarding one does not cost a card, it costs a turn — and the window is two
  turns long.

**A release is not a licence to spend the last one.** Either card, once released,
drops back to the ordinary protection — the last copy is kept and only the surplus
goes. So a Salvatore with two Bronzor in hand makes one of them spendable, not
both, and the same for a Night Stretcher with two Bronzong.

**And the two "surplus … beyond 1" entries on the order above are keep rules, not
just ranks.** One **Duskull** and one **Rare Candy** are protected outright: they
are the two halves of the §4.3 rung-5 escape, and decklist7 and decklist8 run
**one** Rare Candy, so a single Ultra Ball could otherwise close that door for the
whole game. Gwynn honours the same protections, since two lists answering "which
cards are spare" would disagree and the disagreement would be silent.

**"The only `[P]` source" is about the source, not about each printing.** A hand
holding one Telepathic and one basic Psychic protects **one** of them — the
Telepathic, because it also searches. Protecting both was over-protection that
could push the discardable count below 2 and make Ultra Ball unplayable outright,
which is the exact failure the clause below describes.

If fewer than 2 discardable cards remain by that rule, Ultra Ball is unplayable.
Shuffles. **It is the only Item that finds Latias ex.**

**The never-discard list is worth 5 percentage points** — 47.6% without it against
52.6% with, 1,000 replicates going second on decklist2. Whatever happens to the
*order* above, that protection is doing real work and should not be relaxed
casually.

**Buddy-Buddy Poffin** (Item) — free, puts up to **2 Basic Pokémon with 70 HP or less**
directly onto the **Bench**. Eligible in these lists: Bronzor PRE 66 (70), Bronzor SSP
126 (60), Duskull (60), Buneary (70), Budew (30). **Not eligible: Bronzor TEF 68
(80 HP)** — this is the whole reason the Metal printings are candidates. Bench only;
never reaches the Active spot. Shuffles.

**Brock's Scouting** (Supporter) — **either** up to 2 Basics **or** exactly 1
Evolution, never a mix. Puts them in **hand**, not on the Bench.
Mode rule: **Basics mode** to find a Bronzor or the Latias ex that unblocks
sub-goal C, **Evolution mode** for a Bronzong and only when Hilda is unavailable —
which in practice means Basics on turn 1 and Evolution on turn 2, though **neither
mode is pinned to a turn number**. §6 priority 4 states the same rule as two board
conditions rather than as two turns, and those conditions are what decides.
**Missing a Bronzor** means the want-list's sense of missing — none in play *and*
none in hand — not merely none in play. It is the only *free*
way to find Latias ex. Shuffles.

**Hilda** (Supporter) — one **Evolution Pokémon** *and* one **Energy card**, both to
hand. Targets: Bronzong + a `[P]` source. Solves sub-goals B and D with one card,
which makes it the default turn-2 Supporter. Shuffles.

**Once she is played, she takes both searches, whatever the hand already holds.**
The two searches are independent and declining one gains nothing — no card is
saved, no shuffle avoided, and the slot is spent either way. So a second Bronzong
and a second Energy are taken when the first are already in hand, and **the Energy
search takes *any* Energy card** when no `[P]` source is findable, since her text
is not restricted to `[P]`. A whiff on the Energy search therefore means something
sharp: every Energy in the list is prized or discarded. Whether she is worth
*playing* is §6's question and unchanged by this — what a played Hilda fetches is
this file's.

**Her evolution search is aimed at a Dusknoir rather than a Bronzong when the
Cursed Blast escape is the only route to sub-goal C** — a Duskull Active, a Rare
Candy in hand, the line stranded on the Bench, no free retreat, no Switch, no
Latias ex, and **B already secured** (`docs/03_decision_tree.md` §8). She is the
only Supporter that reaches the piece that escape needs. With B *not* secured the
Bronzong keeps the search: one evolution cannot close two gaps, and the Bronzong is
the gap with no other route this turn.

**Salvatore** (Supporter) — searches for a card with **no Abilities** that evolves from
one of our Pokémon and **puts it onto that Pokémon**, bypassing both evolution timing
restrictions (ADR 0001). Legal targets here: **Bronzong** and **Mega Lopunny ex** only
— Dusclops and Dusknoir have Cursed Blast and are excluded. Requires a legal target to
exist in the deck; if all Bronzong are prized or discarded it is **unplayable**, and
that fact is information. Shuffles.

**Its turn-1 exemption is not the only thing it is for.** On turn 1 going second it
is the whole kill line (`docs/03_decision_tree.md` §4.1). On **turn 2** it is still
one card that fetches Bronzong *and* puts it on the Bronzor, and it beats Hilda in
two positions: when a `[P]` source is already secured, so Hilda's second search
would add nothing; and when **the only Bronzor reached play this turn**, where a
Bronzong in hand cannot legally be used and Salvatore's bypass is the only route to
B at all. Behind Hilda otherwise, since she solves D as well.

**Pokégear 3.0** (Item) — looks at the **top 7**, may take one Supporter, shuffles the
rest back. Not a tutor: it can whiff, and the hit probability depends on how many
Supporters remain. Its value is concentrated on **turn 1 going first**, the only turn
where a Supporter cannot otherwise be played but can be *found* for next turn.
**Never play it while a Ciphermaniac's stack is pending** — the shuffle destroys it.
It digs for **Hilda, then Salvatore, then Brock's Scouting, then Lillie's**, and it
is declined outright when all four are already in hand; Gwynn, Ciphermaniac's and
Surfer are not on that list at all. **A default rather than a ruling**, and
unexercised — no decklist runs Pokégear.

**Ciphermaniac's Codebreaking** (Supporter) — searches 2 cards and puts them **on top
of the deck**, in a chosen order. Turn 2 draws exactly **one** of them. Stack the more
urgent card on top. **Playable in exactly one cell: `P2T1`** — going second, on our
own first turn. Going first no Supporter is legal on turn 1, and on turn 2 the draw
step has already passed, so the stack is never reached inside the window
(`docs/03_decision_tree.md` §6).

**Because turn 2 draws one card, it is worth the slot only when one card finishes
the job** — exactly one of B, C and D missing. It is not the answer to a hand
missing three things; there Lillie's, which replaces the whole hand, is. Where the
one gap is **C**, stack a **Switch**: Ciphermaniac's searches Trainers, which
nothing else in the deck does, so it is the only card that can turn want-list item
5 into the card itself. **Sets a `pending_stack` flag on the belief state**, and every shuffling **Item**
checks it — in practice Poké Pad, Buddy-Buddy Poffin, Ultra Ball and Pokégear
3.0, which is the whole of §7 step 1. Shuffles the deck *before* placing, so the
stack survives only until the next shuffle.

**The Supporters are deliberately not guarded, and this is the narrower rule it
used to be.** Hilda, Salvatore, Brock's, Lillie's, another Ciphermaniac's and
Meowth ex's Last-Ditch Catch all shuffle, and guarding them would mean **playing
no Supporter at all on turn 2** whenever a `P2T1` Ciphermaniac's had fired —
against §6 priority 8, which is the largest single rule in this document. What
the guard would protect there is only ever the **second** stacked card: turn 2's
draw step has already taken the first, and the second is reachable inside the
window only through a draw effect. Trading a Supporter for it is not close.
Whether the guard is worth keeping even on the Items is **DT-21**, still open —
§7 step 1 measures it at nothing either way.

## Draw cards

**Lillie's Determination** (Supporter) — shuffle hand into deck, draw 6; **draw 8 while
holding exactly 6 Prizes**, which is always true on turns 1–2 (and stays true even
after a Cursed Blast self-Knock Out, which costs the *opponent's* Prize pile, not
ours). Because it puts the current hand into the deck, the policy must make every other
play it intends **first** — and that includes **benching the Pokémon it wants to
keep**, which is the one situation where filling the Bench is right
(`docs/03_decision_tree.md` §4.4).

**Gwynn** (Supporter) — discard **up to 2** Pokémon **without a Rule Box** from hand,
draw **3 for each one discarded**. The only draw Supporter that **keeps the hand**,
and the only one that does **not shuffle**.

**"Up to 2" is literal and the empty discard is legal**, so a Gwynn played on a hand
holding no spare Pokémon spends the Supporter slot for zero cards. That is the one
place in §6 where the priority-8 fallback has a floor: with nothing spare to pay
with, Gwynn is declined and the fallback moves on.

**Which Pokémon are spare is the Ultra Ball never-discard list, unchanged.** The
line is protected by name — every Bronzor and every Bronzong — and released only by
the card that undoes the discard, a Salvatore for the Bronzor and a Night Stretcher
for the Bronzong. Among what is left, the order is the Ultra Ball discard order.
Reusing that list rather than writing a second one is deliberate: two lists that
answer "which cards are spare" will disagree, and the disagreement will be silent.

Latias ex, Meowth ex, Mega Lopunny ex, Mega Kangaskhan ex and Blissey ex all carry
Rule Boxes, so Gwynn cannot discard them however spare they look.

**Mega Kangaskhan ex — Run Errand** (Ability) — draw 2, once per turn, **only while
Active**. Free and repeatable across turns; take it whenever Kangaskhan is Active and
the draw is not actively unwanted. Conflicts with Bronzor for the Active spot.

**Enriching Energy** (Special Energy) — draw 4 on attach. Provides `[C]` and **is not a
`[P]` source**. Attaching it consumes the turn's one Energy attachment, which is the
resource sub-goal D needs, so it never displaces a `[P]` source on either turn.

**It takes the attachment nothing else can use.** On a turn where no `[P]` source
can be attached at all — none in hand, and none any remaining play can reach — the
attachment is destroyed at end of turn whatever happens, and attaching Enriching
converts it into **4 cards**. So it is played **last**: after every `[P]` source
has had its claim, after Run Around has had its claim (`docs/03_decision_tree.md`
§4.2 pays Run Around with Enriching by preference), and after the Supporter, whose
fetch could still turn up the `[P]` source that outranks it.

**Put it on a body that is not the attacker** — **Latias ex** first, then another
`[C]` attacker, and only then anything else. `[C]` on the Bronzong buys nothing
Evolution Jammer can spend, whereas `[C]` on a Latias ex is an attack cost some
turn past the window could actually pay. The draw is the point; the recipient is
chosen so the card is not merely parked.

**In practice the trigger is wider than "no `[P]` source can be attached".** It
fires whenever the attachment is still unspent when the turn reaches this point,
which also covers the case where a `[P]` source *is* in hand and legal but has
nowhere worth going — sub-goal D already paid, and no second empty Bronzong to
take it (§4.2 step 6). The intent is the same in both: an attachment nobody has
claimed is destroyed at end of turn, and four cards beat nothing.

**Meowth ex — Last-Ditch Catch** (Ability) — on being **played from hand onto the
Bench**, search the deck for a **Supporter**. Does **not** trigger from a setup
placement or from being placed as the Active. Shuffles. **Bench it only when the
Supporter we want is absent from hand** — with Hilda already held it spends a Bench
slot to fetch nothing worth having.

**Target: Hilda, then Lillie's Determination. Salvatore only under a narrow
condition** — `P2T1`, sub-goal C already solved or solvable for free, **and** a
`[P]` source already **secured**, meaning in hand *or* already attached to the
line. Under that condition Salvatore is fetched **ahead of Hilda**, and Lillie's
drops out of the list: with D already paid, Hilda's second search adds nothing and
Salvatore's evolution bypass is the only thing either card can do that the other
cannot. **A default rather than a ruling** in both respects — the ordering and the
"secured" reading of "in hand". Salvatore fetched into any weaker position is a card
that cannot be cashed: it fixes B alone, and a turn missing the Energy or the
positioning still misses. Hilda fixes B *and* D, and Lillie's replaces the hand, so
both convert in far more of the states Meowth ex is benched from. Fetching
Salvatore on a hand that has neither the Energy nor a mover is the single most
common way a `P2T1` Meowth ex is wasted.

## Positioning cards

**Switch** (Item) — swap Active with a Benched Pokémon, free, no retreat used, no
Supporter slot. **The preferred answer to sub-goal C when the retreat is not already
free** — but it is still a card, so do not spend it while Latias ex is in play and the
Active is a Basic, where the retreat does the same job for nothing. Second rung of the
ladder in `docs/03_decision_tree.md` §4.3.

**Surfer** (Supporter) — switch, then **draw until the hand holds 5**. The draw is
`max(0, 5 - hand_size)` computed **after** the switch and after Surfer has left the
hand; with a full hand it draws nothing. Costs the Supporter slot, so it loses to
Switch whenever both are available and a Supporter is wanted for anything else —
**except on a nearly empty hand**, where the refill is large enough that it can be the
better card outright. **No decklist runs it** — it is a candidate
only, so Switch is the operative answer to sub-goal C in every list that exists today.

**Latias ex — Skyliner** (Ability) — passive, works from the Bench, live the moment
Latias ex is in play: **your Basic Pokémon have no Retreat Cost**. Makes the retreat
into Bronzor free whenever the Active is a Basic, which on turn 1 it almost always is.
**The first rung of the §4.3 ladder, ahead of Switch**: the retreat is free and
otherwise unspent, so using a Switch instead throws a card away. **Bench Latias ex at
the first opportunity** — it is the only Basic whose presence alone advances a
sub-goal.

Note it does **not** cover Stage 1s. That is fine for a Bronzong we want to keep
Active, and it is exactly why a **Dusclops** Active gets stuck with a retreat cost of
2 — the case the Cursed Blast escape exists for.

**Buneary — Run Around** (attack, `[C]`) — switch Buneary with a Benched Pokémon.
**Going second only**, and it is not free positioning: besides ending the turn, the
`[C]` cost spends **the turn's one Energy attachment**, and the Energy then leaves
with Buneary for the Bench, where it can never pay for Evolution Jammer. Pay it with
**Enriching Energy** when possible; decline the attack outright when the only Energy
in hand is a `[P]` source and no second one is held. Take it last, and only when
sub-goal C has no other out (`docs/03_decision_tree.md` §4.2).

**Retreat** — costs the retreat cost of the Pokémon **leaving** the Active spot, not
the one being promoted. Once per turn. Free for Basics while Latias ex is in play.

## The evolution and energy cards

**Bronzong (TEF 69)** — Stage 1 from Bronzor. **Evolution Jammer**, `[P]`, 30 damage:
the target event. Has **no Ability**, which is what makes it Salvatore-eligible.

**Bronzor** — **four** distinct cards; always resolve by set and number, and
**never by a hard-coded list of ids**. TEF 68 is Psychic/80 HP
(Telepathic-findable, not Poffin-findable); PRE 66 is Metal/70 and SSP 126 is
Metal/60 (Poffin-findable, not Telepathic-findable); **PBL 63 is Metal/80 and is
findable by neither**, which is the printing decklist7 and decklist8 run.

The "never by a list of ids" clause is load-bearing rather than stylistic: the
trace's unused-out diagnosis held three ids by hand, went silently blind to PBL
63 when it arrived, and reported *no unused out* with a Bronzor sitting in hand —
which reads as a deck problem when it is a decision problem.

**Telepathic Psychic Energy** (Special Energy) — provides `[P]`. On attaching **to a
`[P]` Pokémon**, search up to 2 **Basic `[P]` Pokémon** onto the Bench. In these lists
that is Bronzor TEF 68, Duskull, and Latias ex. The trigger requires the *recipient* to
be `[P]`, so attaching to a Metal Bronzor pays the cost but fires no search; attaching
to the evolved Bronzong does fire it. Shuffles.

**The `[P]` recipient preference is a tie-break, never a reason to decline.** With
both a Metal and a `[P]` Bronzor available, put it on the `[P]` one so the search
fires; with only a Metal Bronzor, attach it anyway. Sub-goal D is what the card is
for and the search is the bonus — a turn that declines the attachment to protect a
search has traded the attack for a fetch. **The preference applies to bodies
already on the board as well as to a choice in hand**, which is what it means in
decklist7 and decklist8, the only lists pairing TEF 68 with the Metal PBL 63.

**And with a Metal recipient, spend a basic Psychic Energy instead if one is in
hand.** The Telepathic is the more useful of the two — it is the only Energy that
also searches — so on a body that cannot fire that search the plain one is the
cheaper card to spend. **A default rather than a ruling** (PB-20): inside a
two-turn window there is often no later body to keep the Telepathic for, and the
choice only changes which card a subsequent Ultra Ball or Lillie's sees.

**And it is attached only while sub-goal D is unmet** (`docs/03_decision_tree.md`
§4.2 step 6). A second Telepathic onto a line that already carries a `[P]` source
buys a search whose two fetches land in the Bench slots §4.4 is holding, on a turn
the window is about to close.

**With one exception: a second Bronzong holding nothing takes it.** Where the
attacker is paid and a *second* Bronzong is in play carrying no Energy, the spare
`[P]` source goes onto that Bronzong, and the turn ends with two Bronzong each able
to attack. The exception is about a **Bronzong** and stops there: a second
**Bronzor** gets nothing, because a Bronzor with an Energy on it is still a
Bronzor, and the Bench slots the search would fill are worth more than the
attachment.

**Basic Psychic Energy** (SVE 5 / MEE 5) — provides `[P]`, no effect. The only `[P]`
source recoverable with Night Stretcher.

**Rare Candy** (Item) — Basic → Stage 2, i.e. **Dusknoir only** (Mega Lopunny ex is a
Stage 1). Carries the ordinary timing restrictions: not on our first turn, and not onto
a Basic put into play this turn. **Not an inert card**: it is the
only route from a **Duskull** Active to a Dusknoir, and therefore the enabler of the
Cursed Blast escape below. Never played in preference to evolving Bronzong — but
**once Bronzong is settled either way** it is played on a **benched** Duskull, so
the board the window closes on carries a Dusknoir rather than a card in hand
(`docs/03_decision_tree.md` §8). Never onto the Active, and never spending a copy
the rung-5 escape still needs.

## Inert for turns 1–2

Modelled as playable, with no effect on any sub-goal:

- **Boss's Orders** — moves the opponent's Pokémon only.
- **Special Red Card** — requires the opponent at ≤3 Prizes; never true here.
- **Night Stretcher** — recovers a Pokémon or **Basic** Energy from discard. Only
  relevant to undo an Ultra Ball discard; cannot recover Telepathic Psychic Energy.
  Inert as a *play*, and load-bearing as a *card held*: holding one is what
  releases a surplus Bronzong onto the Ultra Ball discard order above.
- **Jamming Tower / Festival Grounds / Nighttime Mine** — Stadiums. Occupy the
  once-per-turn Stadium slot; none advances a sub-goal, and none hurts us, so one
  is played for the board record. **Holding two, the one earlier in hand is
  played** — which answers **PB-11** by default rather than by argument, and is
  currently unreachable anyway: no decklist runs two Stadiums with different
  names (S-34).
- **Mystery Garden and Risky Ruins** — Stadiums that are **never played**, under
  §4.2 step 7's "not disruptive to us". Mystery Garden would cost a `[P]` source
  to draw. **Risky Ruins puts 2 damage counters on every Basic non-`[D]` Pokémon
  *any* player benches**, and with no opposing board modelled that is only ever
  ours — Bronzor, Duskull, Latias ex, Meowth ex, Munkidori, Buneary, Dunsparce,
  all non-`[D]`. Twenty damage Knocks Out none of them inside this window, so the
  metric would not move either way; what it would change is the end-of-turn-2
  board record, which is reason enough to decline it and reason enough to say so
  here. Its damage is modelled as **not arising**, because the play that would
  cause it is declined — so if a future rule ever plays it, the damage has to be
  implemented in the same change.
- **Munkidori — Adrena-Brain** (Ability) — moves damage counters, and no damage
  inside this window changes whether Evolution Jammer can be used. Inert as a
  *play*, live as a *target*: it is a Basic `[P]` Pokémon, so **Telepathic Psychic
  Energy can fetch it** and it is a legal want-list filler. At 110 HP it is over
  Poffin's cap.
- **Blissey ex** — evolves from **Chansey**, and no decklist runs one, so in
  decklist7 and decklist8 there is no legal way to put it into play at all. A dead
  card in both, and a decklist question rather than a simulator one.
- **Flutter Mane** — Midnight Fluttering needs the Active spot, which Bronzor wants.
- **Dusclops / Dusknoir** — as a *damage* plan, off-plan: 5 or 13 damage counters mean
  nothing to a metric that ends on turn 2. But **Cursed Blast is not inert.** Its
  self-Knock Out lets us choose a new Active from the Bench, which is a switching
  effect costing no Switch, no Supporter slot, no retreat and no Energy — the last rung
  of the §4.3 ladder, for an Active that is stuck. See `docs/03_decision_tree.md` §8;
  the Ability also works from the Bench, where it does nothing for us.
- **Mega Lopunny ex** — competes for the turn-2 evolution; off-plan for this metric.

## Specified and not implemented

Cards whose text is transcribed and whose effect on this metric is real, but
which the policy does not yet play. **Each one biases the list that runs it
downward**, so a rate for that list is a lower bound until the entry is cleared.
All three arrived with decklist7 and decklist8.

- **Dunsparce — Trading Places** (attack, `[C]`) — switch this Pokémon with 1 of
  your Benched Pokémon. Structurally identical to **Buneary's Run Around**: it
  costs the turn's one Energy attachment, strands that Energy on the Bench, and
  ends the turn, so it belongs at rung 4 of the §4.3 ladder under exactly the
  §4.2 caveats. One copy, decklist8 only. *(It is an attack and not an Ability —
  see `docs/cards/JTG-120-dunsparce.md`, where that distinction is the whole
  card.)*
- **Dudunsparce — Run Away Draw** (Ability) — draw 3, then shuffle this Pokémon
  and everything attached back into the deck. Its window here is one turn wide:
  Dunsparce must be benched on turn 1 and the evolution is legal only from turn
  2, so it fires at most once. It shuffles, so it must check the pending-stack
  flag. One copy, decklist8 only.
- **Basic Darkness Energy as Run Around's payment** — §4.2 says to pay Run Around
  with Enriching Energy where possible, because Enriching is the Energy we can
  most afford to strand. In decklist7 and decklist8 a basic Darkness Energy is
  cheaper still: it is not a `[P]` source, it draws nothing, and its only job is
  an Ability that is inert here. The preference order should gain it ahead of
  Enriching.

## Opponent cards (scenario `item_lock` only)

**Budew — Itchy Pollen** (attack, no Energy) — during our next turn we may play no
**Item** cards. Only usable by a player who went **second** (it is an attack). Against
us it lands on **our turn 2**, disabling Switch, Rare Candy, Ultra Ball, Poké Pad,
Buddy-Buddy Poffin, and Pokégear 3.0 — which is why the turn-1 build order tries to
finish sub-goals A, C, and D on turn 1 rather than deferring them.



---

## Open questions — the register

Numbered so an answer names what it settles. `docs/03b_scenarios.md` poses several
of these as concrete positions; the `S-nn` references point there. The `DT-nn`
questions live in `docs/03_decision_tree.md` §9.

An entry that gets answered is folded into the card's own paragraph and struck from
this list, so the register always reads as what is still open.

### The want-list

- **PB-01.** Should each search card have its **own stopping point** on the list?
  Poké Pad is free and reaches item 7; Ultra Ball costs two discards and probably
  should not reach item 6. Where does each card stop?
- **PB-15.** The want-list is walked in the same order on turn 1 and turn 2, but
  what a fetch is *for* differs: a turn-1 fetch has a whole turn to be cashed and
  a turn-2 fetch has none. **Narrowed:** a turn-2 fetch whose only effect is to
  occupy a Bench slot is declined where the attachment would pay for it. Should
  the same reasoning drop item 7 (Duskull as filler) from every turn-2 search
  outright, including the free ones, where the cost is a Bench slot and nothing
  else?

### Individual cards

- **PB-11.** **Which Stadium** to play when holding two, and whether Jamming Tower
  or Nighttime Mine ever works against us.
- **PB-12.** **Mystery Garden** — worth modelling, or leave it inert? Its text is a
  live turn-1/2 draw effect, so "inert" is currently a known simplification. It is
  in no decklist, so this binds only if it is added.
- **PB-14.** **Boss's Orders** and **Special Red Card** have no effect functions at
  all. Both are genuinely inert for this metric — but Boss's Orders occupies 2
  slots in decklist2. Is it earning them?
- **PB-18.** The Ultra Ball release conditions are stated as *cards in hand* — a
  Night Stretcher held, a Salvatore held. Should a Night Stretcher **believed
  findable in the deck** release a surplus Bronzong too, or is only a copy already
  in hand a real undo?
- **PB-19.** Every card the Ultra Ball discard order does not name ties at the
  bottom and is spent in **hand order** — every Supporter, every Item, every
  Energy, Mega Lopunny ex, and a surplus Bronzor once Salvatore has released it.
  A spare Poké Pad and a spare Bronzor are not equivalent cards. Where do they
  belong on the order?
- **PB-20.** With a **Metal** recipient and both Energy in hand, the basic
  Psychic is spent and the Telepathic kept, on the ground that the Telepathic is
  the only Energy that also searches. Inside a two-turn window there is often no
  later body to keep it for — is holding it back worth anything?
