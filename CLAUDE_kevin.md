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

## Project Status (as of 2026-08-29)

Parts 1-5 are done; part 6 is not started. Part 5 is a **first draft written to
be argued with**, and `demo/demo_simulator_claude.Rmd` is the document to argue
with it from.

- **Part 1 — rules (done).** `docs/01_rules_standard.md`.
- **Part 2 — card text (done).** 37 files in `docs/cards/` covering 36 distinct cards, indexed by `docs/02_cards.md` with a count matrix across all six decklists. Coverage and the matrix are verified by script, not by eye.
- **Part 3 — decision tree (reviewed twice).** `docs/03_decision_tree.md` §9 records Kevin's answers rather than questions, plus a second block of five **corrections he made to the document itself** — bench discipline, the immaterial Items/Salvatore ordering, the retreat-before-Switch ladder, and the Cursed Blast exception. Two answers he deferred to the simulation logs — the §3 lead order and Ciphermaniac's use within `P2T1` — so both are written as defaults part 6 is expected to overturn or confirm, not as rules. `docs/03a_card_playbook.md` still ends with **four** unanswered questions of its own.
- **Part 4 — base simulator (done).** Eight files in `R/`: card database, decklist parsing, game state, belief state, rules, setup, card effects, traces. Now includes Rare Candy, Cursed Blast, Knock Outs and caller-chosen promotion, added 2026-08-29 once Kevin showed the Cursed Blast self-KO is an out for sub-goal C. No Monte Carlo yet, by design; the policy now lives beside it in part 5.
- **Tests (done).** `tests/run_tests_claude.R` runs **1900 assertions**, all passing, plus `scripts/smoke_test_claude.R`. testthat is not installable here, so `tests/testthat_shim_claude.R` provides a testthat-compatible harness; the test files use testthat's real API so `devtools::test()` will run them unchanged once testthat exists.
- **Part 5 — the policy (first draft).** `R/decision_claude.R`, a section-by-section translation of the decision tree so the two can be read side by side. Replacing the old placeholder policy moved decklist2 from 19.5% to **~50% going second, 48% going first**. Written to be argued with, not tuned.
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
- **One positioning ladder, stated once in §4.3**: free retreat under Latias ex → Switch → Surfer → Run Around → Cursed Blast. The retreat comes first because it is free and otherwise unspent; spending a Switch under Skyliner throws a card away.
- **Bench space is the fourth scarce resource** (§2, §4.4). Five slots, one reserved for Latias ex, and a benched Basic cannot be un-benched. **Bench nothing at setup**; during a turn bench only Latias ex, Meowth ex for a named absent Supporter, a Bronzor for A, and everything else only ahead of Lillie's Determination. Benching nothing is safe *only* inside this window — an empty Bench loses the game to a Knocked Out Active.
- **Cursed Blast is a switching effect, not a damage plan.** Its self-Knock Out lets us choose the replacement Active, so it is the last rung for sub-goal C; Rare Candy is what reaches it from a Duskull Active, and is therefore **not** an inert card. A self-KO costs us no Prize (the opponent takes one from *their* pile, unmodelled), so Lillie's still draws 8.
- **The transcription source mis-renders attacks as Abilities.** It did so for Evolution Jammer and Itchy Pollen. Any card whose details drive the decision tree gets a second, pointed query.
- **Base R only.** R 4.6.1 has no jsonlite, yaml, testthat, or tidyverse installed. The simulator is dependency-free. testthat cannot be installed here (R has no CRAN access), so `tests/testthat_shim_claude.R` stands in; the test files use testthat's real API and will run unchanged under `devtools::test()` if testthat ever becomes available.

## Open Questions / Next Steps

### Needs Kevin
0. **Read `demo/demo_simulator_claude.md` and react to the policy.** That is what it was built for. It ends with a list of known gaps so feedback lands on decisions, and it raises one question of its own: **§6 never plays Salvatore on turn 2** — read literally, priority 1 confines it to turn 1 — but on turn 2 it still fetches Bronzong *and* evolves in one card. Should it be ranked against Hilda there?
1. **Answer the playbook's four questions.** `docs/03a_card_playbook.md` — the Ultra Ball discard priority, whether Telepathic Psychic Energy should prefer a `[P]` Bronzor purely to fire its search, whether Mystery Garden is worth modelling, and whether Rare Candy → Dusknoir is ever right on an already-lost turn 2. The decision-tree questions are all answered (§9).
2. **Sign off the `CONTEXT.md` coinages** — *on time*, *earliest legal turn*, *shell*, *whiff*, *cell*, marked `[unconfirmed]` in that file.
3. **Decide the mulligan-bonus divergence.** The opening hand omits the bonus cards owed for an opponent's mulligans, because no opponent is modelled. Biases consistency **downward** by an unknown amount. Fixing it means modelling an opposing decklist or assuming a distribution.
4. **Confirm one wording in ADR 0003.** Kevin wrote "should NOT immediately know what's benched before the first deck-search card is played." Implemented as *deck contents / what is prized*, since that is what a deck search reveals.

### Next work
5. **Improve the policy where the demo says it is weak.** Chiefly: it leaves the Supporter slot unspent in most misses, never plays Pokegear 3.0, never uses Run Errand, and never takes the Cursed Blast escape. The lead order and Ciphermaniac's timing also still need to become **parameters rather than constants**, since Kevin deferred both to the logs.
6. **Part 6 — the registry** over 10,000 replicates per (decklist, scenario, first/second) cell.
7. **Wire the smoke script into the test runner.** It is the only end-to-end hand-played line and nothing currently runs it automatically.

### Hypotheses to test rather than assume
8. **Getting Bronzong *Active* is the suspected bottleneck**, not drawing it — Salvatore fixes timing, not positioning. With the real policy the unmet tally over 1,000 replicates a cell is A 95 / B 284 / C 347 / D 468 going second, so C is the most-unmet of the three that are not the attack cost itself. Still not conclusive: D is inflated because it can only be met once B and C are.
8a. **The §3 lead order** — deferred to the logs by Kevin, and `lead_hit_df` is the table that settles it. First real reading disagrees with §3 twice: Mega Kangaskhan ex, its recommended non-Bronzor lead, is near the bottom (39.5%), and Latias ex, which §3 leads only as a last resort, is the best non-Bronzor lead (62.5%, n=32). Both readings are contaminated — the policy never uses Run Errand, so Kangaskhan is judged with its upside off.
8b. **Ciphermaniac's on `P2T1`** — legal only there, and Kevin expects the right answer to depend on the board and hand. Logged as a decision, to be judged from traces.
9. **The Bronzor printing trade-off.** Poffin caps at 70 HP, so it cannot fetch TEF 68 (80) but can fetch PRE 66 (70) and SSP 126 (60) — at the cost of those being Metal, so Telepathic Psychic Energy can no longer find them. A 2/2 split keeps both routes.
10. **Surfer competes with Salvatore for the one Supporter slot**, so Switch (an Item) is better for the turn-1 line — Kevin agreed, adding the simpler reason that no decklist runs Surfer at all. Live again only if a Surfer list is added.

### Loose ends
11. **`Mystery Garden` is modelled as inert but is not.** Its text is a live turn-1/2 draw effect. In no decklist yet, so it only bites when added as a candidate. **Rare Candy was the same error and has been fixed** (2026-08-29) — worth re-reading the whole "inert for turns 1–2" list in `R/card_effects_claude.R` with the lesson in mind: *inert* is a claim about every line a card appears in, not about its headline use.
12. **Nighttime Mine's effect text is uncorroborated** and looks implausible (hoses Tera Pokémon; no list runs Tera). decklist1 only, inert for the metric either way.
13. **The Salvatore first-turn ruling has no citable public source** (ADR 0001) — Kevin's expertise is the citation. Residual risk only.
