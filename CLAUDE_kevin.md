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

Parts 1 and 2 of the six-part plan are complete; part 3 has not been started.

- **Part 1 — rules (done).** `docs/01_rules_standard.md` covers Standard 2026 legality, deck construction, the full setup sequence, turn structure and per-turn limits, evolution timing, first-turn restrictions, and §5.1's derivation of the earliest possible Evolution Jammer.
- **Part 2 — card text (done).** 35 files in `docs/cards/` covering 34 distinct cards, indexed by `docs/02_cards.md` with a count matrix across all six decklists. Coverage and the matrix are both verified by script against the decklists, not by eye.
- **Parts 3–6 — not started.** Decision tree, simulator, policy, and the decklist registry.

Six decklists in `decklists/`, each a legal 60. Two exact duplicates (old 7 and 8) were removed. The lists share a fixed 16-card shell; the live variables are Salvatore (0/1), the `[P]` energy base, Switch 3-vs-4, Bronzor 2-vs-3, Ciphermaniac's 0/2/3, and the stadium slot.

Four cards are imported as **candidates not yet in any list**: Buddy-Buddy Poffin, Bronzor PRE 66, Bronzor SSP 126, Pokégear 3.0, Mystery Garden.

## Key Methodological Details

- **The target event is an attack, not a board state.** Bronzong TEF 69 must be *Active* with a `[P]` source attached and must actually attack. See `CONTEXT.md` → *Target event*.
- **Only two cards are `[P]` sources**: basic Psychic Energy (SVE 5 / MEE 5) and Telepathic Psychic Energy (POR 88). Enriching Energy provides `[C]` and does not qualify.
- **Earliest legal turn is per-cell, not constant** — turn 1 for a Salvatore list going second, turn 2 otherwise (ADR 0001, 0002).
- **The policy may not read prizes or deck order** (ADR 0003). This requires a belief state separate from ground truth, built in from the start.
- **Three different cards are named "Bronzor."** Never write "Bronzor" without a set and number.
- **Retreating costs the retreat cost of the Pokémon *leaving* the Active spot.** Bronzor's retreat 3 does not obstruct promoting it; what matters is what is currently Active. Latias ex's Skyliner makes any *Basic* Active retreat free, and on turn 1 the Active is almost always a Basic.
- **The transcription source mis-renders attacks as Abilities.** It did so for Evolution Jammer and Itchy Pollen. Any card whose details drive the decision tree gets a second, pointed query.
- **Base R only.** R 4.6.1 has no jsonlite, yaml, testthat, or tidyverse installed. The simulator is being written dependency-free; adding `testthat` for part 4 is an open offer, not a decision.

## Open Questions / Next Steps

1. **Write part 3** — the English decision tree for turns 1–2. Structure it as four branches: going first vs. second, crossed with Salvatore vs. no Salvatore, since those produce genuinely different play patterns.
2. **Getting Bronzong *Active* is the suspected bottleneck**, not drawing it — Salvatore fixes timing but not positioning. Confirm this in the sim rather than assuming it.
3. **Open: the Salvatore first-turn ruling has no citable source** (ADR 0001). Kevin confirmed it; an official ruling in `additional_context/` would retire the risk.
4. **Open: Nighttime Mine's effect text is uncorroborated** and looks implausible (hoses Tera Pokémon; no list runs Tera). decklist1 only, and inert for the metric either way.
5. **Open: the Bronzor printing trade-off is unmeasured.** Buddy-Buddy Poffin caps at 70 HP, so it cannot fetch Bronzor TEF 68 (80 HP) but can fetch PRE 66 (70) and SSP 126 (60) — at the cost of those being Metal, so Telepathic Psychic Energy can no longer find them. A 2/2 split keeps both routes and is its own candidate.
6. **Open: whether to install `testthat`** for part 4's tests, or hand-roll assertions in base R.
7. **Open: `CONTEXT.md` coinages need sign-off** — *on time*, *by turn 2*, *shell*, *whiff*, and *cell* are Claude's terms, marked `[unconfirmed]` in that file.
