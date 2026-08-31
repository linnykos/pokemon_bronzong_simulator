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

Parts 1-5 are done and **part 6 has started**: `results/registry.md` scores all
**eight** decklists across all three cells. Kevin has now answered two full
scenario banks (S-01 to S-26) and the policy is aligned to both.

**decklist2, 1,000 replicates: 77.8% going second, 63.9% going first, 61.2%
`item_lock` going first.** The second bank was worth **1.7 points** against the
first bank's 23 — the shape of a policy that is mostly right. Per-change
attribution is in `results/change_attribution.md`, and the number to read there
first is the **noise floor**: at 1,000 paired replicates the standard error on a
difference is 0.2-0.4 points, so most rows are honestly zero.

**The registry's headline: decklist5, decklist7 and decklist8 are level at the top**, and
decklist1 is far worst in every cell. See *Open Questions* below.

**The decision documents are the specification and the code follows them**
(`CLAUDE.md` → *The decision documents are the specification*). Kevin edits
`docs/03_decision_tree.md` and `docs/03a_card_playbook.md`; `/align-decision-tree`
brings `R/decision_claude.R` back into line afterwards. As of 2026-08-30 the two
agree, and both files are **present-tense only** — the evolution of a rule lives
in `HISTORY_kevin.md`, or in an ADR the document cites by number.

- **Part 1 — rules (done).** `docs/01_rules_standard.md`.
- **Part 2 — card text (done).** **47 files** in `docs/cards/` covering 45 distinct cards, indexed by `docs/02_cards.md`. The count matrix is now **generated** by `scripts/refresh_card_index_claude.R`, which also checks coverage in **both directions** — every database row has a file and every file has a row — and a test runs the same check unprompted. Ten cards were added on 2026-08-30 for decklist7 and decklist8.
- **Part 3 — decision tree (the specification, present-tense).** §9 is the open-question register: **14 `DT-nn`** (01, 07, 16, 18, 21, 23, 25-32 — with 03 and 24 struck as answered, 25 narrowed, and **28 to 32 raised by the alignment audit**) and **8 `PB-nn`** (01, 11, 12, 14, 15, 18-20 — with 04, 07, 09, 10, 13, 16 and 17 struck). `docs/03b_scenarios.md` is a fresh bank, **S-27 to S-39**, and it is the first bank to leave the going-second `clear` cell and the first to leave decklist2.
- **Part 4 — base simulator (done).** Eight files in `R/`. `play_gwynn()` was added 2026-08-30, the first new effect since the Cursed Blast work.
- **Tests (done).** `tests/run_tests_claude.R` runs **2080 assertions**, all passing, plus `scripts/smoke_test_claude.R`.
- **Part 5 — the policy.** `R/decision_claude.R`, a section-by-section translation of the decision tree. decklist2 went 19.5% (placeholder) → 52.6% → 75.8% → 77.5% → **77.8%** going second. A doc-section to function cross-reference sits at the top of the file, so editing a section says what to change. **The §3 lead order is now a parameter** (`LEAD_ORDER_LIST`), not a constant.
- **Demo (done).** `demo/demo_simulator_claude.Rmd`, knitted to `.md` and `.html` by `scripts/knit_rmd_claude.R`.
- **Part 6 — started.** `scripts/score_decklists_claude.R` writes `results/decklist_registry.csv`, `results/registry.md` and one trace file per decklist, over 24 cells at 1,000 replicates. The 10,000-replicate version is a parameter change, not new work.

Five rounds of agent audit found and fixed **~38 defects**, and this session found **16 more** — three by hand and thirteen from the `/align-decision-tree` pass, which reported **18 red and 28 green**. The classes worth remembering:

- **A diagnostic that is confidently wrong rather than absent** — four times now, and the newest is the worst variant because it **under**-reports: `unused_outs()` held the Bronzor printings as a literal of three ids, went blind to PBL 63, and reported *no unused out* with a Bronzor in hand. **Never hard-code a list of printings**; resolve by name at run time.
- **A guard evaluated once at the top of a sequence is not a guard on the sequence.** The §4.1 kill line checked it held a Salvatore on entry and then let the Items discard it; `.policy_bench_meowth()` checked a Supporter was wanted without checking one could still be played. Both fired only once an unrelated change made the sequence common.
- **A dormant predicate becomes expensive the moment a tuning change moves what it reads.** Three predicates read "in play" as "on the Bench", which was harmless while §3 ranked Latias ex **last** — and ADR 0008 had just moved it to **first going second**.
- **A defect that only exists on a decklist nobody had.** Six of the thirteen fixes are invisible on the first six lists and bite only on decklist7 and decklist8, which run two Bronzor printings, two Latias ex and a basic Darkness Energy. **A one-decklist test suite audits one decklist**; `.make_pair()` now takes a `decklist_name`.
- **A document can disagree with itself, and neither audit direction catches it.** §6's priority table numbered Lillie's ahead of Ciphermaniac's while §6's own prose argued the reverse; measured, the prose was right by 1.92 points. Both `/align-decision-tree` directions ask whether the code and the document agree; neither asks whether the document is internally consistent.

**Eight decklists in `decklists/`**, each a legal 60. The first six share a fixed shell and vary Salvatore (0/1), the `[P]` base, Switch 3-vs-4, Bronzor 2-vs-3, Ciphermaniac's 0/2/3 and the Stadium. **decklist7 and decklist8 are a different deck**, not a variation: no Mega Kangaskhan ex, no Boss's Orders, no Ciphermaniac's, Rare Candy cut to 1, and a Darkness sub-theme (Munkidori, basic Darkness Energy) plus Gwynn, Risky Ruins and Buddy-Buddy Poffin.

Candidate cards still in **no** list: Bronzor PRE 66, Bronzor SSP 126, Pokégear 3.0, Mystery Garden, Surfer, Brock's Scouting.

## Key Methodological Details

- **The target event is an attack, not a board state.** Bronzong TEF 69 must be *Active* with a `[P]` source attached and must actually attack. See `CONTEXT.md` → *Target event*.
- **Only two cards are `[P]` sources**: basic Psychic Energy (SVE 5 / MEE 5) and Telepathic Psychic Energy (POR 88). Enriching Energy provides `[C]` and **basic Darkness Energy (MEE 7) provides `[D]`** — neither qualifies, and the second is the newer trap, because it is a *basic* Energy card and looks like the real thing.
- **The transcription source has now mis-rendered an attack as an Ability three times**: Evolution Jammer, Itchy Pollen, and — 2026-08-30 — **Dunsparce JTG 120's Trading Places**, which limitlesstcg lists as an Ability while pokemon.com and Bulbapedia both give it as an attack costing `[C]`. As an Ability it would have been a free rung on the §4.3 ladder; as an attack it is Run Around's shape and a last resort. **Query a second, different source for anything that drives the tree.**
- **Blissey ex TWM 134 evolves from Chansey, and no decklist runs one.** It cannot be put into play in decklist7 or decklist8 by any route: Rare Candy is Basic → Stage 2, and Salvatore fetches a card that evolves from a Pokémon we control. A dead card in both lists, and a decklist question rather than a simulator one (S-37).
- **Buddy-Buddy Poffin cannot fetch a Bronzor in decklist7 or decklist8.** Both printings those lists run are 80 HP (TEF 68 and PBL 63) against Poffin's 70 HP cap, so its only legal targets there are Duskull, Buneary and Dunsparce — none of which advances sub-goal A (S-35).
- **Primary outcome is a fixed bar: Evolution Jammer on or before the player's own turn 2** (ADR 0004), identical going first and going second. Going first and going second are reported separately and never pooled (ADR 0002). Every replicate also records the *turn actually achieved*, which is the only place Salvatore's turn-1 speed appears.
- **The measured window is setup through the end of the player's own turn 2, and nothing past it is played or recorded** (ADR 0007). Separate from the ADR 0004 bar: the bar could have been turn 2 while the engine played on, and deliberately is not. In exchange the end-of-turn-2 board state is recorded in full — every zone, plus damage and the turn each Pokémon was played or evolved — so a doomed turn 2 must still be played properly.
- **The policy may not read prizes or deck order** (ADR 0003), which requires a belief state separate from ground truth, built in from the start. It constrains the **policy**, not the analysis: the trace records the prized cards, labelled as ground truth, because "both Bronzong prized" is what separates a variance miss from a decision defect. Three mechanics: deck contents unknown until the first deck search; deck order never known; the deck reshuffles unseen after every search, destroying order knowledge but not contents knowledge.
- **Four different cards are named "Bronzor"** since PBL 63 arrived with decklist7. Never write "Bronzor" without a set and number — and **never hard-code the list of printings**, which is exactly how `unused_outs()` went silently blind to PBL 63 and reported "no unused out" with a Bronzor in hand. Resolve by name at run time, as `.bronzor_ids()` does.
- **Buneary's Run Around costs `[C]`, i.e. the turn's Energy attachment**, and the Energy leaves with Buneary for the Bench. It is a last resort, not free positioning. Budew's Itchy Pollen costs no Energy, so the two §4.2 exceptions are not symmetric.
- **Retreating costs the retreat cost of the Pokémon *leaving* the Active spot.** Bronzor's retreat 3 does not obstruct promoting it; what matters is what is currently Active. Latias ex's Skyliner makes any *Basic* Active retreat free, and on turn 1 the Active is almost always a Basic — but **only a Basic**, which is why a Stage 1 Dusclops gets stuck.
- **The §3 lead order is measured, not asserted** (ADR 0008). `LEAD_ORDER_LIST` holds it and `scripts/tune_lead_order_claude.R` chooses it, by varying the order and reading the cell rate under common random numbers — **not** from `lead_hit_df`, which is confounded because the hand holding a Kangaskhan is not the hand holding a Duskull. Two findings: **the lead order is worth about a point**, against the 23 the Supporter rules moved; and going first, three candidate orders land within 0.22 points of each other, so that branch was **left unchanged** rather than fitted to noise.
- **A guard evaluated once at the top of a sequence is not a guard on the sequence.** Twice this session: the §4.1 kill line checked it held a Salvatore on entry and the free Items inside it then discarded the card, and `.policy_bench_meowth()` checked a Supporter was wanted without checking one could still be played. Both were latent for weeks and became common only when an unrelated change (a second Poké Pad; Gwynn taking the slot) made the sequence frequent.
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
0. **Read `results/registry_notes.md` first**, then `results/registry.md`. It is the answer to *which decklist*, and the honest version of that answer is **decklist5, decklist7 or decklist8**: at 1,000 replicates a gap under about 4 points is not resolved, and those three sit inside a 1-point band going second and lead in all three cells. What *is* resolved is decklist1's collapse, and its cause.
0a. **Then `results/alignment_attribution.md`**, which is what the `/align-decision-tree` pass was worth: decklist7 gained **1.4 to 1.6 points in every cell**, essentially all of it from one fix — the want-list wanting a Latias ex it did not need whenever a **Bronzor** was Active. decklist2 did not move, and that is attributed rather than merely observed.
1. **Work through the new `docs/03b_scenarios.md`** — 13 positions, **S-27 to S-39**, the tree's own answer held back to appendix A. This bank is the first to leave the going-second `clear` cell and the first to leave decklist2. **Answer in frequency order**: S-33 (turn 2 under the Item lock) arises in **30.8%** of games, S-36 (Risky Ruins) 21.0%, S-35 (a Poffin that cannot fetch a Bronzor) 15.2%, S-37 (Blissey ex) 12.6%. **Read S-39 out of order** at 3.8%: it is this bank's S-20, the one that found something the tree is getting *wrong* rather than merely leaving open.
2. **Two decklist questions, not policy questions.** In decklist7 and decklist8: **Blissey ex cannot be played at all** (it evolves from Chansey and neither list runs one), and **Buddy-Buddy Poffin cannot fetch a Bronzor** (both printings there are 80 HP against its 70 HP cap). That is four of sixty cards doing nothing in decklist7. S-35 and S-37 pose both.
3. **Rule on DT-27, which decklist7 raised.** Gwynn draws up to 6 and keeps the hand; Lillie's draws 8 and shuffles the hand away. The tree currently plays **Gwynn when Lillie's would bury a piece the turn still needs** — a Bronzong, a `[P]` source, or a Switch while C is open — and Lillie's otherwise. That is a default, not a ruling. **S-27 poses it.**
4. **Two places I did not follow the letter of your answers**, both flagged rather than buried: **S-19's Supporter** (you named Ciphermaniac's; the fallback still prefers Salvatore, because a stack is two cards the window never draws while Salvatore is a second Bronzong on the board — now **DT-26**, and **S-28** poses it); and **DT-23's other half** (you ruled on the turn already *won*; the turn already *lost* is written into §8 as a proposal — **S-29** poses it).
5. **Sign off the `CONTEXT.md` coinages** — *on time*, *earliest legal turn*, *shell*, *whiff*, *cell*, and the three added 2026-08-30: *settled*, *lead order*, *registry*.
6. **Decide the mulligan-bonus divergence.** The opening hand omits the bonus cards owed for an opponent's mulligans, because no opponent is modelled. Biases consistency **downward** by an unknown amount. Fixing it means modelling an opposing decklist or assuming a distribution.
7. **Confirm one wording in ADR 0003.** Kevin wrote "should NOT immediately know what's benched before the first deck-search card is played." Implemented as *deck contents / what is prized*, since that is what a deck search reveals.

### Next work
8. **Re-run the registry at 10,000 replicates.** One constant in `scripts/score_decklists_claude.R`. It is the only way to separate the top three, and it is the highest-value remaining task by a distance.
9. **The three specified-and-not-implemented cards** (`docs/03a_card_playbook.md`): Dunsparce's Trading Places, Dudunsparce's Run Away Draw, and basic Darkness Energy as Run Around's cheapest payment. All three arrived with decklist8 and each biases its rate **downward**, so decklist8's number is a lower bound until they are done.
10. **The gaps the demo still lists.** Pokégear 3.0 is never played, and a **paid** retreat is never considered even when the Energy spent was going to waste.
11. **Wire the smoke script into the test runner.** It is the only end-to-end hand-played line and nothing currently runs it automatically.
12. **Re-tune the lead order after any change that alters what a turn can do** (ADR 0008). A lead is only as good as the plays the policy knows how to make from it — Kangaskhan sat at 40.9% until Run Errand was implemented and then reached 55.8%, on the same sixty cards.

### Hypotheses to test rather than assume
13. **Sub-goal D is the largest unmet count in all 24 registry cells**, and §1 still claims **C** is the one that actually fails. decklist2 going second is now **A 43 / B 137 / C 159 / D 201**, and the shape has survived the rate rising twenty-five points. The claim is not refuted — D can only be *unmet* once B and C are met, so it inherits their failures — but it is worth deciding rather than leaving open. **S-38 poses it.**
14. **The `[P]` base is an A question wearing a D costume.** decklist1 is the only list with no Telepathic Psychic Energy, and its **sub-goal A fails 102 times against decklist2's 43** on the same two Bronzor. A basic Psychic Energy pays D and does nothing else; a Telepathic pays D *and* searches two Basic `[P]` Pokémon onto the Bench, which is A's cheapest out and costs no card. That one substitution is worth 18.4 points going second and **20.5 under the Item lock**.
15. **Salvatore buys turn-1 kills and almost no rate**, which is the primary outcome working as designed (ADR 0004). The two lists without it are the only two with a turn-1 count of zero; every other list lands between 29 and 41 in 1,000 games. Its value has to be argued from the turn-1 column, not the hit rate.
16. **The Bronzor printing trade-off is now live rather than hypothetical.** decklist7 and decklist8 run TEF 68 (Psychic/80) alongside **PBL 63 (Metal/80)** — the printing that fetches worst, since 80 HP is over Poffin's cap *and* Metal is off Telepathic's list. A 2/2 split with PRE 66 (70) or SSP 126 (60) keeps both routes and no list runs one.
17. **Surfer competes with Salvatore for the one Supporter slot**, so Switch (an Item) is better for the turn-1 line — and no decklist runs Surfer at all. Live again only if a Surfer list is added.

### Loose ends
18. **`Mystery Garden` is modelled as inert but is not.** Its text is a live turn-1/2 draw effect. In no decklist yet, so it only bites when added. **Rare Candy was the same error and has been fixed** — worth re-reading the whole "inert for turns 1–2" list in `R/card_effects_claude.R` with the lesson in mind: *inert* is a claim about every line a card appears in, not about its headline use. **Risky Ruins is the newest member of this family**, and it is inert only for as long as §4.2 step 7 keeps declining to play it.
19. **Nighttime Mine's effect text is uncorroborated** and looks implausible (hoses Tera Pokémon; no list runs Tera). decklist1 only, inert for the metric either way.
20. **The Salvatore first-turn ruling has no citable public source** (ADR 0001) — Kevin's expertise is the citation. Residual risk only.
21. **A neutralising patch that silently matches nothing reads as a change that costs nothing.** The first attribution run reported ten of thirteen changes as worth 0.0, because multiline `perl` patterns written with `\n` do not match a **CRLF** source and `perl` still exits 0. `scripts/attribute_changes_claude.R` now does exact line-block substitution in R and **stops** unless the block matched exactly once. Same family as the confidently-wrong diagnostics this project has hit three times.
22. **A shell heredoc silently ate a backslash** while writing an R regex into a test — `"\\1-\\2"` arrived as `"\1-\2"` — and the test then failed with a substitution that had matched nothing. Write anything containing backslashes with the file-writing tools, not `cat <<'EOF'`.
