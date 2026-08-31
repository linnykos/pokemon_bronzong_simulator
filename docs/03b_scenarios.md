# Part 3b — Scenarios

Positions to answer, so your intuition can be compared against
`docs/03_decision_tree.md` rather than argued with in prose.

**The tree's own answer is not on this page.** It is in appendix A at the bottom,
one entry per scenario, so that reading the question does not anchor you to it.
Answer first, then read the appendix; where you and the tree disagree, the tree is
what changes.

**Every observed position is real.** It comes from a named seed on the decklist
named in its header, reached by the current policy, and the percentage is how
often a position matching that description arose across 500 games. **The
percentage is the point as much as the position is** — a question about a spot
that arises once in 500 games is not worth your afternoon. Regenerate them with:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/generate_scenarios_claude.R
```

which writes fresh positions to `docs/03b_generated_positions.md`.

Notation: `Bronzor(TEF)[P]{TelepathicPsychicEnergy}` is a Bronzor TEF 68, a `[P]`
Pokémon, carrying a Telepathic Psychic Energy. `played=T1` is the turn it reached
play.

**Numbering starts at S-27.** S-01 to S-26 are answered; their answers are rules
in `docs/03_decision_tree.md` and `docs/03a_card_playbook.md` now, and the answers
themselves are archived verbatim in `HISTORY_kevin.md`.

## Three things are deliberately different about this bank

**It leaves the going-second `clear` cell.** Every position from S-15 to S-26 came
from there, and it is one of the *three* cells the registry reports — so two
thirds of what this project measures had never been put to you as a question.
Going first is the weaker branch by twelve points and had never been asked about
at all. **S-32 and S-33 are the two that fix that**, and S-33 is the most common
position in this file.

**It leaves decklist2.** decklist7 is a different deck rather than a variation,
and the questions it raises cannot be asked from decklist2: a Gwynn to rank
(S-27), a Stadium that damages our own Bench (S-36), a Buddy-Buddy Poffin that
cannot fetch a Bronzor (S-35), and a Blissey ex that cannot be played at all
(S-37).

**It asks about turns the metric has already lost**, because that is where the
next decision defect lives and a bank made only of winnable positions cannot find
one.

## Answer in frequency order

**S-33 (30.8%)**, **S-36 (21.0%)**, **S-35 (15.2%)** and **S-37 (12.6%)** are
where an answer changes the most games. **S-39 arises in 3.8% and should be read
out of order** — it is this bank's S-20, the one that found something the tree is
getting wrong rather than merely leaving open.

**S-29 (0.2%) and S-30 (0.6%) are honestly rare** and are here only because they
are the exact residuals of DT-23 and DT-25. Answer them last, or leave them.

---

## S-27 — Gwynn against Lillie's, for the same slot

*Turn 2, going second, `clear`, **decklist7**. Seed 31. **6.8%** of games.*

```
  active   Bronzor(PBL)[M] played=T1
  bench    Latiasex[P]{EnrichingEnergy} played=T0
  hand     Bronzong, RiskyRuins, Dusknoir, Duskull, Duskull, Munkidori,
           Hilda, Gwynn, LilliesDetermination, RiskyRuins
  discard  PokePad, PokePad
  deck     39 cards   prizes 6   stadium -
```

The Bronzong is in hand and the Bronzor reached play last turn, so B and C are
solvable. **The `[P]` source is the whole problem** — the only Energy in play is
the Enriching on the Latias ex, which is `[C]` and pays nothing. Three Supporters
are in hand and one slot.

Note what Gwynn can legally take: **Munkidori and two Duskull** are the spare
Pokémon (the Bronzong is protected by name, Dusknoir is spare too) — so Gwynn
discards **2** and draws **6**, keeping the Bronzong. Lillie's draws **8** and
shuffles the Bronzong back into the deck. And Hilda fetches a Bronzong *and* an
Energy in one card, which is the thing actually missing.

- **a)** Hilda — she solves D directly, and the Bronzong in hand means her
  evolution search is a spare.
- **b)** Gwynn — 6 cards and the Bronzong stays in hand.
- **c)** Lillie's — 8 cards, the largest draw, and the Bronzong goes back into
  the deck to be found again.
- **d)** something else: ______

*Probes DT-27.*

---

## S-28 — A won turn with a spare Salvatore and a spare Ciphermaniac's

*Turn 2, going second, `clear`, **decklist2**. Seed 126. **1.4%** of games.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Meowthex[C] played=T1 | Latiasex[P]{TelepathicPsychicEnergy} played=T0
           | Duskull[P] played=T1
  hand     Dusknoir, CiphermaniacsCodebreaking, Salvatore, MegaLopunnyex,
           TelepathicPsychicEnergy, Bronzong, TelepathicPsychicEnergy,
           BosssOrders
  discard  Hilda
  deck     40 cards   prizes 6   stadium -
```

The turn is already won: the Bronzor reached play last turn so it evolves, and a
Telepathic in hand pays the attack. The Supporter slot is unspent and nothing
depends on it.

**This is the position I did not follow your S-19 answer on**, and it is here so
you can overrule me. You picked Ciphermaniac's there and marked the choice
unimportant; the fallback ranks Salvatore ahead of it, on the ground that a
Ciphermaniac's stack is two cards this window can never draw while Salvatore puts
a **second Bronzong** onto the benched line.

- **a)** Salvatore — a second Bronzong on a benched Bronzor, if one is there to
  take it. A real board.
- **b)** Ciphermaniac's — stack two cards the window will never see, and leave the
  hand alone.
- **c)** Neither. The turn is won; spending the slot changes nothing that is
  measured and the honest record is the board as it stood.
- **d)** something else: ______

*Probes DT-26.*

---

## S-29 — Rare Candy on a turn that is already lost

*Turn 2, going second, `clear`, **decklist2**. Seed 115. **0.2%** of games — the
rarest in this file, and the exact residual of DT-23.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T0
  bench    Latiasex[P] played=T1 | Duskull[P] played=T1
  hand     BosssOrders, Dusknoir, RareCandy, MegaLopunnyex, Switch, Duskull
  discard  PokePad
  deck     43 cards   prizes 6   stadium -
```

Read the turn-1 line: **the Poké Pad whiffed, and that is how the player knows
both Bronzong are prized.** Sub-goal B is unreachable this turn and every turn
inside the window, so the replicate is a miss whatever happens next. A Rare Candy
and a Dusknoir are in hand and a Duskull is on the Bench.

- **a)** Rare Candy the benched Duskull into a Dusknoir. The metric is lost; the
  board the window closes on is worth more with the evolution on it.
- **b)** Do nothing. A lost turn should stop, and a board built out after the
  metric is gone is decoration.
- **c)** something else: ______

*Probes DT-23, PB-13. §8 currently says (a) — as a **proposal**, since your S-19
answer covered the turn that is already won and not this one.*

---

## S-30 — Salvatore against Hilda, with no Item that can fetch the Bronzong

*Turn 2, going second, `clear`, **decklist2**. Seed 194. **0.6%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1
  bench    MegaKangaskhanex[C] played=T0 | Latiasex[P] played=T1
           | Meowthex[C] played=T1
  hand     Dusknoir, LilliesDetermination, Hilda, Switch, MegaLopunnyex,
           MegaLopunnyex, LilliesDetermination, Salvatore, RareCandy
  discard  PokePad, LilliesDetermination
  deck     38 cards   prizes 6   stadium -
```

Your S-16 answer settled the common case: a free Poké Pad finds the Bronzong and
the Supporter slot goes to whatever is worth more afterwards. **This is the
position where that escape does not exist** — no Poké Pad, no Ultra Ball, and both
Salvatore and Hilda in hand. The `[P]` source is already attached, so Hilda's
Energy search adds nothing; the Bronzor reached play last turn, so it can be
evolved from hand and Salvatore's timing bypass adds nothing either.

- **a)** Salvatore — one card, fetches the Bronzong and puts it on the Bronzor.
- **b)** Hilda — one card, fetches the Bronzong to hand and an Energy that is
  redundant, and the Bronzor evolves from hand anyway.
- **c)** Lillie's — eight cards. Two Bronzong in a 38-card deck is not a bad draw,
  and it keeps both tutors for a turn that does not exist.
- **d)** something else: ______

*Probes DT-25 — the discriminator, in the one position where it actually binds.*

---

## S-31 — Ultra Ball paying two cards for a Duskull

*Turn 2, going second, `clear`, **decklist2**. Seed 31. **3.4%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T0
  bench    Meowthex[C] played=T1 | Duskull[P] played=T1 | Bronzor(TEF)[P] played=T1
  hand     LilliesDetermination, MegaLopunnyex, Dusknoir, Bronzong, Bronzong,
           UltraBall
  discard  UltraBall, Dusclops, Dusknoir, Hilda
  deck     39 cards   prizes 6   stadium -
```

Every sub-goal is already met — the Bronzong is in hand, the Bronzor is Active
with its Energy — so the want-list has run out of anything that matters and its
**last entry is Duskull as filler**. Ultra Ball is in hand and would pay two
cards for it: Mega Lopunny ex and the Dusknoir, since both Bronzong are protected
and the Lillie's is this turn's Supporter.

- **a)** Play it. A card out of the deck thins the deck, and the two it costs are
  cards this window cannot convert anyway.
- **b)** Do not play it. Two cards for a Duskull is the definition of a search
  card with no stopping point, and it fills a Bench slot for nothing.
- **c)** Play it, but give **Ultra Ball** a shorter want-list than the free
  cards get — stop it before the filler entry while Poké Pad still reaches it.
- **d)** something else: ______

*Probes PB-01, PB-15.*

---

## S-32 — Turn 1 going first, where no Supporter may be played

*Turn 1, **going first**, `clear`, **decklist2**. Seed 12. **7.8%** of games — and
one of only two positions in this file from the branch the deck is built to
survive.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    (empty)
  hand     NightStretcher, MegaLopunnyex, Switch, Salvatore, Meowthex,
           Latiasex, Bronzor(TEF)
  discard  -
  deck     46 cards   prizes 6   stadium -
```

No Supporter may be played at all, so the Salvatore in hand is dead this turn and
the whole turn exists to set up turn 2. Five Bench slots, and four Pokémon in hand
that could take them: Bronzor, Latias ex, Meowth ex, Mega Lopunny ex.

Meowth ex is the interesting one. §5 calls this **the one branch where benching it
is close to automatic**, because Last-Ditch Catch is not a Supporter and so works
on a turn when no Supporter may be played — and the card it fetches is played next
turn.

- **a)** Bench Latias ex, bench the Bronzor, bench Meowth ex for a Hilda, and
  retreat into the Bronzor for free. Three of five slots gone on turn 1.
- **b)** The same, but **hold Meowth ex** — Salvatore is already in hand and
  playable next turn, so the fetched Supporter may be surplus and the Bench slot
  is not recoverable.
- **c)** Bench Latias ex and the Bronzor only, and keep both Meowth ex and the
  Switch in hand as turn-2 options.
- **d)** something else: ______

*Probes DT-18, and §5 as a whole — a section no scenario has ever tested.*

---

## S-33 — Turn 2 under the Item lock, with the Supporter alone

*Turn 2, **going first**, **`item_lock`**, **decklist2**. Seed 4. **30.8%** of
games — the most common position in this file, in a cell that has never been
asked about.*

```
  active   Bronzor(TEF)[P] played=T0
  bench    Meowthex[C] played=T1
  hand     Bronzong, Switch, RareCandy, Duskull, Hilda, LilliesDetermination
  discard  PokePad, UltraBall, Duskull, LilliesDetermination
  deck     42 cards   prizes 6   stadium -
```

Itchy Pollen landed, so **every Item in this hand is dead**: the Switch and the
Rare Candy cannot be played at all. What is left is one evolution, one
attachment, one bench, and one Supporter.

The Bronzong is in hand and the Bronzor reached play before this turn, so B and C
are solvable. **Sub-goal D is the whole problem** — there is no Energy in hand,
and the two cards that could find one are the Hilda that Meowth ex fetched last
turn and the Lillie's.

Lillie's **shuffles the hand into the deck**, so with it the order is a question
as well as the choice.

- **a)** Hilda — she fetches an Energy directly, and the redundant evolution
  search costs nothing.
- **b)** Evolve first, *then* Lillie's, then attach whatever the eight cards gave
  — so the Bronzong is on the board before it can be buried.
- **c)** Lillie's without evolving first, for a hand chosen with more information
  — accepting that the Bronzong goes back into the deck.
- **d)** something else: ______

*Probes the `item_lock` cell, and §6's ordering rule under a lock that removes
every alternative.*

---

## S-34 — *(no example found)*

The predicate asked for **two different Stadiums in hand at once**, to settle
PB-11. In 500 games it never happened, and the reason is arithmetic rather than
policy: **no decklist runs two Stadiums with different names.** decklist2 runs one
Jamming Tower; decklist7 runs two Risky Ruins, and a Stadium may not replace one
of the same name. **PB-11 is unreachable as the lists stand**, and the predicate
is left in place so that a list running two names re-raises it automatically.

---

## S-35 — A Poffin that cannot fetch the Bronzor the turn needs

*Turn 1, going second, `clear`, **decklist7**. Seed 2. **15.2%** of games.*

```
  active   Duskull[P] played=T0
  bench    (empty)
  hand     Salvatore, NightStretcher, Gwynn, PokePad, Dusknoir,
           BuddyBuddyPoffin, DarknessEnergy
  discard  -
  deck     46 cards   prizes 6   stadium -
```

**Buddy-Buddy Poffin caps at 70 HP, and both Bronzor printings in decklist7 are
80** — TEF 68 and PBL 63. So the Poffin in this hand *cannot fetch a Bronzor*.
Its only legal targets in this list are Duskull, Buneary and Dunsparce, none of
which advances any sub-goal. The Poké Pad, which is free and has no HP cap, is
what actually finds the Bronzor.

- **a)** Play the Poké Pad for the Bronzor, and play the Poffin too — two bodies
  and two cards out of the deck cost nothing on turn 1.
- **b)** Play the Poké Pad and **hold the Poffin**. A Bench slot spent on a
  Duskull is a slot the turn-2 Telepathic search wants, and this deck has five.
- **c)** Cut the Poffin from decklist7 and decklist8 outright, and put the two
  slots somewhere that can reach a Bronzor.
- **d)** something else: ______

*Probes PB-01, and whether the Bronzor printing in these two lists is right.*

---

## S-36 — Risky Ruins as the only Stadium in hand

*Turn 2, going second, `clear`, **decklist7**. Seed 3. **21.0%** of games.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Latiasex[P]{TelepathicPsychicEnergy} played=T0 | Latiasex[P] played=T1
  hand     DarknessEnergy, RiskyRuins, Dusknoir, Duskull, Dusknoir, Bronzong,
           PokePad
  discard  Hilda
  deck     42 cards   prizes 6   stadium -
```

Risky Ruins reads *"whenever **any player** puts a Basic non-`[D]` Pokémon onto
their Bench during their turn, place 2 damage counters on that Pokémon."* No
opposing board is modelled, so all of that falls on ours — and every Basic this
deck benches is non-`[D]`. Twenty damage Knocks nothing out inside two turns; what
it changes is the board the window closes on.

§4.2 step 7 says to play a Stadium only when **it is not disruptive to us**, so
the tree currently never plays this one — which makes its **two slots in decklist7
and decklist8 dead inside the measured window**.

- **a)** Never play it, as the tree has it. It damages only us here.
- **b)** Play it anyway. The Stadium slot is otherwise idle, 20 damage kills
  nothing in this window, and against a real opponent it is doing the work it was
  put in the list for — which the simulator cannot see.
- **c)** Cut it from both lists, and treat "the simulator cannot model the
  opponent" as a reason not to run the card rather than a reason to excuse it.
- **d)** something else: ______

*Probes PB-11, and §4.2 step 7. **Read S-39 next** — this same position hides a
second problem, and it is the one that costs points.*

---

## S-37 — Blissey ex in hand, and no Chansey anywhere

*Turn 2, going second, `clear`, **decklist7**. Seed 4. **12.6%** of games.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Duskull[P] played=T1 | Latiasex[P]{TelepathicPsychicEnergy} played=T0
           | Latiasex[P] played=T1
  hand     Blisseyex, RiskyRuins, DarknessEnergy, LilliesDetermination,
           NightStretcher, Bronzong, PokePad
  discard  BuddyBuddyPoffin, Hilda
  deck     40 cards   prizes 6   stadium -
```

**Blissey ex TWM 134 is a Stage 1 that evolves from Chansey, and neither decklist7
nor decklist8 runs a Chansey.** There is no legal way to put it into play: Rare
Candy goes Basic → Stage 2 and cannot reach a Stage 1, and Salvatore fetches a
card that evolves from a Pokémon we control. It is a card that can only ever be
discarded, and it cannot even be discarded to Gwynn, which excludes Rule Box
Pokémon.

This is a decklist question rather than a policy one, and it is the only one in
this bank.

- **a)** It is an error — cut it from both lists.
- **b)** It is deliberate and a Chansey is meant to be in there; the lists are
  what need fixing, not the card.
- **c)** It is doing something outside this window that the metric cannot see,
  and it stays.
- **d)** something else: ______

*Probes nothing in the tree. Verified twice —
`docs/cards/TWM-134-blissey-ex.md`.*

---

## S-38 — A miss where the attachment was the only thing missing

*Turn 2, going second, `clear`, **decklist2**. Seed 7. **6.6%** of games.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Latiasex[P] played=T1 | Duskull[P] played=T0
  hand     NightStretcher, RareCandy, Bronzong, JammingTower
  discard  PokePad, PokePad, UltraBall, Dusknoir, EnrichingEnergy
  deck     42 cards   prizes 6   stadium -
```

The Bronzong is in hand, the Bronzor is Active and reached play last turn, and
**the one thing missing is a `[P]` source.** The Enriching Energy went onto a
Buneary last turn — your S-22 answer, working as intended: the attachment was
otherwise going unused and it drew 4. Four cards in hand and no Supporter among
them, so nothing here can find an Energy at all.

§1 claims **C is the sub-goal that actually fails**. Over 1,000 replicates the
unmet tally going second is A 43 / B 137 / C 159 / **D 201**, and D has been the
largest through a twenty-five-point rise in the rate.

- **a)** §1 is still right. D looks largest only because it can *only* be unmet
  once B and C are met, so it inherits their failures.
- **b)** §1 is wrong and should be rewritten around **the turn's single Energy
  attachment**, which is the scarcest thing on the board.
- **c)** Neither — the tally is the wrong instrument, and the question should be
  re-asked as "which sub-goal, when it fails, has no other out".
- **d)** something else: ______

*Probes DT-01.*

---

## S-39 — The `[P]` source stranded on a body that cannot attack

*Turn 2, going second, `clear`, **decklist2**. Seed 34. **3.8%** of games — and the
one in this file worth reading out of order.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Latiasex[P] played=T1 | Duskull[P]{TelepathicPsychicEnergy} played=T0
           | Duskull[P] played=T1
  hand     Hilda, Hilda, LilliesDetermination, BosssOrders, NightStretcher,
           Bronzong, Dusknoir
  discard  Hilda
  deck     41 cards   prizes 6   stadium -
```

Read the turn-1 line, because the position is a consequence of it:

> lead Duskull; bench Latias ex; **Hilda** → Bronzong and a Telepathic; **attach
> the Telepathic to the Duskull**; its search fetches **Bronzor** and a Duskull
> onto the Bench; promote the Bronzor by free retreat.

The tree attached the Telepathic to a **Duskull** because at the moment of
attaching there was no Bronzor in play — and the search that attachment fired is
what *put* the Bronzor into play, one step too late to receive it. So turn 1 ends
with the line Active and carrying nothing, and the `[P]` source sitting on a body
that can never use it. The turn's one attachment bought sub-goal A and threw away
sub-goal D.

The tree knows it is doing this: *"the Energy is stranded on a body that will not
attack, which is a real cost — but a turn with no Bronzor in play has nothing
better to spend the attachment on."* This position says the second half is
sometimes false.

- **a)** Leave it. A Bronzor in play is worth more than an Energy in the right
  place, and turn 2 gets a fresh attachment.
- **b)** Fire the search **from a Bronzor**, not onto one: find the Bronzor with
  an Item first where the hand has one, bench it, and only then attach the
  Telepathic to it — so the same card pays D and searches.
- **c)** Do not attach at all when no Bronzor is in play and the search is the
  only reason. Keep the Telepathic for turn 2, where it will land on the line.
- **d)** something else: ______

*Probes DT-01 and §4.2 step 6. Sub-goal D is the largest unmet count in every cell
of the registry, and this is one named, reproducible way the tree produces it.*

---

# Appendix A — what the tree does today

Computed by running `policy_turn()` from each position, not remembered. Regenerate
with `scripts/generate_scenarios_claude.R`.

- **S-27** — **Hilda**, fetching a second Bronzong and a Telepathic; evolve;
  attach; search; **Evolution Jammer**. Option (a) — neither draw Supporter is
  reached, because §6 priority 3 outranks both and Hilda is the card that solves
  the gap.
- **S-28** — evolve; **Salvatore → a second Bronzong**; attach the second
  Telepathic to it; search; **Evolution Jammer**. Option (a), against your S-19
  answer.
- **S-29** — **Rare Candy → Dusknoir** on the benched Duskull, and nothing else.
  Option (a), and it is a proposal rather than a ruling.
- **S-30** — evolve; **Salvatore → Bronzong**; **Evolution Jammer**. Option (a).
- **S-31** — **Ultra Ball → Duskull**, paying Mega Lopunny ex and a Dusknoir for
  it; then Lillie's. **A miss.** Option (a) — and this is the clearest case in the
  file for giving Ultra Ball its own stopping point: two cards bought a Duskull
  and the eight-card redraw did not find the piece.
- **S-32** — Run Errand; bench Latias ex; bench the Bronzor; **bench Meowth ex for
  a Hilda**; promote the Bronzor by free retreat. Option (a).
- **S-33** — **Hilda**, fetching a Bronzong and a Telepathic; evolve; attach;
  search; **Evolution Jammer**. Option (a) — the Lillie's is never reached, and
  the ordering question the other options ask does not arise.
- **S-35** — Poké Pad → Bronzor; **Poffin → Duskull**; Gwynn, discarding 1 and
  drawing 3; bench the Bronzor. Option (a) — and the Poffin's only effect on the
  turn was to spend a Bench slot on a body that does nothing.
- **S-36** — Poké Pad → Duskull; evolve. **Risky Ruins is not played**, and the
  turn is a **miss** on sub-goal D. Option (a) — and see S-39 for why it missed.
- **S-37** — Poké Pad → Duskull; evolve; bench a Duskull; Lillie's, drew 8; attach
  a Telepathic from those 8; **Evolution Jammer**. **Blissey ex is never played
  and never discarded**; it simply sits in hand through the whole window.
- **S-38** — evolve; play Jamming Tower. **A miss on sub-goal D**, with nothing in
  hand that could have found an Energy — which is the position the question is
  about rather than a defect in it.
- **S-39** — Hilda, evolution search declined, Energy search finds a Telepathic;
  evolve; **attach the new Telepathic to the Bronzong**; search; **Evolution
  Jammer**. A hit — but only because a *second* Telepathic was findable. The first
  one is still on the Duskull and always will be.

**S-36 and S-38 are the two misses in this appendix**, and both miss on sub-goal
**D** — which is the largest unmet count in all twenty-four cells of the registry
and the reason S-38 and S-39 are in this bank at all.
