# pokemon_bronzong_simulator

R simulator for Pokémon TCG opening hands and early-turn play, used to optimize a
60-card Bronzong / Lopunny / Dusknoir decklist for **consistency of reaching the
Evolution Jammer attack on the earliest legal turn**.

This is not a research project. The usual lab conventions (papers, wikis, grants)
do not apply here. R style still follows `r-style-guide`.

## The question being answered

Over many simulated games, what fraction of the time can the player attack with
Evolution Jammer on their **second turn** (the earliest legal turn — see
`docs/01_rules_standard.md` §5)? Compare that number across candidate 60-card
lists.

**Evolution Jammer is an attack, not an Ability.** Bronzong (TEF #69, reg H)
must be Active with one Psychic Energy attached. The Bronzor must have been in
play since setup or turn 1.

## Scenarios

Every decklist is evaluated under a set of named scenarios, crossed with going
first vs. going second:

| Scenario | Opponent behaviour |
|----------|--------------------|
| `clear` | Opponent does nothing. Baseline consistency of the list in isolation. |
| `item_lock` | Opponent leads Budew and uses Itchy Pollen, locking our Items on the turn it is Active. Only meaningful when we go first. |
| *(more to be added)* | Other disruption, e.g. a turn-1 Iono. |

Results are reported per (decklist, scenario, first/second) cell, not pooled.

## Layout

| Path | Contents |
|------|----------|
| `docs/01_rules_standard.md` | Standard-format rules reference (part 1) |
| `docs/cards/` | Verbatim card text, one file per card (part 2) |
| `docs/03_decision_tree.md` | English decision tree for turns 1–2 (part 3) |
| `R/` | Simulator source |
| `decklists/` | Candidate 60-card lists, one file each |
| `results/` | Per-decklist simulation results and the run registry (part 6) |
| `scripts/` | Entry points |
| `tests/testthat/` | Tests |

## Ground rules for this project

- **Never invent card text.** Every card in `docs/cards/` is transcribed from a
  primary source (limitlesstcg.com or pokemon.com) with the set code, number,
  and regulation mark recorded. If a card cannot be verified, it is marked
  `[UNVERIFIED]` rather than guessed.
- **Never let the decision logic peek at hidden information.** Prizes and deck
  order are hidden from the player. The simulator's policy code may only read
  what a real player would know at that moment. This is the easiest way to
  produce a silently wrong consistency number.
- **Turn numbering is per player.** `P2T2` means the second player's second
  turn. See `docs/01_rules_standard.md` §6.
- Standard 2026 legality = regulation mark **H**, **I**, or **J**.

## Environment

R 4.6.1, not on `PATH`. Invoke as:

```
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/<script>.R
```
