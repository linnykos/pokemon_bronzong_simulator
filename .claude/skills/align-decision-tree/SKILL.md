---
name: align-decision-tree
description: Realign R/decision_claude.R with docs/03_decision_tree.md and docs/03a_card_playbook.md. Use when either decision document has been edited, when the code and the tree are reported to disagree, when a rule in the tree turns out to be unimplemented, or before a run whose numbers will be read as facts about the deck.
---

# Align the policy with the decision documents

Kevin edits the decision documents and does not edit the R (`CLAUDE.md` → *The
decision documents are the specification*). This skill closes the gap afterwards,
in both directions, and leaves the documents describing the simulator that
actually runs.

Two words carry the work:

- **red** — the code fails to do what a document says. A code defect.
- **green** — the code does something no document describes. A wording gap, and
  Kevin's to settle, not yours.

Auditing for one finds roughly half the divergences. The manual pass on
2026-08-29 turned up seven red and eight green, and neither list contained the
other's items.

## 1. Fix the map first

`R/decision_claude.R` opens with a section → function table. Read it, and read
both documents. Where a section has gained or lost material, correct the table
before auditing — every later step indexes through it.

Done when every section of `docs/03_decision_tree.md` has a row, and every row
names a function that exists.

## 2. Two agents, one per direction

Dispatch both in a single message so they run at once. Give each the section
list, the two document paths, and `R/decision_claude.R`.

**The red agent** answers one question: *for each rule in the documents, does the
code do it?* It reports the section, the rule, and the observed behaviour. It
proposes no fixes.

**The green agent** answers the other: *for each decision the code makes, does a
document say to?* Same shape of report.

Keeping the questions apart is the point. An agent asked for "any divergence"
finds the first kind and stops.

Done when both have reported and every section appears in one report or the
other, including the sections that turned out to be aligned.

## 3. Red findings: a failing test, then the code

For each, in this order:

1. **Write the test first**, in `tests/testthat/test_decision.R`, citing the
   section it comes from in its comment. Run it and watch it fail — a test that
   passes before the fix is testing something else.
2. **Fix `R/decision_claude.R`** until it passes.
3. Keep the rest of the suite green.

Read `/r-style-guide` before editing any `.R` file, and its `references/tests.md`
before writing the test.

Done when every red finding has a test that failed before the change and passes
after, and `tests/run_tests_claude.R` is green.

## 4. Green findings: draft the wording, hand it over

The documents are Kevin's. For each green finding, write the sentence or the
table row you would add, in the voice of the surrounding section, and say which
section it belongs in. Then apply them — he reads the documents, so a finding
left only in a chat message is a finding lost — and tell him plainly which
paragraphs are new so he can rewrite them.

Mark a rule the code does not implement as **specified and not implemented** in
place, rather than quietly dropping it.

Done when every green finding is either written into a document or reported as a
question with the reason it was not written.

## 5. Re-measure, and attribute the change

Run both cells and compare with the previous numbers.

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" tests/run_tests_claude.R
cd demo && "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" ../scripts/knit_rmd_claude.R demo_simulator_claude.Rmd
```

A bare before-and-after is not the deliverable. **Attribute the movement to
individual changes** by neutralising one at a time and re-running — that is what
turns "alignment cost 1.4 points" into "the want-list's items 6-7 cost all of it,
and the pending-stack guard costs nothing". The attribution is usually worth more
to Kevin than the rate.

Done when every point of movement is assigned to a named change, or explicitly
reported as unattributed.

## Traps this repo has already sprung

- **A search target the card cannot legally fetch is a crash, not a misplay.**
  The effects assert legality with `stopifnot()`. Filter every target through
  `ALLOWED_TARGET_LIST` in `R/card_effects_claude.R`, which both sides consult.
- **A diagnostic whose precondition is inverted reads as working.** It fires
  rarely, so a count of 2 in 322 looks plausible. Every `unused_outs()` entry
  needs a test asserting the negative case with the card still in hand.
- **The policy may read the hand, the board, the discard and the belief state**
  (ADR 0003). Searches go through `believes_findable()`. A test greps the source
  for `state$prize_vec` and `state$deck_vec`, because reading a field leaves no
  trace that a played game could reveal.
- **"Inert for the metric" is a claim about every line a card appears in.** Rare
  Candy sat on the inert list until the Cursed Blast escape made it the enabler
  of sub-goal C.

## Finish

Run `/project-state`. Record the red and green counts, the rate movement with its
attribution, and any green finding Kevin still has to rule on.
