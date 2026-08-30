---
name: generate-scenarios
description: Turn the defaults in docs/03_decision_tree.md and docs/03a_card_playbook.md into concrete board positions for Kevin to answer, in docs/03b_scenarios.md. Use when a rule is stated as a default rather than a ruling, when a question needs a position rather than prose, when Kevin has answered the current bank and wants more, or when a new card or decklist changes which positions are reachable.
---

# Generate scenarios to answer the open questions

`docs/03b_scenarios.md` exists so Kevin's intuition can be compared against the
tree rather than argued with. A scenario is a **position**, not a hypothetical: it
comes from a named seed, the current policy reached it, and it carries how often a
position like it arose. An invented hand can be answered "I would never be here",
which settles nothing.

Two properties make the bank work, and both are easy to lose:

- **The tree's answer stays in appendix A.** Reading a question must not reveal
  what the policy does, or the answer is anchored rather than elicited.
- **The frequency is reported.** A question about a spot arising once in 500 games
  is not worth an afternoon; one arising in a quarter of them is.

## 1. Find the defaults that lack a scenario

Read both decision documents and the `DT-nn` / `PB-nn` registers at the end of
each. A question needs a position when the answer would depend on the board rather
than on principle — "which lead ranks third" does not, "do you spend the last Bench
slot on Latias ex or on thinning" does.

Done when every register entry is either matched to a scenario id or listed as one
that prose answers better, with the reason.

## 2. Write a predicate per question

Add to `PREDICATE_LIST` in `scripts/generate_scenarios_claude.R`. Each entry names
the turn, the coin flip, the scenario, the `DT`/`PB` ids it probes, and a `test`
reading the pair at the decision point. The helpers there — `.holds()`,
`.line_benched()`, `.active_is()` — are the vocabulary; add to them rather than
inlining board arithmetic in a predicate.

Then run it:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/generate_scenarios_claude.R
```

**A predicate that finds no example is a result, not a failure.** It means the
policy never reaches that position, which is worth knowing and usually means the
question belongs in the constructed half. Two predicates aimed at turn 1 found
nothing because the Bench is empty until the turn is played; moving them to turn 2
found 41 and 37 examples.

Done when every predicate either has an example or is recorded as unreachable with
the reason.

## 3. Write the question, and keep the answer out of it

For each position, in `docs/03b_scenarios.md`: the position block, one sentence of
what has already happened and why it matters, then **3–4 options plus "something
else"**, then the ids it probes.

The options are the hard part. Each must be **legal in that exact position** —
check the hand actually holds the card, that the retreat is actually free, that
the Supporter slot is actually unspent. And no option should be obviously right
from the framing, or the scenario measures nothing.

Constructed positions get the same treatment and a **`*(constructed)*`** marker,
plus a note on what makes them unreachable today.

Done when every option in every scenario is playable from the position it belongs
to.

## 4. Appendix A comes from running it, never from memory

The generator plays `policy_turn()` from each captured position and writes what
the policy actually does. Copy that into appendix A. Writing what you believe the
tree does is how an appendix goes quietly wrong.

Done when every scenario has an appendix entry naming the actual sequence, and the
entries for unreachable positions say so.

## Traps

- **A scenario must be a legal 60.** The generator asserts this with `.census()`;
  a constructed position needs the same check by hand — count the cards, and check
  the evolution timing (`docs/01_rules_standard.md` §5) for anything mid-line.
- **Rare Candy goes Basic → Stage 2.** A constructed position with a Stage 1
  Active cannot use it; that one reached a first draft of S-13.
- **Card text comes from `docs/cards/`, never from memory** (`CLAUDE.md` → *Ground
  rules*). A scenario that misstates a card teaches the wrong lesson twice: once
  to Kevin and once to whoever implements his answer.

## Finish

Run `/project-state`. Record which register entries gained a scenario, which are
unreachable and why, and the frequencies — the frequencies are what tell Kevin
which questions to answer first.
