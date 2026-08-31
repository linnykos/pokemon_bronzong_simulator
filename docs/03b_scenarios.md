# Part 3b — Scenarios

Positions to answer, so your intuition can be compared against
`docs/03_decision_tree.md` rather than argued with in prose.

**The tree's own answer is not on this page.** It is in appendix A at the bottom,
one entry per scenario, so that reading the question does not anchor you to it.
Answer first, then read the appendix; where you and the tree disagree, the tree is
what changes.

**Every observed position is real.** It comes from a named seed on `decklist2`,
reached by the current policy, and the percentage is how often a position matching
that description arose across 500 games. **The percentage is the point as much as
the position is** — a question about a spot that arises once in 500 games is not
worth your afternoon. Regenerate them with:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/generate_scenarios_claude.R
```

which writes fresh positions to `docs/03b_generated_positions.md`.

Notation: `Bronzor(TEF)[P]{TelepathicPsychicEnergy}` is a Bronzor TEF 68, a `[P]`
Pokémon, carrying a Telepathic Psychic Energy. `played=T1` is the turn it reached
play.

**Numbering starts at S-15.** S-01 to S-14 are answered; their answers are rules in
`docs/03_decision_tree.md` and `docs/03a_card_playbook.md` now, and the answers
themselves are archived in `HISTORY_kevin.md`.

**Answer in frequency order.** S-15 (19.8%), S-22 (12.8%), S-25 (11.6%) and S-23
(9%) are where an answer changes the most games. S-20 arises in 1.6% and can wait —
but read it anyway, because it is the one that found a line the tree cannot
currently take.

---

## S-15 — Lillie's with the turn already won

*Turn 2, going second, `clear`. Seed 1. **19.8%** of games — the most common
question in this file.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Latiasex[P]{TelepathicPsychicEnergy} played=T1 | MegaKangaskhanex[C] played=T0 | Duskull[P] played=T1
  hand     Duskull, Budew, Buneary, Dusknoir, Dusknoir, LilliesDetermination, Bronzong, TelepathicPsychicEnergy, Dusclops
  discard  Hilda
  deck     39 cards   prizes 6   stadium -
```

The turn is already won: the Bronzor reached play last turn, so it evolves, the
second Telepathic pays for the attack, and Evolution Jammer fires. Lillie's is the
only Supporter left in hand and the slot is unspent. **The window closes at the end
of this turn** (ADR 0007), so nothing drawn now is ever played.

- **a)** Evolve, attach, attack — and play Lillie's before attacking anyway, since
  the slot is destroyed otherwise and eight fresh cards is a better record of where
  the game stood.
- **b)** Evolve, attach, attack, and **do not** play Lillie's. On a turn that is
  already won it buys nothing at all, and the end-of-turn board is more honest
  without a hand that was shuffled for no reason.
- **c)** Play Lillie's **first**, before evolving, so the eight cards can still be
  used this turn — accepting that it buries the Bronzong and the Telepathic
  currently in hand.
- **d)** something else: ______

*Probes DT-24.*

---

## S-16 — Salvatore, Hilda, and a Poké Pad that does the same job

*Turn 2, going second, `clear`. Seed 41. **4.4%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1
  bench    MegaKangaskhanex[C] played=T0 | Latiasex[P] played=T1 | Duskull[P] played=T1 | Meowthex[C] played=T1
  hand     MegaLopunnyex, PokePad, Hilda, Dusknoir, MegaKangaskhanex, Buneary, RareCandy, Salvatore, MegaLopunnyex
  discard  PokePad, UltraBall, BosssOrders, CiphermaniacsCodebreaking, Switch, LilliesDetermination
  deck     33 cards   prizes 6   stadium -
```

Bronzong is the only missing piece: the Bronzor is Active, it reached play last
turn so it can be evolved from hand, and the Telepathic is already attached. Three
cards in hand can find a Bronzong, and they cost different things.

- **a)** Salvatore — it fetches the Bronzong and puts it straight onto the Bronzor,
  and with the Energy already attached Hilda's second search is dead weight.
- **b)** Hilda — she fetches the Bronzong *and* a spare Energy for the same slot,
  and the Bronzor evolves from hand regardless.
- **c)** Poké Pad — it finds Bronzong for **free**, leaving the Supporter slot for
  whichever of the two is worth more afterwards.
- **d)** something else: ______

*Probes DT-25.*

---

## S-17 — Ciphermaniac's on `P2T1` with one piece missing

*Turn 1, going second, `clear`. Seed 99. **2.4%** of games.*

```
  active   Bronzor(TEF)[P] played=T0
  bench    (empty)
  hand     TelepathicPsychicEnergy, Dusknoir, UltraBall, CiphermaniacsCodebreaking, CiphermaniacsCodebreaking, TelepathicPsychicEnergy, Duskull
  discard  -
  deck     46 cards   prizes 6   stadium -
```

Exactly the hand §6 priority 6 was narrowed to: Bronzor Active, two Telepathics in
hand, and **Bronzong the single missing piece**. Turn 2 draws one card, so one card
is all that is needed.

- **a)** Ciphermaniac's, stacking Bronzong on top — turn 2's draw completes the
  line and no other card is spent.
- **b)** Ultra Ball for the Bronzong outright. It costs two discards, but it puts
  the card in hand now rather than offering it to a draw step.
- **c)** Ultra Ball for the Bronzong **and then** Ciphermaniac's on top of that, for
  whatever is still worth stacking once B is closed.
- **d)** something else: ______

*Probes DT-17, PB-04.*

---

## S-18 — Hilda whose two searches are both redundant

*Turn 2, going second, `clear`. Seed 68. **4.8%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1
  bench    Latiasex[P] played=T1 | MegaKangaskhanex[C] played=T0 | Duskull[P] played=T1 | Bronzor(TEF)[P] played=T1
  hand     Dusknoir, Bronzong, Hilda, Bronzong, TelepathicPsychicEnergy, Switch
  discard  UltraBall, BosssOrders, Duskull, Hilda
  deck     38 cards   prizes 6   stadium -
```

Both Bronzong are in hand and a third Energy is too. Everything Hilda searches for,
you already hold. The attack is on regardless.

- **a)** Play her anyway — the slot is destroyed if it is not used, and a spare
  Energy in hand costs nothing.
- **b)** Do not play her. Two cards you cannot use are not worth a search, and the
  window ends here.
- **c)** Play her, and use the second Bronzong on the benched Bronzor as well, so
  the board that gets recorded carries the whole line twice over.
- **d)** something else: ______

*Probes PB-16.*

---

## S-19 — Rare Candy and Dusknoir on a turn that is already won

*Turn 2, going second, `clear`. Seed 4. **8%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T0
  bench    Latiasex[P] played=T1 | Meowthex[C] played=T1 | Duskull[P] played=T1 | Bronzor(TEF)[P] played=T1
  hand     Dusknoir, Dusclops, CiphermaniacsCodebreaking, PokePad, RareCandy, Salvatore, MegaLopunnyex
  discard  PokePad, UltraBall, Duskull, Duskull, LilliesDetermination
  deck     35 cards   prizes 6   stadium JammingTower
```

Bronzong is the only gap and the Poké Pad can close it for free. That leaves Rare
Candy, Dusknoir and Salvatore all live on a turn the metric no longer needs — and
§8 says not to evolve Dusknoir *in preference to* Bronzong, which is not the
question here.

- **a)** Poké Pad for the Bronzong, evolve, attack. Leave the Rare Candy and the
  Dusknoir in hand; they are off-plan.
- **b)** Same, but Rare Candy the benched Duskull into Dusknoir before attacking —
  the metric is already banked and the board this leaves behind is worth more.
- **c)** Same as (a), and spend the Supporter on Salvatore for the second Bronzong
  onto the benched Bronzor.
- **d)** something else: ______

*Probes DT-23, PB-13.*

---

## S-20 — The escape that is one card away

*Turn 2, going second, `clear`. Seed 134. **1.6%** of games — and the one worth
reading out of order.*

```
  active   Duskull[P] played=T0
  bench    Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1 | Duskull[P] played=T1
  hand     FlutterMane, Hilda, MegaKangaskhanex, Bronzong, RareCandy
  discard  UltraBall, Dusknoir, RareCandy, Hilda
  deck     41 cards   prizes 6   stadium -
```

Sub-goal C is the whole problem. There is no Latias ex in play, so the Duskull's
retreat costs 1 and nothing is attached to pay it; there is no Switch. The benched
Bronzor already carries its Energy and the Bronzong is in hand, so **every other
sub-goal is met**. The §4.3 rung-5 escape wants a Dusknoir to Rare Candy the
Duskull into — and the only one you have seen is in the discard.

- **a)** Evolve the benched Bronzor into Bronzong and take the miss. Nothing in
  hand moves the Active.
- **b)** Play **Hilda aimed at a Dusknoir** — she fetches an Evolution Pokémon, and
  Dusknoir is one. Rare Candy it onto the Duskull, Cursed Blast, promote the
  Bronzong, attack.
- **c)** Play Hilda for what she is normally for — a second Bronzong and an Energy
  — evolve on the Bench, and accept the miss.
- **d)** something else: ______

*Probes DT-22, and a rule the playbook does not yet have: **when the Cursed Blast
escape is the only route to C, does Dusknoir join the want-list ahead of
everything else?***

---

## S-21 — *(no example found)*

The predicate asked for a **Night Stretcher in hand with a Bronzor or Bronzong in
the discard**, to settle PB-10. In 500 games it never happened, and the reason is a
rule that already works: the Ultra Ball never-discard list protects the only
Bronzor and the only Bronzong, so the line does not reach the discard in the first
place. **PB-10 is answered by its own unreachability** — Night Stretcher has
nothing to recover inside this window, which is what justifies its new rank third
on the Ultra Ball discard order. Left in the predicate list so a future decklist
that changes the discard pattern re-raises it.

---

## S-22 — Enriching Energy and an attachment with nothing to spend it on

*Turn 1, going second, `clear`. Seed 7. **12.8%** of games.*

```
  active   Duskull[P] played=T0
  bench    (empty)
  hand     Dusknoir, UltraBall, PokePad, PokePad, NightStretcher, RareCandy, EnrichingEnergy
  discard  -
  deck     46 cards   prizes 6   stadium -
```

No Bronzor, no Bronzong, and no `[P]` source — Enriching Energy provides `[C]` and
does not count for sub-goal D. But the turn's one attachment is otherwise going
completely unused, and attaching Enriching draws **4**.

- **a)** Search with the Poké Pads and the Ultra Ball, and attach nothing. Enriching
  is not a `[P]` source and the attachment is better left alone.
- **b)** Attach Enriching to the Duskull for the draw-4. Turn 2 gets its own
  attachment, so this costs sub-goal D nothing at all.
- **c)** Search first, then attach Enriching to whichever Bronzor the searches turn
  up, so the draw-4 happens on the body that will actually attack.
- **d)** something else: ______

*Probes PB-09.*

---

## S-23 — Poké Pad and Ultra Ball, and which one chases what

*Turn 1, going second, `clear`. Seed 33. **9%** of games.*

```
  active   Meowthex[C] played=T0
  bench    (empty)
  hand     LilliesDetermination, LilliesDetermination, UltraBall, PokePad, TelepathicPsychicEnergy, TelepathicPsychicEnergy, LilliesDetermination
  discard  -
  deck     46 cards   prizes 6   stadium -
```

Meowth ex led, so Last-Ditch Catch never fired — §3 says never to lead it, and this
is what that costs. Two Energy and three Lillie's in hand; no Bronzor, no Bronzong,
and a Colorless Active that will need moving. **Poké Pad cannot fetch Latias ex**
(Rule Box); Ultra Ball is the only Item that can.

- **a)** Poké Pad for the Bronzor, Ultra Ball for **Latias ex** — the Active is
  Colorless and something has to move it.
- **b)** Poké Pad for the Bronzor, Ultra Ball for the **Bronzong**, and trust the
  Supporter to find the mover.
- **c)** Ultra Ball for Latias ex first, then Poké Pad for whichever of Bronzor and
  Bronzong the board turns out to want more.
- **d)** something else: ______

Note the Ultra Ball discard: one Telepathic and this turn's Supporter are both
protected, so it pays with two of the spare Lillie's.

*Probes PB-07.*

---

## S-24 — Four candidate leads and no Bronzor

*Turn 1, going second, `clear`. Seed 1. **3%** of games.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    (empty)
  hand     Hilda, Duskull, Budew, TelepathicPsychicEnergy, Buneary, Dusknoir, Dusknoir
  discard  -
  deck     46 cards   prizes 6   stadium -
```

The opening hand held Kangaskhan, Duskull, Budew and Buneary and no Bronzor. §3's
order picked Kangaskhan, and that order is still a default rather than a ruling.
The measured rates going second are Latias ex 65.6%, **Kangaskhan 55.8%**, Budew
53.7%, Duskull 49.4%, Meowth ex 46.2%, Buneary 40.2%, Flutter Mane 35.7% — but
those are facts about the policy as much as about the deck.

- **a)** Kangaskhan, as §3 says — Run Errand draws 2 now, and it retreats free once
  Latias ex is benched.
- **b)** Duskull — a `[P]` body, so the Telepathic can go on it this turn and fire
  its search for two Basics including the Bronzor.
- **c)** Buneary — Run Around can put a found Bronzor into the Active spot on turn 1
  without spending the Supporter slot or the retreat.
- **d)** something else: ______

*Probes DT-03.*

---

## S-25 — The line Active, and only the attachment missing

*Turn 2, going second, `clear`. Seed 7. **11.6%** of games.*

```
  active   Bronzor(TEF)[P] played=T1
  bench    Latiasex[P] played=T1 | Duskull[P] played=T0
  hand     PokePad, RareCandy, EnrichingEnergy, Meowthex
  discard  PokePad, UltraBall, NightStretcher, Dusknoir
  deck     43 cards   prizes 6   stadium -
```

Positioning is solved — the Bronzor is Active and reached play last turn, so it
evolves. **Both** remaining gaps are cards: a Bronzong and a `[P]` source, and one
Supporter has to find both. Meowth ex in hand can fetch that Supporter, at the cost
of a Bench slot.

- **a)** Bench Meowth ex for the Supporter, Poké Pad for the Bronzong, and let the
  fetched Supporter find the Energy.
- **b)** Poké Pad for the Bronzong and keep Meowth ex in hand — a Supporter is
  likely to be drawn anyway and the Bench slot is not recoverable.
- **c)** Bench Meowth ex aimed at **Lillie's** rather than Hilda, and take an
  eight-card redraw at both missing pieces at once.
- **d)** something else: ______

*Probes DT-01 — §1 claims C is the sub-goal that actually fails, and this is a
position where C was free and the attachment is what is left.*

---

## S-26 — The last Bench slot against a second Telepathic

*Turn 2, going second, `clear`. Seed 33. **5.2%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1
  bench    Latiasex[P] played=T1 | Meowthex[C] played=T0 | Duskull[P] played=T1 | Bronzor(TEF)[P] played=T1
  hand     TelepathicPsychicEnergy, Dusknoir, Dusknoir, RareCandy, Hilda, LilliesDetermination, RareCandy, MegaLopunnyex
  discard  PokePad, UltraBall, LilliesDetermination, TelepathicPsychicEnergy, LilliesDetermination
  deck     34 cards   prizes 6   stadium JammingTower
```

Sub-goal D is already paid on the Active Bronzor, so the second Telepathic in hand
has nothing to buy but its own search — which would fill the one remaining Bench
slot. Thirty-four cards left in the deck, and Bronzong is the only gap.

- **a)** Hilda for the Bronzong, evolve, attack; attach nothing and leave the last
  slot empty.
- **b)** Same, but attach the second Telepathic to the Bronzong so its search fills
  the slot and thins the deck by two.
- **c)** Lillie's rather than Hilda — with 34 cards left an eight-card redraw finds
  the Bronzong about as reliably and leaves a real hand behind.
- **d)** something else: ______

*Probes PB-15, DT-02.*

---

# Appendix A — what the tree does today

Computed by running `policy_turn()` from each position, not remembered. Regenerate
with `scripts/generate_scenarios_claude.R`.

- **S-15** — evolve; attach the Telepathic; search Duskull and Flutter Mane;
  **Lillie's Determination, drew 8**; play Jamming Tower; **Evolution Jammer**.
  Option (a): the fallback spends the slot even on a won turn.
- **S-16** — **Poké Pad → Bronzong**; evolve; Hilda, whose evolution search is
  declined and whose Energy search finds a Telepathic; **Evolution Jammer**. Option
  (c), and Salvatore is never reached because the free Item got there first.
- **S-17** — **Ultra Ball → Bronzong**; attach the Telepathic to the Bronzor;
  search Latias ex and Duskull; **Ciphermaniac's stacking Bronzong then Switch**.
  Option (c).
- **S-18** — evolve; Hilda, evolution search declined, Energy search finds a
  Telepathic; **evolve again** — the second Bronzong onto the benched Bronzor;
  **Evolution Jammer**. Between (a) and (c).
- **S-19** — Poké Pad → Bronzong; evolve; **Salvatore → Bronzong** onto the benched
  Bronzor; evolve again; **Evolution Jammer**. Option (c). Rare Candy is left in
  hand.
- **S-20** — evolve the benched Bronzor; Hilda, evolution search **declined**,
  Energy search finds a Telepathic. **A miss.** The escape is not taken, because
  Hilda is never aimed at a Dusknoir and Rare Candy has nothing to become.
- **S-22** — Poké Pad → Bronzor; Ultra Ball → Latias ex; bench both; promote the
  Bronzor by free retreat. **Enriching Energy is never attached**, so the turn's
  attachment goes unused. Option (a).
- **S-23** — Poké Pad → Bronzor; Ultra Ball → Latias ex; bench both; promote by
  free retreat; attach a Telepathic to the Bronzor; search Duskull and a second
  Bronzor; **Lillie's, drew 8**; play Jamming Tower. Option (a).
- **S-24** — Run Errand; bench Latias ex; Hilda → Bronzong and a Telepathic; attach
  the Telepathic **to Latias ex**; search Bronzor and Duskull; promote the Bronzor
  by free retreat. The Kangaskhan lead, played out.
- **S-25** — bench Meowth ex, whose Last-Ditch Catch fetches **Hilda**; Poké Pad →
  Bronzong; Hilda → Bronzong and a Telepathic; evolve; attach; search; **Evolution
  Jammer**. Option (a).
- **S-26** — Hilda → Bronzong and a Telepathic; evolve; **Evolution Jammer**. The
  second Telepathic is **not** attached and the last Bench slot stays empty.
  Option (a).
