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

Invocation from the Git Bash shell used in these sessions:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/<script>.R
```

## Project Status (as of 2026-08-29)

Parts 1, 2 and 4 are done; part 3 is drafted and awaiting Kevin's review; parts 5 and 6 are not started.

- **Part 1 — rules (done).** `docs/01_rules_standard.md`.
- **Part 2 — card text (done).** 37 files in `docs/cards/` covering 36 distinct cards, indexed by `docs/02_cards.md` with a count matrix across all six decklists. Coverage and the matrix are verified by script, not by eye.
- **Part 3 — decision tree (drafted, needs review).** `docs/03_decision_tree.md` and `docs/03a_card_playbook.md`. Each ends with numbered questions for Kevin.
- **Part 4 — base simulator (done).** Seven files in `R/`: card database, decklist parsing, game state, belief state, rules, setup, card effects. No Monte Carlo and no policy yet, by design.
- **Tests (done).** `tests/run_tests_claude.R` runs **1517 assertions**, all passing, plus `scripts/smoke_test_claude.R`. testthat is not installable here, so `tests/testthat_shim_claude.R` provides a testthat-compatible harness; the test files use testthat's real API so `devtools::test()` will run them unchanged once testthat exists.
- **Parts 5–6 — not started.** Policy, and the decklist registry over 10,000 replicates.

Three rounds of agent audit found and fixed **~30 defects**. The classes worth remembering: silent card loss through zones nobody counted, belief-state staleness, unbounded search targets, and metrics that measured availability rather than action.

Six decklists in `decklists/`, each a legal 60. They share a fixed 16-card shell; the live variables are Salvatore (0/1), the `[P]` energy base, Switch 3-vs-4, Bronzor 2-vs-3, Ciphermaniac's 0/2/3, and the stadium slot.

Six cards are imported as **candidates not yet in any list**: Buddy-Buddy Poffin, Bronzor PRE 66, Bronzor SSP 126, Pokégear 3.0, Mystery Garden, Surfer, plus Brock's Scouting.

## Key Methodological Details

- **The target event is an attack, not a board state.** Bronzong TEF 69 must be *Active* with a `[P]` source attached and must actually attack. See `CONTEXT.md` → *Target event*.
- **Only two cards are `[P]` sources**: basic Psychic Energy (SVE 5 / MEE 5) and Telepathic Psychic Energy (POR 88). Enriching Energy provides `[C]` and does not qualify.
- **Primary outcome is a fixed bar: Evolution Jammer on or before the player's own turn 2** (ADR 0004), identical going first and going second. Going first and going second are reported separately and never pooled (ADR 0002). Every replicate also records the *turn actually achieved*, which is the only place Salvatore's turn-1 speed appears.
- **The policy may not read prizes or deck order** (ADR 0003), which requires a belief state separate from ground truth, built in from the start. Three mechanics: deck contents unknown until the first deck search; deck order never known; the deck reshuffles unseen after every search, destroying order knowledge but not contents knowledge.
- **Three different cards are named "Bronzor."** Never write "Bronzor" without a set and number.
- **Retreating costs the retreat cost of the Pokémon *leaving* the Active spot.** Bronzor's retreat 3 does not obstruct promoting it; what matters is what is currently Active. Latias ex's Skyliner makes any *Basic* Active retreat free, and on turn 1 the Active is almost always a Basic.
- **The transcription source mis-renders attacks as Abilities.** It did so for Evolution Jammer and Itchy Pollen. Any card whose details drive the decision tree gets a second, pointed query.
- **Base R only.** R 4.6.1 has no jsonlite, yaml, testthat, or tidyverse installed. The simulator is dependency-free. testthat cannot be installed here (R has no CRAN access), so `tests/testthat_shim_claude.R` stands in; the test files use testthat's real API and will run unchanged under `devtools::test()` if testthat ever becomes available.

## Open Questions / Next Steps

### Needs Kevin
1. **Review part 3.** `docs/03_decision_tree.md` and `docs/03a_card_playbook.md` each end with numbered questions — lead order at setup, Switch-vs-Surfer for the turn-1 kill, whether Ciphermaniac's is ever right on turn 1, the Ultra Ball discard priority, and whether to record turn-3 outcomes.
2. **Sign off the `CONTEXT.md` coinages** — *on time*, *earliest legal turn*, *shell*, *whiff*, *cell*, marked `[unconfirmed]` in that file.
3. **Decide the mulligan-bonus divergence.** The opening hand omits the bonus cards owed for an opponent's mulligans, because no opponent is modelled. Biases consistency **downward** by an unknown amount. Fixing it means modelling an opposing decklist or assuming a distribution.
4. **Confirm one wording in ADR 0003.** Kevin wrote "should NOT immediately know what's benched before the first deck-search card is played." Implemented as *deck contents / what is prized*, since that is what a deck search reveals.

### Next work
5. **Part 5 — the policy.** A direct translation of part 3, so it waits on the review above.
6. **Part 6 — the registry** over 10,000 replicates per (decklist, scenario, first/second) cell.
7. **Wire the smoke script into the test runner.** It is the only end-to-end hand-played line and nothing currently runs it automatically.

### Hypotheses to test rather than assume
8. **Getting Bronzong *Active* is the suspected bottleneck**, not drawing it — Salvatore fixes timing, not positioning.
9. **The Bronzor printing trade-off.** Poffin caps at 70 HP, so it cannot fetch TEF 68 (80) but can fetch PRE 66 (70) and SSP 126 (60) — at the cost of those being Metal, so Telepathic Psychic Energy can no longer find them. A 2/2 split keeps both routes.
10. **Surfer competes with Salvatore for the one Supporter slot**, so Switch (an Item) is probably better for the turn-1 line.

### Loose ends
11. **`Mystery Garden` is modelled as inert but is not.** Its text is a live turn-1/2 draw effect. In no decklist yet, so it only bites when added as a candidate.
12. **Nighttime Mine's effect text is uncorroborated** and looks implausible (hoses Tera Pokémon; no list runs Tera). decklist1 only, inert for the metric either way.
13. **The Salvatore first-turn ruling has no citable public source** (ADR 0001) — Kevin's expertise is the citation. Residual risk only.
