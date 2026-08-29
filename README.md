# pokemon_bronzong_simulator

Simulating Pokémon TCG opening hands and early-turn play in R, to optimize a
Bronzong / Lopunny / Dusknoir list for how consistently it reaches the
**Evolution Jammer** attack on the earliest legal turn.

## Where things are

| File | What it holds |
|---|---|
| `CLAUDE.md` | How the project is organized and how to work in it. **Start here.** |
| `CONTEXT.md` | Glossary — what this project's words mean |
| `docs/adr/` | Numbered decision records — the choices that were expensive to make |
| `docs/01_rules_standard.md` | Standard-format rules model |
| `docs/02_cards.md` | Card index + count matrix across the decklists |
| `docs/cards/` | Verbatim card text, one file per card |
| `decklists/` | Candidate 60-card lists |
| `HISTORY_kevin.md` | Append-only session log — how the ideas got here |

## Status

Parts 1–2 (rules model, card text) are complete. Parts 3–6 (decision tree,
simulator, policy, decklist registry) are not started. Current state is in
`CLAUDE_kevin.md`.

## Running R

R 4.6.1 is not on `PATH`. Resolve the `R_BIN` location from your own
`CLAUDE_[name].md`; on Kevin's desktop that is:

```bash
"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/<script>.R
```

## Contributing

Each collaborator owns their own `CLAUDE_[name].md` and `HISTORY_[name].md` and
writes only those. After cloning, enable the large-file guard once:

```bash
git config core.hooksPath .githooks
```
