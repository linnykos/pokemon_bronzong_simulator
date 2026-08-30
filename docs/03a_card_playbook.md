# Part 3a — Card Playbook

**Status: draft for Kevin's review.** Per-card rules: what each card does in the
simulator, and what it should be aimed at. Companion to `docs/03_decision_tree.md`,
which gives the shape of the turn. This file is the spec for `R/card_effects_claude.R`.

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
6. **A second Bronzor** — insurance against the first being Knocked Out
7. **Meowth ex** — if a Supporter is still wanted and Meowth ex is unplayed
8. **Duskull** — filler, and a legal Poffin/Telepathic target

**Item 4 moves to the front when sub-goal C is blocked** — the line is in play, on
the Bench, and neither a free retreat nor a Switch can move it. Latias ex stops
being a nice-to-have and becomes the missing piece, and only Ultra Ball and Brock's
Scouting can fetch it. That is also why Poké Pad ends up being the card that finds
Bronzong: it cannot fetch a Rule Box.

The rule for every search card is: *walk this list, skip anything this card cannot
legally fetch, take the first hit*. A search that finds nothing is a **whiff**, and the
whiff updates the belief state (ADR 0003) — the searched cards are now known.

> **One list, cards with very different costs — and it shows.** Walking the same
> list to the same depth is wrong in two measured ways, and this is the open
> question the list most needs answering.
>
> **A floor, per card.** Poké Pad is free, so reaching item 6 costs nothing. Ultra
> Ball costs **two discarded cards**, so paying that for "a second Bronzor as
> insurance" is a bad trade. Adding items 6 and 7 to this list cost **1.4
> percentage points** (53.9% → 52.6%, 1,000 replicates going second on decklist2)
> almost entirely through the hand-fetching cards spending themselves on insurance
> once the useful targets had whiffed. Each card probably needs its own stopping
> point, not just its own legality filter.
>
> **Where the fetch lands.** Poffin and Telepathic put Basics **on the Bench**, not
> in hand. So item 7 is actively wrong for them: **Meowth ex fetched onto the Bench
> never triggers Last-Ditch Catch**, because the Ability fires only when it is
> played from hand. A search that "finds" Meowth ex this way spends a Bench slot
> and gets nothing.

---

## Search cards

**Poké Pad** (Item) — free, finds one Pokémon **without a Rule Box**.
Eligible: Bronzor (all printings), Bronzong, Duskull, Dusclops, Dusknoir, Buneary,
Flutter Mane, Budew. **Cannot** find Latias ex, Meowth ex, Mega Lopunny ex, Mega
Kangaskhan ex. Play early and freely; it has no cost. Shuffles.

**Ultra Ball** (Item) — finds **any** Pokémon; requires discarding 2 other cards from
hand first. Play it only when the discard is affordable. **Discard priority** (first
listed goes first):
Special Red Card → Boss's Orders → surplus Duskull beyond 1 → Dusclops → Dusknoir →
surplus Rare Candy → a Stadium → Flutter Mane → surplus Bronzong beyond 1.
**Never discard:** the only `[P]` source, the only Bronzor, the only Bronzong, the
only Switch when Bronzor is benched, or Salvatore on a live turn-1 kill.
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
Mode rule: **Basics mode on turn 1** (target Bronzor + Latias ex), **Evolution mode on
turn 2** (target Bronzong) and only when Hilda is unavailable. It is the only *free*
way to find Latias ex. Shuffles.

**Hilda** (Supporter) — one **Evolution Pokémon** *and* one **Energy card**, both to
hand. Targets: Bronzong + a `[P]` source. Solves sub-goals B and D with one card,
which makes it the default turn-2 Supporter. Shuffles.

**Salvatore** (Supporter) — searches for a card with **no Abilities** that evolves from
one of our Pokémon and **puts it onto that Pokémon**, bypassing both evolution timing
restrictions (ADR 0001). Legal targets here: **Bronzong** and **Mega Lopunny ex** only
— Dusclops and Dusknoir have Cursed Blast and are excluded. Requires a legal target to
exist in the deck; if all Bronzong are prized or discarded it is **unplayable**, and
that fact is information. Shuffles. **Only ever played on turn 1 going second** — its
exemption is worthless on turn 2.

**Pokégear 3.0** (Item) — looks at the **top 7**, may take one Supporter, shuffles the
rest back. Not a tutor: it can whiff, and the hit probability depends on how many
Supporters remain. Its value is concentrated on **turn 1 going first**, the only turn
where a Supporter cannot otherwise be played but can be *found* for next turn.
**Never play it while a Ciphermaniac's stack is pending** — the shuffle destroys it.

**Ciphermaniac's Codebreaking** (Supporter) — searches 2 cards and puts them **on top
of the deck**, in a chosen order. Turn 2 draws exactly **one** of them. Stack the more
urgent card on top. **Playable in exactly one cell: `P2T1`** — going second, on our
own first turn. Going first no Supporter is legal on turn 1, and on turn 2 the draw
step has already passed, so the stack is never reached inside the window
(`docs/03_decision_tree.md` §6). **Sets a `pending_stack` flag on the belief state**, and every
shuffling card must check it. Shuffles the deck *before* placing, so the stack survives
only until the next shuffle.

## Draw cards

**Lillie's Determination** (Supporter) — shuffle hand into deck, draw 6; **draw 8 while
holding exactly 6 Prizes**, which is always true on turns 1–2 (and stays true even
after a Cursed Blast self-Knock Out, which costs the *opponent's* Prize pile, not
ours). Because it puts the current hand into the deck, the policy must make every other
play it intends **first** — and that includes **benching the Pokémon it wants to
keep**, which is the one situation where filling the Bench is right
(`docs/03_decision_tree.md` §4.4).

**Mega Kangaskhan ex — Run Errand** (Ability) — draw 2, once per turn, **only while
Active**. Free and repeatable across turns; take it whenever Kangaskhan is Active and
the draw is not actively unwanted. Conflicts with Bronzor for the Active spot.

**Enriching Energy** (Special Energy) — draw 4 on attach. Provides `[C]` and **is not a
`[P]` source**. Attaching it consumes the turn's one Energy attachment, so it is right
on turn 1 (when the `[P]` source can wait) and usually wrong on turn 2.

**Meowth ex — Last-Ditch Catch** (Ability) — on being **played from hand onto the
Bench**, search the deck for a **Supporter**. Does **not** trigger from a setup
placement or from being placed as the Active. Target: Hilda by default, Salvatore if
the turn-1 kill is live and Salvatore is not already in hand. Shuffles. **Bench it only
when the Supporter we want is absent from hand** — with Hilda already held it spends a
Bench slot to fetch nothing worth having.

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
better card outright (Kevin, 2026-08-29). **No decklist runs it** — it is a candidate
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

**Bronzor** — three distinct cards; always resolve by set and number. TEF 68 is
Psychic/80 HP (Telepathic-findable, not Poffin-findable); PRE 66 is Metal/70 and
SSP 126 is Metal/60 (Poffin-findable, not Telepathic-findable).

**Telepathic Psychic Energy** (Special Energy) — provides `[P]`. On attaching **to a
`[P]` Pokémon**, search up to 2 **Basic `[P]` Pokémon** onto the Bench. In these lists
that is Bronzor TEF 68, Duskull, and Latias ex. The trigger requires the *recipient* to
be `[P]`, so attaching to a Metal Bronzor pays the cost but fires no search; attaching
to the evolved Bronzong does fire it. Shuffles.

**Basic Psychic Energy** (SVE 5 / MEE 5) — provides `[P]`, no effect. The only `[P]`
source recoverable with Night Stretcher.

**Rare Candy** (Item) — Basic → Stage 2, i.e. **Dusknoir only** (Mega Lopunny ex is a
Stage 1). Carries the ordinary timing restrictions: not on our first turn, and not onto
a Basic put into play this turn. **No longer inert** (Kevin, 2026-08-29): it is the
only route from a **Duskull** Active to a Dusknoir, and therefore the enabler of the
Cursed Blast escape below. Still never played in preference to evolving Bronzong.

## Inert for turns 1–2

Modelled as playable, with no effect on any sub-goal:

- **Boss's Orders** — moves the opponent's Pokémon only.
- **Special Red Card** — requires the opponent at ≤3 Prizes; never true here.
- **Night Stretcher** — recovers a Pokémon or **Basic** Energy from discard. Only
  relevant to undo an Ultra Ball discard; cannot recover Telepathic Psychic Energy.
- **Jamming Tower / Festival Grounds / Nighttime Mine / Mystery Garden** — Stadiums.
  Occupy the once-per-turn Stadium slot; none advances a sub-goal. Mystery Garden would
  cost a `[P]` source to draw, which is counterproductive.
- **Flutter Mane** — Midnight Fluttering needs the Active spot, which Bronzor wants.
- **Dusclops / Dusknoir** — as a *damage* plan, off-plan: 5 or 13 damage counters mean
  nothing to a metric that ends on turn 2. But **Cursed Blast is not inert.** Its
  self-Knock Out lets us choose a new Active from the Bench, which is a switching
  effect costing no Switch, no Supporter slot, no retreat and no Energy — the last rung
  of the §4.3 ladder, for an Active that is stuck. See `docs/03_decision_tree.md` §8;
  the Ability also works from the Bench, where it does nothing for us.
- **Mega Lopunny ex** — competes for the turn-2 evolution; off-plan for this metric.

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
questions live in `docs/03_decision_tree.md` §10.

### The want-list

- **PB-01.** Should each search card have its **own stopping point** on the list?
  Poké Pad is free and can afford to reach item 8; Ultra Ball costs two discards
  and probably should not reach item 6. Where does each card stop?
- **PB-02.** **Meowth ex is item 7, and Poffin and Telepathic put it on the Bench**,
  where Last-Ditch Catch never triggers. Should the bench-placing searches skip it
  outright, or is a body worth the slot anyway?
- **PB-03.** Item 6, "a second Bronzor as insurance" — insurance against a Knock
  Out that cannot happen inside this window. Worth a search, or an item that only
  makes sense in a longer game? *(See S-11.)*
- **PB-04.** Item 5 is Switch, which only **Ciphermaniac's** can actually fetch, since
  nothing else in the deck searches Trainers. Should Ciphermaniac's stack a Switch
  when sub-goal C is the blocker? *(See S-05.)*

### Individual cards

- **PB-05.** The **Ultra Ball discard order** — is it right? Is discarding a
  surplus Bronzong ever correct when there are only 2 in the deck? *(See S-07.)*
- **PB-06.** The **never-discard list** protects the only Switch "when Bronzor is
  benched". It is worth 5 points as it stands. Should it also protect the only
  Poké Pad, or Lillie's on a hand that is about to need it?
- **PB-07.** **Poké Pad** ends up being the card that finds Bronzong, because it
  cannot fetch Latias ex. Is that the right division of labour, or should Poké Pad
  chase the Bronzor and Ultra Ball the Bronzong?
- **PB-08.** **Telepathic Psychic Energy** — with both a Metal Bronzor and a `[P]`
  Bronzor available as recipients, prefer the `[P]` one purely to fire the search?
  No decklist runs a Metal Bronzor today, so this binds only if one is added.
- **PB-09.** **Enriching Energy** draws 4 but provides `[C]`. It is currently never
  attached at all. Is there a turn-1 hand where the draw is worth the attachment?
- **PB-10.** **Night Stretcher** is modelled as inert. It recovers a Pokémon or a
  Basic Energy from the discard — is there a line where recovering a discarded
  Bronzor or Psychic Energy matters inside two turns?
- **PB-11.** **Which Stadium** to play when holding two, and whether Jamming Tower
  or Nighttime Mine ever works against us.
- **PB-12.** **Mystery Garden** — worth modelling, or leave it inert? Its text is a
  live turn-1/2 draw effect, so "inert" is currently a known simplification. It is
  in no decklist, so this binds only if it is added.
- **PB-13.** **Rare Candy → Dusknoir** on a turn where Bronzong is unreachable —
  the replicate is already a miss, so does the board it leaves behind justify the
  evolution? *(Also DT-23.)*
- **PB-14.** **Boss's Orders** and **Special Red Card** have no effect functions at
  all. Both are genuinely inert for this metric — but Boss's Orders occupies 2
  slots in decklist2. Is it earning them?
