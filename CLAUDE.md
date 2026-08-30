# CLAUDE.md — Pokémon TCG Bronzong Simulator

## Workflow Instructions
1. **Always enter plan mode** before starting any non-trivial task.
2. **Use superpower skills** where relevant: `/code-review` for code changes, `/r-style-guide` before writing or editing any `.R` file, `/domain-modeling` when recording a hard-to-reverse decision.
3. **After every prompt**, run `/project-state`: refresh the current-state sections of the individual contributor's `CLAUDE_[name].md` in place, and append a dated entry to their `HISTORY_[name].md`. Write only non-obvious things; skip anything already in the code or git history.

## Project Context (High Level)
**Paper/Project**: An R simulator for Pokémon TCG opening hands and early-turn play, used to optimize a 60-card Bronzong / Lopunny / Dusknoir decklist for how consistently it reaches the Evolution Jammer attack on the earliest legal turn.
**Authors**: Kevin Lin (sole author; deck designer and analyst).
**Goal**: Over many simulated games, what fraction of the time can the player attack with Evolution Jammer on **the earliest turn legal for that decklist and coin flip**? Compare that number across candidate 60-card lists to choose a list.

This is not a research project. The usual lab conventions (papers, grants, literature wikis) do not apply. R style still follows `/r-style-guide`.

### The target event
**Evolution Jammer is an attack, not an Ability.** Bronzong (TEF #69, reg H) must be **Active** with one `[P]` Energy attached — basic Psychic or Telepathic Psychic. Enriching Energy provides `[C]` and does **not** qualify.

### The metric
**Primary outcome: did the player attack with Evolution Jammer on or before their own turn 2?** One fixed bar, the same going first and going second, the same for every decklist (ADR 0004). Going first, turn 2 was always the floor anyway — the first player may play no Supporter and may not attack. Going second, this counts a turn-1 Salvatore kill and a turn-2 conventional line as the same success, on purpose, so Salvatore and non-Salvatore lists stay comparable.

**Going first and going second are reported separately and never pooled** (ADR 0002). Every replicate also records the **turn actually achieved**, which is where Salvatore's turn-1 speed shows up — the primary outcome is deliberately not designed to price it.

**Mulligans never count as a miss** (ADR 0005). A hand with no Basic is redrawn and the redraw is played; a replicate that mulliganed twice and then hit on turn 2 is a hit. The cost of mulliganing is reported as two **orthogonal** metrics beside the hit rate — `mulligan_rate` and `mean_mulligans` — never folded into it.

### Two outputs, for two different questions
| Output | Answers | Covers |
|---|---|---|
| **Rate** — one number per cell | *which decklist is better* | every replicate |
| **Traces** — `results/*_traces.txt` | *should the decision tree change* | a small stratified sample (ADR 0006) |

Traces are **deliberately over-weighted toward misses** and are therefore not representative of the outcome distribution — **never compute a rate from a trace file**. Each carries `blocking_subgoal` (which of the four sub-goals in `docs/03_decision_tree.md` §1 was unmet) and `unused_out_vec` (outs still sitting in hand). A miss blocked on sub-goal C with a Switch in hand is a **decision** defect: fix `docs/03_decision_tree.md`, not the 60 cards.

For reference, the earliest turn on which the event is *possible* — a property of the game, not the metric:

| | Salvatore lists | No-Salvatore lists |
|---|---|---|
| **Going second** | turn 1 | turn 2 |
| **Going first** | turn 2 | turn 2 |

### Scenarios
Every decklist is evaluated under named scenarios, crossed with going first vs. second:

| Scenario | Opponent behaviour |
|----------|--------------------|
| `clear` | Opponent does nothing. Baseline consistency of the list in isolation. |
| `item_lock` | Opponent leads Budew and attacks with Itchy Pollen, locking our Items on our next turn. Only possible when the opponent went **second**, since Itchy Pollen is an attack. |

## Repository Layout
Paths here are relative to the project root and are the same for everyone.

| Path | Contents |
|------|----------|
| `docs/01_rules_standard.md` | Standard-format rules reference (part 1) |
| `docs/02_cards.md` | Card index + cross-decklist count matrix |
| `docs/cards/` | Verbatim card text, one file per card (part 2) |
| `docs/03_decision_tree.md` | English decision tree for turns 1–2 (part 3). §10 is the open-question register (`DT-nn`) |
| `docs/03a_card_playbook.md` | Per-card rules, and the `PB-nn` question register |
| `docs/03b_scenarios.md` | Board positions for Kevin to answer, with the tree's own answer held back to appendix A |
| `docs/adr/` | Numbered decision records — the evolution of the project's ideas |
| `CONTEXT.md` | Shared glossary: what this project's words mean |
| `R/` | Simulator source (parts 4–5) — *not yet written* |
| `decklists/` | Candidate 60-card lists, one `.txt` each, PTCG-Live export format |
| `results/` | Per-decklist simulation results and the run registry (part 6) |
| `scripts/` | Entry points |
| `tests/testthat/` | Tests |
| `additional_context/` | Reference material + `summary.md` index |

## External Locations
Folders this project depends on that live **outside** the project root.

**No per-machine filesystem path appears in this file.** This file names each location and says what it is for; the path — and which machine it is on — is recorded per person in `CLAUDE_[name].md` under *External Locations (per-machine paths)*. Hostnames and URIs that are the same for everyone are fine here.

| Location name | Purpose | Copy semantics |
|---|---|---|
| `R_BIN` | The R installation's `bin/` directory, holding `Rscript`. R is **not on `PATH`** on the author's machine, so scripts are invoked through this location. | per-person copy — independent |
| `PANDOC` | A `pandoc` executable, used by `scripts/knit_rmd_claude.R` to turn the knitted `demo/*.md` into `.html`. Optional: without it the `.md` is still produced, and the `.md` is the artefact that matters. | per-person copy — independent |

Git remote (same for everyone): `https://github.com/linnykos/pokemon_bronzong_simulator.git`

Refer to these locations by name in prose, code comments, and session notes. To resolve a name to a real path, read the current user's `CLAUDE_[name].md`. If that person has no row for the location, ask them — do not guess, and do not reuse another collaborator's path.

## Who Is Using This Session?
**Detect the current user** by running `echo $USER`. This table maps each login to that person's **first-name** context file.

| Username (login) | Current-state file (first name) | History archive |
|---|---|---|
| `kevinlin`, `klin1` | `CLAUDE_kevin.md` | `HISTORY_kevin.md` |

**File ownership.** Each row above names one person's files, and **only that person's session writes them.** Once `$USER` resolves to a first name, that is the only suffix you may create, edit, append to, rename, or delete — every other collaborator's per-person files are read-only. Read them for context when useful; never modify them. This master `CLAUDE.md` is the exception: it is shared and any collaborator may update it. The single override is the user, in the current turn, directing you to write that exact file — confirm once, then write it.

**Session startup — run this before any other work.** All four cases below are normal; none is an error to report back to the user.

1. Run `echo $USER` and look for a matching row. On Windows, `$USER` is often empty — fall back to `$USERNAME`, or to the working-directory owner.
2. **Row exists and the file exists** → read that person's `CLAUDE_[name].md` immediately. Do **not** read `HISTORY_[name].md` at startup; it is the append-only session log, consulted only on demand.
3. **Row exists but `CLAUDE_[name].md` does not** → initialize `CLAUDE_[name].md` and `HISTORY_[name].md` via `/project-state`, then continue.
4. **No matching row** → ask the user their first name, add a row to the table above, then initialize their files as in case 3. Never guess a first name from the login.

## Shared vocabulary and decisions
- **`CONTEXT.md`** (project root) is the glossary — what this project's words mean. Read it before using a term like *turn*, *Bronzor*, *`[P]` source*, or *cell*; several of them are ambiguous in ordinary Pokémon TCG usage. Update it via `/domain-modeling` when a term settles.
- **`docs/adr/`** holds numbered decision records — the choices that were expensive to make and would be surprising without context. Seven exist; read them before revisiting the metric, the Salvatore ruling, the information-hiding rule, or the length of the measured window.

## The decision documents are the specification

**Kevin edits `docs/03_decision_tree.md` and `docs/03a_card_playbook.md`. He does not
edit the R.** Those two files are the specification; `R/decision_claude.R` is a
translation of them, and after any edit the **code is brought back into line with the
documents**, never the reverse.

What that means in practice:

- **A disagreement between the two is a code defect by default.** Fix the policy, and
  add a test citing the section it came from, so a later edit to that section fails
  loudly instead of drifting.
- **The exception is a behaviour the documents do not describe at all.** Do not
  silently delete it and do not silently keep it — propose the wording and let Kevin
  decide, because the documents are his.
- **`R/decision_claude.R` opens with a section → function table.** Keep it current; it
  is what makes "§4.3 changed, so `.policy_position()` changes" a lookup rather than a
  search.
- **Run `/align-decision-tree`** after any edit to either document. It audits both
  directions, fixes the code, adds the tests, and drafts the document wording for
  anything the code does that the documents do not yet say.
- **Run `/generate-scenarios`** when a rule is a default rather than a ruling. It
  turns the `DT-nn` and `PB-nn` questions into real board positions in
  `docs/03b_scenarios.md`, each with the frequency it arises at, so Kevin answers
  the ones that matter first.

## Ground rules for this project
- **Never invent card text.** Every card in `docs/cards/` is transcribed from a primary source (limitlesstcg.com, Bulbapedia, pokemon.com) with the set code, number, and regulation mark recorded, and the verification date noted. If a card cannot be verified it is marked `[UNVERIFIED]` rather than guessed. The transcription source has twice mis-rendered an **attack** as an **Ability** — re-query with a pointed question for any card whose details drive the decision tree.
- **Never let the decision logic peek at hidden information.** Prizes and deck order are hidden from the player. The simulator's policy code may only read what a real player would know at that moment. A search that fails because the card is prized is *information the player earns*, not something the policy may assume. This is the easiest way to produce a silently wrong consistency number.
- **Turn numbering is per player.** `P2T2` means the second player's second turn. See `docs/01_rules_standard.md` §6.
- Standard 2026 legality = regulation mark **H**, **I**, or **J**.
- New R files drafted by Claude are named with a `_claude` suffix so Kevin can review before integrating.

## Post-Prompt Update Instructions
After completing each user prompt, run `/project-state`. It will:
- **Refresh in place** the current-state sections of `CLAUDE_[name].md` (Project Status, Key Methodological Details, Open Questions / Next Steps).
- **Append a dated entry at the bottom** of `HISTORY_[name].md` recording new decisions, resolved/open questions, non-obvious rationale, and empirical findings.

Do NOT record: things already in the code, git history, or reproducible from code.
