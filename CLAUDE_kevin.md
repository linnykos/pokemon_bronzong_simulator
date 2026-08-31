# CLAUDE_kevin.md — Kevin's Context

> **Current state only.** Every narrative section below is updated *in place* each session — overwrite, don't append. The External Locations table is keyed by (location, machine): replace the matching row when a path changes, add a row only for a new pair, and delete rows that no longer exist. The append-only dated log lives in `HISTORY_kevin.md`.
>
> **Owned by Kevin.** Only Kevin's session writes this file and `HISTORY_kevin.md`. Other collaborators may read it for context but must not edit it.

## About Kevin
- Role in project: sole author — deck designer, analyst, and the domain authority on Pokémon TCG rulings
- Background: statistician; R is the working language. Also the person to ask when a rules question can't be settled from public sources — this has already happened twice (see ADR 0001)
- Email: kzlin@uw.edu

## External Locations (per-machine paths)
Resolves the location names declared in the master `CLAUDE.md` → *External Locations* to real paths **on Kevin's machines**.

| Location name | Machine | Path | Notes |
|---|---|---|---|
| `R_BIN` | personal Windows desktop (Windows 11) | `C:\Program Files\R\R-4.6.1\bin` | R 4.6.1; **not on `PATH`** — invoke `Rscript.exe` by full path |
| `PANDOC` | personal Windows desktop (Windows 11) | `C:\Program Files\RStudio\resources\app\bin\quarto\bin\tools\pandoc.exe` | pandoc 3.8.3, bundled inside RStudio rather than installed separately. Hardcoded in `scripts/knit_rmd_claude.R`, which skips the `.html` rather than failing if it moves |

Invocation from the Git Bash shell used in these sessions:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/<script>.R
```

## Project Status (as of 2026-08-30)

Parts 1-5 are done; part 6 is not started. Part 5 is **no longer a first draft**:
Kevin has answered all fourteen positions in the first scenario bank, and the
policy is aligned to those answers. `demo/demo_simulator_claude.Rmd` is the
document to argue with it from.

**decklist2, 1,000 replicates: 75.8% going second, 64.1% going first, 60.7%
`item_lock` going first** — up from 52.6 / 53.4 / 49.0 before the answers were
folded in. The movement is attributed per change in the demo, not reported as a
lump. Two changes are almost all of it, and they are the same idea twice: **play a
Supporter every turn** (§6 priority 8, worth 15.2 going second) and **then use
what it drew** (§7 step 6, worth another 5.0 going second and 6.7 going first).

**The decision documents are the specification and the code follows them**
(`CLAUDE.md` → *The decision documents are the specification*). Kevin edits
`docs/03_decision_tree.md` and `docs/03a_card_playbook.md`; `/align-decision-tree`
brings `R/decision_claude.R` back into line afterwards. As of 2026-08-30 the two
agree.

Those two files are also **present-tense only**: they state the tree as it stands and
never how it got there. The evolution of a rule lives in `HISTORY_kevin.md`, or in an
ADR the document cites by number. **Migrated 2026-08-30** — §9's answers and
corrections tables are gone, their three still-live rules folded into the sections
they govern first, and no `(Kevin, <date>)` stamp survives in either document.

- **Part 1 — rules (done).** `docs/01_rules_standard.md`.
- **Part 2 — card text (done).** 37 files in `docs/cards/` covering 36 distinct cards, indexed by `docs/02_cards.md` with a count matrix across all six decklists. Coverage and the matrix are verified by script, not by eye.
- **Part 3 — decision tree (the specification, and now present-tense).** Both documents state the tree as it stands and nothing about how it got there; §9 of the decision tree (the answers table and the corrections table) has been **deleted**, with its three still-live rules folded into §4.1, §4.2 and §6 first. Every `(Kevin, <date>)` stamp is gone. §9 is now the open-question register — **7 `DT-nn`** (01, 03, 07, 16, 18, 21, 23) plus two the answers raised (**DT-24**, **DT-25**) — and the playbook carries **11 `PB-nn`**, including the new **PB-17**. `docs/03b_scenarios.md` is a fresh bank, **S-15 to S-26**, with the tree's answer held back to appendix A.
- **Part 4 — base simulator (done).** Eight files in `R/`: card database, decklist parsing, game state, belief state, rules, setup, card effects, traces. Now includes Rare Candy, Cursed Blast, Knock Outs and caller-chosen promotion, added 2026-08-29 once Kevin showed the Cursed Blast self-KO is an out for sub-goal C. No Monte Carlo yet, by design; the policy now lives beside it in part 5.
- **Tests (done).** `tests/run_tests_claude.R` runs **1966 assertions**, all passing, plus `scripts/smoke_test_claude.R`. testthat is not installable here, so `tests/testthat_shim_claude.R` provides a testthat-compatible harness; the test files use testthat's real API so `devtools::test()` will run them unchanged once testthat exists.
- **Part 5 — the policy (aligned to Kevin's answers).** `R/decision_claude.R`, a section-by-section translation of the decision tree so the two can be read side by side. decklist2 went 19.5% (placeholder) → 52.6% (first draft) → **75.8% going second, 64.1% going first**. A doc-section to function cross-reference sits at the top of the file, so editing a section says what to change.
- **Demo (done).** `demo/demo_simulator_claude.Rmd`, knitted to `.md` and `.html` by `scripts/knit_rmd_claude.R`: one game narrated turn by turn, then 1,000 replicates a cell with every diagnostic table, and a closing list of what the policy does **not** do yet so feedback lands on decisions rather than gaps.
- **Part 6 — not started.** The decklist registry over 10,000 replicates per cell.

Five rounds of agent audit found and fixed **~38 defects**. The classes worth remembering: silent card loss through zones nobody counted, belief-state staleness, unbounded search targets, metrics that measured availability rather than action, and — three times now — **a diagnostic that is confidently wrong rather than absent**, which is the one that actually misdirects a decision. The newest variant is the nastiest: an "unused out" whose *card* is right and whose *precondition* is inverted. It fires rarely, so a hit count of 2 in 322 reads as "working" rather than "backwards". Every out entry now needs a test asserting the negative case **with the card still in hand**.

Six decklists in `decklists/`, each a legal 60. They share a fixed 16-card shell; the live variables are Salvatore (0/1), the `[P]` energy base, Switch 3-vs-4, Bronzor 2-vs-3, Ciphermaniac's 0/2/3, and the stadium slot.

Six cards are imported as **candidates not yet in any list**: Buddy-Buddy Poffin, Bronzor PRE 66, Bronzor SSP 126, Pokégear 3.0, Mystery Garden, Surfer, plus Brock's Scouting.

## Key Methodological Details

- **The target event is an attack, not a board state.** Bronzong TEF 69 must be *Active* with a `[P]` source attached and must actually attack. See `CONTEXT.md` → *Target event*.
- **Only two cards are `[P]` sources**: basic Psychic Energy (SVE 5 / MEE 5) and Telepathic Psychic Energy (POR 88). Enriching Energy provides `[C]` and does not qualify.
- **Primary outcome is a fixed bar: Evolution Jammer on or before the player's own turn 2** (ADR 0004), identical going first and going second. Going first and going second are reported separately and never pooled (ADR 0002). Every replicate also records the *turn actually achieved*, which is the only place Salvatore's turn-1 speed appears.
- **The measured window is setup through the end of the player's own turn 2, and nothing past it is played or recorded** (ADR 0007). Separate from the ADR 0004 bar: the bar could have been turn 2 while the engine played on, and deliberately is not. In exchange the end-of-turn-2 board state is recorded in full — every zone, plus damage and the turn each Pokémon was played or evolved — so a doomed turn 2 must still be played properly.
- **The policy may not read prizes or deck order** (ADR 0003), which requires a belief state separate from ground truth, built in from the start. It constrains the **policy**, not the analysis: the trace records the prized cards, labelled as ground truth, because "both Bronzong prized" is what separates a variance miss from a decision defect. Three mechanics: deck contents unknown until the first deck search; deck order never known; the deck reshuffles unseen after every search, destroying order knowledge but not contents knowledge.
- **Three different cards are named "Bronzor."** Never write "Bronzor" without a set and number.
- **Buneary's Run Around costs `[C]`, i.e. the turn's Energy attachment**, and the Energy leaves with Buneary for the Bench. It is a last resort, not free positioning. Budew's Itchy Pollen costs no Energy, so the two §4.2 exceptions are not symmetric.
- **Retreating costs the retreat cost of the Pokémon *leaving* the Active spot.** Bronzor's retreat 3 does not obstruct promoting it; what matters is what is currently Active. Latias ex's Skyliner makes any *Basic* Active retreat free, and on turn 1 the Active is almost always a Basic — but **only a Basic**, which is why a Stage 1 Dusclops gets stuck.
- **One positioning ladder, stated once in §4.3**: free retreat under Latias ex → Switch → Surfer → Run Around → Cursed Blast. The retreat comes first because it is free and otherwise unspent; spending a Switch under Skyliner throws a card away. **All five rungs are now implemented**; rung 5 was the last one, added 2026-08-30.
- **The Supporter slot is a per-turn resource that carries no credit forward, so it is never left idle** (§6 priority 8). Every named priority above it decides *which* Supporter, never *whether*. This is the largest single change the policy has ever made — 15.2 points going second.
- **A Supporter is only worth playing if the turn then uses what it gave you** (§7 step 6). Bench / evolve / position / attach run a **second time** after the fallback Supporter. Without that pass the fallback is worth nothing at all on turn 2, because ADR 0007 closes the window before the drawn cards can be played — the two rules only make sense together.
- **Rank Supporters by what each can *solve*, never by how many sub-goals are open.** Kevin's framing, and it is what fences Ciphermaniac's into "exactly one of B, C, D missing": it puts one card into turn 2's draw, so one gap is all it can close. Two hands with the same number of gaps can want different Supporters.
- **Bench space is the fourth scarce resource** (§2, §4.4). Five slots, one reserved for Latias ex, and a benched Basic cannot be un-benched. **Bench nothing at setup**; during a turn bench only Latias ex, Meowth ex for a named absent Supporter, a Bronzor for A, and everything else only ahead of Lillie's Determination. Benching nothing is safe *only* inside this window — an empty Bench loses the game to a Knocked Out Active.
- **Cursed Blast is a switching effect, not a damage plan.** Its self-Knock Out lets us choose the replacement Active, so it is the last rung for sub-goal C; Rare Candy is what reaches it from a Duskull Active, and is therefore **not** an inert card. A self-KO costs us no Prize (the opponent takes one from *their* pile, unmodelled), so Lillie's still draws 8.
- **The transcription source mis-renders attacks as Abilities.** It did so for Evolution Jammer and Itchy Pollen. Any card whose details drive the decision tree gets a second, pointed query.
- **Base R only.** R 4.6.1 has no jsonlite, yaml, testthat, or tidyverse installed. The simulator is dependency-free. testthat cannot be installed here (R has no CRAN access), so `tests/testthat_shim_claude.R` stands in; the test files use testthat's real API and will run unchanged under `devtools::test()` if testthat ever becomes available.

## Open Questions / Next Steps

### Needs Kevin
0. **Read `demo/demo_simulator_claude.md`.** It now opens the results with a **per-change attribution table** rather than a single rate: which of the twelve changes made from your fourteen answers is worth what, in both cells, each measured by neutralising it alone. Four of them cost points and stay anyway, because they are rulings rather than optimisations.
1. **Work through the new `docs/03b_scenarios.md`** — 12 positions, **S-15 to S-26**, the tree's own answer held back to appendix A. **Answer in frequency order**: S-15 (Lillie's on a won turn) arises in 19.8% of games, S-22 (Enriching Energy) in 12.8%, S-25 (only the attachment missing) in 11.6%, S-23 in 9%. **Read S-20 out of order** at 1.6%: it is the one where the tree misses a position it could have won.
1a. **Then the registers**: 9 `DT-nn` in `docs/03_decision_tree.md` §9 and 11 `PB-nn` in the playbook. `/generate-scenarios` turns any of them into a board position if prose is the wrong way to answer it.
2. **Rule on PB-17, which the new bank raised.** With a Duskull Active, the line stranded on the Bench and a Rare Candy in hand, the Cursed Blast escape is **one Dusknoir away** — and Dusknoir is an Evolution Pokémon, so **Hilda can fetch it**. The want-list has no Dusknoir entry, so she is never aimed at one. Should Dusknoir join the want-list ahead of everything else exactly when the escape is the only route to sub-goal C, the way Latias ex does when C is blocked? Not implemented: it is a new rule and the documents are yours.
3. **Sign off the `CONTEXT.md` coinages** — *on time*, *earliest legal turn*, *shell*, *whiff*, *cell*, marked `[unconfirmed]` in that file.
4. **Decide the mulligan-bonus divergence.** The opening hand omits the bonus cards owed for an opponent's mulligans, because no opponent is modelled. Biases consistency **downward** by an unknown amount. Fixing it means modelling an opposing decklist or assuming a distribution.
5. **Confirm one wording in ADR 0003.** Kevin wrote "should NOT immediately know what's benched before the first deck-search card is played." Implemented as *deck contents / what is prized*, since that is what a deck search reveals.

### Next work
6. **The two gaps the demo still lists.** Pokégear 3.0 is never played, and a **paid** retreat is never considered even when the Energy spent was going to waste. The lead order and Ciphermaniac's timing also still need to become **parameters rather than constants**, since both were deferred to the logs.
7. **Part 6 — the registry** over 10,000 replicates per (decklist, scenario, first/second) cell. This is the next substantial piece of work; everything it needs now exists.
8. **Wire the smoke script into the test runner.** It is the only end-to-end hand-played line and nothing currently runs it automatically.

### Hypotheses to test rather than assume
9. **Getting Bronzong *Active* is the suspected bottleneck**, not drawing it. The unmet tally over 1,000 replicates going second is now **A 51 / B 153 / C 177 / D 221**, and the shape is unchanged by the rate rising 23 points: C is still the most-unmet of the three that are not the attack cost itself, and D is still inflated because it can only be met once B and C are. **S-25 poses this as a position** (11.6% of games) where C was free and the attachment was what was left.
10. **The §3 lead order** — deferred to the logs, and `lead_hit_df` is the table that settles it. **Read it only as a fact about the policy.** Kangaskhan sat at 40.9% purely because the policy did not use Run Errand; implementing the draw moved it to 55.8%. Latias ex leads the non-Bronzor field (65.6%) on a small n. **S-24 poses it as a position.**
11. **The Bronzor printing trade-off.** Poffin caps at 70 HP, so it cannot fetch TEF 68 (80) but can fetch PRE 66 (70) and SSP 126 (60) — at the cost of those being Metal, so Telepathic Psychic Energy can no longer find them. A 2/2 split keeps both routes. **Answered in principle** (S-14: attach the Telepathic to a Metal Bronzor anyway, since D is what matters), but no decklist runs one yet.
12. **Surfer competes with Salvatore for the one Supporter slot**, so Switch (an Item) is better for the turn-1 line — and no decklist runs Surfer at all. Live again only if a Surfer list is added.

### Loose ends
13. **`Mystery Garden` is modelled as inert but is not.** Its text is a live turn-1/2 draw effect. In no decklist yet, so it only bites when added as a candidate. **Rare Candy was the same error and has been fixed** — worth re-reading the whole "inert for turns 1–2" list in `R/card_effects_claude.R` with the lesson in mind: *inert* is a claim about every line a card appears in, not about its headline use.
14. **Nighttime Mine's effect text is uncorroborated** and looks implausible (hoses Tera Pokémon; no list runs Tera). decklist1 only, inert for the metric either way.
15. **The Salvatore first-turn ruling has no citable public source** (ADR 0001) — Kevin's expertise is the citation. Residual risk only.
16. **A neutralising patch that silently matches nothing reads as a change that costs nothing.** The first attribution run reported ten of thirteen changes as worth 0.0, because multiline `perl` patterns written with `\n` do not match a **CRLF** source and `perl` still exits 0. The harness now `cmp`s each patched copy and prints `SKIPPED`. Same family as the confidently-wrong diagnostics this project has hit three times: the failure produces a plausible number rather than an error.
