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

**Constructed positions are marked as such.** They are legal but the current
policy never reaches them, which is exactly why they need answering: they are the
rules the tree specifies and nothing exercises.

Notation: `Bronzor(TEF)[P]{TelepathicPsychicEnergy}` is a Bronzor TEF 68, a `[P]`
Pokémon, carrying a Telepathic Psychic Energy. `played=T1` is the turn it reached
play.

---

## S-01 — A free retreat and a Switch, for the same job

*Turn 2, going second, `clear`. Seed 20. **3.2%** of games.*

```
  active   Duskull[P] played=T0
  bench    Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1 | Latiasex[P] played=T1
  hand     Dusknoir, NightStretcher, PokePad, LilliesDetermination, Switch
  discard  PokePad
  deck     43 cards   prizes 6   stadium JammingTower
```

Latias ex is on the Bench, so Duskull retreats for free. You also hold a Switch.
Bronzong is not in hand.

- **a)** Retreat into Bronzor, keep the Switch, then Poké Pad for Bronzong.
- **b)** Switch into Bronzor, keep the retreat available in case turn 2 needs a
  second reposition.
- **c)** Poké Pad first, then decide how to move based on what it finds.
- **d)** something else: ______

*Probes DT-08, DT-09.*

---

## S-02 — Kangaskhan Active on turn 2, the line on the Bench

*Turn 2, going second, `clear`. Seed 1. **8.2%** of games.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    Latiasex[P]{TelepathicPsychicEnergy} played=T1 | Bronzor(TEF)[P] played=T1
  hand     Duskull, Budew, Buneary, Dusknoir, Dusknoir, LilliesDetermination, Bronzong, PokePad
  discard  Hilda
  deck     41 cards   prizes 6   stadium -
```

Turn 1 used Run Errand, benched Latias ex, and spent Hilda — whose Energy search
found nothing, so the Telepathic went onto Latias ex rather than onto the Bronzor.
Bronzong is in hand. The retreat into Bronzor is free.

- **a)** Retreat into Bronzor, evolve into Bronzong, attach nothing — there is no
  `[P]` source in hand, so the attack is off regardless.
- **b)** Run Errand first for two more cards, then retreat and evolve.
- **c)** Retreat and evolve, then Lillie's Determination to dig for the Energy.
- **d)** something else: ______

*Probes DT-11, DT-04, DT-12 — note the turn-1 Telepathic went onto Latias ex.*

---

## S-03 — Lillie's and Hilda in the same hand

*Turn 2, going second, `clear`. Seed 10. **9.2%** of games.*

```
  active   Bronzor(TEF)[P] played=T0
  bench    (empty)
  hand     Dusknoir, LilliesDetermination, LilliesDetermination, RareCandy, Salvatore, LilliesDetermination, BosssOrders, Hilda
  discard  -
  deck     45 cards   prizes 6   stadium -
```

Eight cards, three of them Lillie's. Bronzor is already Active, so sub-goal C is
done; B and D are both open.

- **a)** Hilda — fetch Bronzong and a `[P]` source, and attack this turn.
- **b)** Lillie's — the hand is mostly dead weight, so shuffle it into the deck
  and draw 8.
- **c)** Salvatore — fetch Bronzong straight onto the Bronzor, then use the
  attachment on whatever the draw gave you.
- **d)** something else: ______

*Probes DT-13, DT-14, DT-15.*

---

## S-04 — Hilda with both her targets already in hand

*Turn 2, going second, `clear`. Seed 44. **4.4%** of games.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    (empty)
  hand     Switch, Dusknoir, Bronzong, TelepathicPsychicEnergy, Hilda, Dusknoir, LilliesDetermination, Dusknoir, CiphermaniacsCodebreaking
  discard  -
  deck     43 cards   prizes 6   stadium JammingTower
```

You hold Bronzong **and** a `[P]` source — the two things Hilda fetches — but no
Bronzor anywhere, and the Bench is empty.

- **a)** Nothing but the Supporter matters: play Lillie's to dig for a Bronzor.
- **b)** Hilda anyway, aimed at whatever she can still legally take.
- **c)** Ciphermaniac's — stack a Bronzor on top for next turn's draw.
- **d)** Spend no Supporter; Run Errand, then attach the Telepathic to Kangaskhan
  to fire its search for a Basic `[P]`.
- **e)** something else: ______

*Probes DT-14, DT-17, DT-12.*

---

## S-05 — Ciphermaniac's on `P2T1`, with Lillie's also in hand

*Turn 1, going second, `clear`. Seed 6. **13%** of games.*

```
  active   Duskull[P] played=T0
  bench    (empty)
  hand     CiphermaniacsCodebreaking, LilliesDetermination, Dusknoir, RareCandy, JammingTower, NightStretcher, UltraBall
  discard  -
  deck     46 cards   prizes 6   stadium -
```

No Bronzor, no Bronzong, no Energy. This is the one turn of the game where
Ciphermaniac's is legal *and* not obviously wasted — but turn 2 draws only one of
the two cards it stacks.

- **a)** Ciphermaniac's, stacking Bronzor then Bronzong.
- **b)** Ciphermaniac's, stacking Bronzor then a `[P]` source.
- **c)** Lillie's — draw 8 now rather than arrange one card for later.
- **d)** Ultra Ball for a Bronzor, then Ciphermaniac's for the rest.
- **e)** something else: ______

*Probes DT-17, PB-04.*

---

## S-06 — Salvatore still in hand on turn 2

*Turn 2, going second, `clear`. Seed 2. **23.4%** of games — the most common
question in this file.*

```
  active   Duskull[P] played=T0
  bench    Meowthex[C] played=T1 | Bronzor(TEF)[P] played=T1
  hand     Budew, Bronzong, MegaKangaskhanex, Salvatore, RareCandy
  discard  UltraBall, Duskull, FlutterMane
  deck     43 cards   prizes 6   stadium -
```

Meowth ex fetched Salvatore on turn 1. There is no Latias ex, so Duskull's retreat
costs 1 Energy and you have none attached; there is no Switch. Bronzong is in hand
and the Bronzor is on the Bench.

- **a)** Evolve the benched Bronzor into Bronzong and accept it is stuck there
  this turn.
- **b)** Play Salvatore to put Bronzong on the benched Bronzor — same board, but
  Bronzong stays in hand for later.
- **c)** Bench Mega Kangaskhan ex, and treat the turn as a rebuild.
- **d)** something else: ______

*Probes DT-13, DT-08.*

---

## S-07 — Ultra Ball with nothing spare to pay for it

*Turn 2, going second, `clear`. Seed 84. **2.2%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T0
  bench    Latiasex[P] played=T1 | Bronzor(TEF)[P] played=T1 | Duskull[P] played=T1
  hand     UltraBall, CiphermaniacsCodebreaking, Bronzong, Switch
  discard  PokePad, UltraBall, RareCandy, MegaLopunnyex, Hilda
  deck     40 cards   prizes 6   stadium -
```

Every other card in hand is on the never-discard list: the only Bronzong, the only
Switch with a Bronzor benched, and Ciphermaniac's. The playbook's rule says Ultra
Ball is therefore unplayable.

- **a)** Correct — do not play it. Evolve and attack; the Ultra Ball is a dead
  card this turn and that is fine.
- **b)** Discard Ciphermaniac's and the Switch to play it — the Bronzor is already
  Active, so the Switch is doing nothing.
- **c)** Discard Ciphermaniac's and Bronzong, then Ultra Ball for a second
  Bronzong.
- **d)** something else: ______

*Probes PB-05, PB-06.*

---

## S-08 — Buneary Active with the line benched

*Turn 2, going second, `clear`. Seed 9. **7.4%** of games.*

```
  active   Buneary[C] played=T0
  bench    Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1 | Latiasex[P] played=T1
  hand     CiphermaniacsCodebreaking, NightStretcher, RareCandy, Bronzong, UltraBall
  discard  UltraBall, BosssOrders, Dusknoir, Hilda
  deck     41 cards   prizes 6   stadium -
```

Latias ex is out, so Buneary retreats free. Bronzong is in hand and the Bronzor
already carries its Energy. Run Around is also available — but it is turn 2, where
attacking with Buneary ends the game's window.

- **a)** Retreat into Bronzor, evolve, attack.
- **b)** Evolve the Bronzor on the Bench first, then retreat into a finished
  Bronzong.
- **c)** Ultra Ball for a second Bronzor before committing.
- **d)** something else: ______

*Probes DT-06, DT-08.*

---

## S-09 — Going first, turn 1, a Supporter you cannot play

*Turn 1, going first, `clear`. Seed 1. **85%** of games.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    (empty)
  hand     Hilda, Duskull, Budew, TelepathicPsychicEnergy, Buneary, Dusknoir, Dusknoir
  discard  -
  deck     46 cards   prizes 6   stadium -
```

No Supporter may be played and no attack may be made. Hilda is stuck in hand until
turn 2. There is no Bronzor anywhere, and the only `[P]` bodies available are ones
you would have to bench first.

- **a)** Bench nothing; Run Errand and attach the Telepathic to Kangaskhan, whose
  `[C]` type means the search does not fire — but the Energy is banked.
- **b)** Bench Duskull, attach Telepathic to it, fire the search for two Basic
  `[P]` Pokémon.
- **c)** Run Errand only; hold the Energy so turn 2 can put it on a real Bronzor.
- **d)** something else: ______

*Probes DT-12, DT-19, DT-05.*

---

## S-10 — Items locked on turn 2, going first

*Turn 2, going first, `item_lock`. Seed 1. **47.2%** of that cell.*

```
  active   MegaKangaskhanex[C] played=T0
  bench    Latiasex[P]{TelepathicPsychicEnergy} played=T1 | Bronzor(TEF)[P] played=T1
  hand     Hilda, Duskull, Budew, Buneary, Dusknoir, Dusknoir, LilliesDetermination, PokePad
  discard  -
  deck     42 cards   prizes 6   stadium -
```

Itchy Pollen has locked your Items, so the Poké Pad is dead this turn. The retreat
into Bronzor is still free. Turn 1 put the Telepathic on Latias ex.

- **a)** Retreat into Bronzor, Hilda for Bronzong plus an Energy, evolve, attack.
- **b)** Same, but Lillie's instead of Hilda — the hand is full of cards the lock
  has made useless.
- **c)** Retreat and evolve only; save the Supporter, since the lock ends next
  turn.
- **d)** something else: ______

*Probes DT-20, DT-14.*

---

## S-11 — The last Bench slot: Latias ex or deck thinning

*Turn 2, going second, `clear`. Seed 24. **5.4%** of games.*

```
  active   Bronzor(TEF)[P]{TelepathicPsychicEnergy} played=T1
  bench    Buneary[C] played=T0 | Latiasex[P] played=T1 | Bronzor(TEF)[P] played=T1 | Duskull[P] played=T1
  hand     TelepathicPsychicEnergy, Bronzong, Dusknoir
  discard  PokePad, UltraBall, Duskull, LilliesDetermination
  deck     41 cards   prizes 6   stadium -
```

Four Bench slots used, one left. The second Telepathic in hand would fetch **two**
Basics if the space existed, thinning the deck — but only one slot remains, and
sub-goal D is already met by the Energy on the Active Bronzor.

- **a)** Evolve and attack; do not attach the second Telepathic at all.
- **b)** Attach it and fetch one Basic into the last slot — a thinner deck is a
  better draw next turn.
- **c)** Attach it to the Active Bronzong for a second Energy, declining the
  search entirely.
- **d)** something else: ______

*Probes DT-02, DT-10, PB-03.*

---

## S-12 — Both Bronzor gone, Bronzong in hand

*Turn 2, going second, `clear`. Seed 30. **7.6%** of games.*

```
  active   Latiasex[P]{TelepathicPsychicEnergy} played=T0
  bench    (empty)
  hand     LilliesDetermination, Bronzong, RareCandy, RareCandy, Hilda, Salvatore, LilliesDetermination
  discard  -
  deck     45 cards   prizes 6   stadium -
```

Latias ex led — the last resort in §3's order. Turn 1's Telepathic search **whiffed
on both Bronzor**, which is how you know they are prized. Bronzong, Hilda and
Salvatore are all in hand and all useless without a Bronzor.

- **a)** Lillie's — the hand cannot win, so redraw eight.
- **b)** Hilda for an Energy, and accept the miss.
- **c)** Nothing at all; hold everything for turn 3, which this project does not
  measure.
- **d)** something else: ______

*Probes DT-03, DT-12, PB-03.*

---

## S-13 — Dusclops stuck Active *(constructed)*

*Turn 2, going second, `clear`. **The current policy never reaches this**, which is
why it needs an answer.*

```
  active   Duskull>Dusclops[P] played=T0 evo=T2
  bench    Bronzor(TEF)[P]{PsychicEnergy(SVE)} played=T1
  hand     Bronzong, RareCandy, Dusknoir
  deck     ~42 cards  prizes 6   stadium -
```

Dusclops is a Stage 1, so **Skyliner would not help even with Latias ex out**, and
its retreat costs 2. No Switch. The benched Bronzor already carries a `[P]` source.
§8's Cursed Blast escape exists for exactly this — and note **Rare Candy is not the
route here**: it goes Basic → Stage 2, and Dusclops is a Stage 1. The Dusclops uses
**its own** Cursed Blast, Knocking itself Out, and you choose the replacement
Active. (The Rare Candy → Dusknoir route is for a **Duskull** Active, which is the
Basic version of this same position.)

- **a)** Take the escape: Cursed Blast, promote the Bronzor, evolve, attack. Costs
  a Prize to the opponent and the Dusclops.
- **b)** Evolve the benched Bronzor into Bronzong and accept the miss — a Prize is
  too much to give for one turn of tempo.
- **c)** Only take it going second, where the game is otherwise lost anyway.
- **d)** something else: ______

*Probes DT-22, DT-23.*

---

## S-14 — A Metal Bronzor in the list *(constructed)*

*Turn 1, going second, `clear`. **No decklist runs a Metal Bronzor**, so this asks
whether one should be added.*

```
  active   Bronzor(PRE)[M] played=T0        <- Metal, 70 HP
  bench    (empty)
  hand     TelepathicPsychicEnergy, BuddyBuddyPoffin, Bronzong, Duskull
  deck     ~46 cards  prizes 6   stadium -
```

The Metal printing is **Poffin-findable** (70 HP) but **not** a legal recipient for
Telepathic's search, which needs a `[P]` body. Attaching the Telepathic here pays
sub-goal D and fires nothing.

- **a)** Attach the Telepathic anyway — D is what matters, the search is a bonus.
- **b)** Play the Poffin first to get a second body down, then attach.
- **c)** The trade-off is bad enough that a 2/2 Psychic/Metal split is wrong;
  stay on TEF 68 only.
- **d)** something else: ______

*Probes PB-08, and hypothesis 9 in `CLAUDE_kevin.md`.*

---

# Appendix A — what the tree does today

Computed by running `policy_turn()` from each position, not remembered. Regenerate
with `scripts/generate_scenarios_claude.R`.

- **S-01** — Poké Pad → Bronzong; promote Bronzor via **retreat (free)**; evolve;
  **Evolution Jammer**. Option (a), and it hits.
- **S-02** — Run Errand; Poké Pad → Duskull; retreat into Bronzor; Hilda, whose
  evolution search is declined and whose Energy search finds Telepathic; evolve;
  attach; **Evolution Jammer**. Closest to (b).
- **S-03** — Hilda → Bronzong and Telepathic; evolve; attach; search; **Evolution
  Jammer**. Option (a); Lillie's is never reached, because the hand is 8 cards and
  §6 priority 4 wants four or fewer.
- **S-04** — Run Errand; Ultra Ball → Bronzor; bench it; promote via **Switch**;
  attach Telepathic; fetch Latias ex and a second Bronzor. No Supporter at all —
  Hilda is skipped because she can fetch nothing, and nothing below her fires.
- **S-05** — Ultra Ball → Bronzor; **Ciphermaniac's stacking Bronzong then
  Telepathic**; bench the Bronzor; play Jamming Tower. Between (b) and (d).
- **S-06** — **evolve the benched Bronzor into Bronzong, and nothing else.**
  Salvatore is never considered, because §6 priority 1 confines it to turn 1. The
  turn ends with Bronzong on the Bench and a miss. This is DT-13.
- **S-07** — evolve; **Evolution Jammer**. Option (a): Ultra Ball is correctly left
  unplayed.
- **S-08** — Ultra Ball → Meowth ex; retreat into Bronzor; bench Meowth ex, whose
  Last-Ditch Catch fetches Hilda; evolve; **Evolution Jammer**. Option (a) plus an
  Ultra Ball first.
- **S-09** — Run Errand; bench Latias ex; attach Telepathic **to Latias ex**;
  search finds a Bronzor. Option (b), with Latias ex as the recipient.
- **S-10** — Run Errand; retreat into Bronzor; Hilda → Bronzong and Telepathic;
  evolve; attach; search; **Evolution Jammer**. Option (a).
- **S-11** — evolve; attach the second Telepathic **to the Bronzong**; fetch one
  Duskull into the last slot; **Evolution Jammer**. Between (b) and (c).
- **S-12** — Hilda, whose evolution search is declined and whose Energy search
  finds a Telepathic; attach it **to Latias ex**; fetch Duskull and Flutter Mane.
  A miss, and two Bench slots spent on bodies that do nothing.
- **S-13** — **not implemented.** The policy has `play_rare_candy()`,
  `use_cursed_blast()` and `knock_out()` but no line that reaches them.
- **S-14** — **not reachable**: no decklist runs a Metal Bronzor.
