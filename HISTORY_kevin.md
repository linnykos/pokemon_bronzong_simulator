# HISTORY_kevin.md — Kevin's Session Log

> **Append-only, ascending chronological order** (oldest at top, newest at the bottom). Add each session's dated entry to the END of this file. Never read at session startup — consulted only on demand for deep history. Current project state lives in `CLAUDE_kevin.md`.
>
> **Owned by Kevin.** Only Kevin's session appends to this file. Other collaborators may read it but must not edit or rewrite entries.

---

### 2026-08-29 (Session 1 — project init and the rules model)

- Initialized the repo and wrote part 1, `docs/01_rules_standard.md`: Standard 2026 legality, deck construction, setup with mulligans, turn structure, evolution timing, first-turn restrictions.
- **Resolved: what "Evolution Jammer" actually is.** Started from the assumption it was a Bronzong *Ability*. It is an **attack** — `[P]`, 30 damage. This changes the target from "Bronzong in play" to "Bronzong Active, with a `[P]` Energy, actually attacking." The transcription source (Limitless via WebFetch) reported it as an Ability with an energy cost, which is self-contradictory; Bulbapedia settled it. **This became a standing rule: any card driving the decision tree gets a second, pointed query.** The same error later recurred on Budew's Itchy Pollen.
- **Resolved: Bronzong TEF 69 is Standard-legal.** I initially concluded it had rotated, reading a source that said regulation mark G covered "all Scarlet & Violet releases through Pokémon 151" and wrongly placing Temporal Forces inside that range. Kevin corrected it: TEF is **reg H**, since G *stops* at Pokémon 151 and TEF is later. Worth remembering as a failure mode — the source was accurate and I misapplied it.
- **Derived the earliest-possible-attack floor:** you cannot evolve on your own first turn, so a Stage 1 could not attack before turn 2. At this point the project's target was believed to be turn 2, full stop. Session 2 overturned this.
- Decided the opponent would be modelled as named **scenarios** rather than a full opposing deck; Kevin asked for both a do-nothing baseline and an Itchy-Pollen disruption case.
- Noted R 4.6.1 is installed but has only base packages, and is not on `PATH`.

### 2026-08-29 (Session 2 — card import, and the premise changing twice)

- Imported verbatim card text for every distinct card across what were then eight decklists. Coverage checked by exact set+number match rather than name matching, after a name-based heuristic produced false positives on accented and reformatted names.
- **Resolved: Salvatore (TEF 160) permits evolving on your first turn.** This was the session's big one. Salvatore's text plainly overrides "can't evolve a Pokémon played this turn"; whether it also overrides the separate first-turn ban decides whether the whole project measures turn 1 or turn 2. Public sources actively contradicted each other and none was authoritative, so I stopped and asked rather than guessing. Kevin confirmed it works. Recorded as **ADR 0001**, explicitly flagged as the one load-bearing rules fact with no citable source.
- **Decision: report per (decklist, scenario, first/second) cell and never pool** — ADR 0002. Follows directly from the above: the earliest legal turn is turn 1 for a Salvatore list going second and turn 2 in every other case, so a single pooled number per decklist averages two different questions and penalises Salvatore lists for the half of their games where Salvatore is unusable. Rejected the simpler one-number-per-list design for exactly that reason.
- **Resolved: Bronzong has no Ability**, which is what makes it a legal Salvatore target. Dusclops and Dusknoir both have Cursed Blast and can therefore *never* be fetched with Salvatore — a non-obvious asymmetry that shapes the turn-2 branch.
- Learned that **Telepathic Psychic Energy provides `[P]`** and its attach trigger searches 2 Basic `[P]` Pokémon onto the Bench, while **Enriching Energy provides `[C]`** and cannot pay for Evolution Jammer. Decklists 2–6 have no basic Energy at all, so their only `[P]` sources are 4 Telepathic Psychic — and Night Stretcher cannot recover those, since it retrieves only *Basic* Energy.
- Noticed the eight lists share a fixed 16-card shell, and that Salvatore is present in five and absent from three — i.e. Salvatore is the variable actually being tested, which is what made ADR 0001 worth stopping for.

### 2026-08-29 (Session 3 — dedup, candidate cards, and a self-correction)

- **Removed two duplicate decklists.** Old decklist7 was an exact reordering of decklist2 and decklist8 of decklist6 — identical card multisets, different line order. Detected by hashing the sorted card lines, then confirmed with a real diff before deleting. Six lists remain. This is why `CONTEXT.md` defines a **Decklist** by contents rather than filename.
- Imported five candidate cards not in any list: Buddy-Buddy Poffin, Bronzor PRE 66, Bronzor SSP 126, Pokégear 3.0 (BLK 84), Mystery Garden. Night Stretcher was already present as ASC 196.
- **Learned: "Bronzor" names three different cards**, not three printings of one. TEF 68 is Psychic/80 HP; PRE 66 is Metal/70; SSP 126 is Metal/60. All evolve into Bronzong TEF 69, so a list may mix them up to 4 total.
- **New axis to test:** Buddy-Buddy Poffin caps at "70 HP or less", so it **cannot fetch Bronzor TEF 68** (80 HP) but can fetch both Metal printings — at the cost that Telepathic Psychic Energy can then no longer find them, since they are not `[P]`. A 2/2 split preserves both search routes. This is a clean, measurable trade-off and belongs in part 6.
- **Corrected an error I had introduced in Session 1:** I had written that Bronzor's retreat cost of 3 made promoting it from the Bench impractical. Wrong — retreating costs the retreat cost of the Pokémon *leaving* the Active spot, so Bronzor's own cost is irrelevant to promoting it. Fixed in the rules doc and both Bronzong-line card files. The knock-on: **Latias ex's Skyliner is better than I had described**, since on turn 1 the Active is almost always a Basic and Skyliner makes that retreat free.
- Standing hypothesis for part 3, not yet tested: **positioning, not drawing, is the bottleneck** — Salvatore removes the timing constraint but evolves a Bronzor anywhere, so it does not get Bronzong Active.
- Open: Pokégear 3.0 is a *look at 7*, not a tutor, and it shuffles — so it can whiff, and playing it after a Ciphermaniac's Codebreaking would destroy the stacked top of deck. The policy must know not to.

### 2026-08-29 (Session 4 — project scaffolding and history tracking)

- Ran `/project-setup`, `/domain-modeling`, and `/project-state` at Kevin's request to put the collaboration scaffolding in place and start tracking how the project's ideas evolve.
- Rewrote the master `CLAUDE.md` onto the standard template; moved the R installation path out of it into this person-file as the `R_BIN` location, since a `C:\...` path is only true on one machine.
- Created `CONTEXT.md` as a glossary. The entries worth having are the ambiguous ones: **Turn** (per-player, not global), **Bronzor** (three cards, one name), **`[P]` source** (two cards, not all Energy), and **Decklist** (identified by contents, not filename). Five terms are Claude coinages marked `[unconfirmed]` and need Kevin's sign-off.
- Wrote three decision records — ADR 0001 (Salvatore premise), 0002 (per-cell reporting), 0003 (policy may not read hidden information). ADR 0003 was written now rather than at implementation time because retrofitting information-hiding onto a policy that reads ground truth is a rewrite, not a patch.
- Installed the standard `.gitignore` and the ≥50 MB pre-commit guard, and set `core.hooksPath`. Noted the GitHub remote `linnykos/pokemon_bronzong_simulator` already existed; did not create one.
- Open: `additional_context/` is empty by design so far — every source used was fetched live with its URL and date recorded at the point of use. The two things worth saving offline are an official Salvatore ruling and corroboration of Nighttime Mine's text.

### 2026-08-29 (Session 5 — ADR review, metric redefined, two Supporters imported)

- Kevin reviewed all three decision records and confirmed each. ADR 0001 reaffirmed with explicit confidence; recorded that his expertise, not a document, is the citation.
- **Decision: the primary outcome changed** — ADR 0004. I had proposed grading each cell against its *own* earliest legal turn, so a Salvatore list going second would be measured against turn 1 and everything else against turn 2. Kevin rejected that: the headline number then means a different thing per decklist and the lists stop being comparable. The metric is now a fixed bar — **Evolution Jammer on or before the player's own turn 2** — identical going first and going second. ADR 0002's stratification is unchanged and it now carries an "amended by 0004" note.
- The consequence worth remembering: this makes a turn-1 Salvatore kill and a turn-2 conventional line count as the *same* success. That is intentional, but it means Salvatore's genuine advantage — locking the opponent's evolutions a full turn earlier — is invisible in the primary metric. It has to be read off the recorded **turn achieved** and the turn-1 rate on the going-second cell.
- **ADR 0003 extended with three concrete mechanics** Kevin specified: deck contents are unknown until the first deck-search card is played; deck order is never known; and the deck reshuffles unseen after every search. The non-obvious part for implementation is the asymmetry — a shuffle destroys knowledge of **order** but not of **contents**, so the belief state cannot model "unknown" as a single flag.
- Open: Kevin's phrase was "should not immediately know what's benched before the first deck-search card is played." Implemented as deck contents / what is prized, since that is the knowledge a deck search confers. Flagged in ADR 0003 rather than silently assumed.
- **Imported Surfer** (SSP 187, reg H; also ASC 200): "Switch your Active Pokémon with 1 of your Benched Pokémon. If you do, draw cards until you have 5 cards in your hand." Aims straight at the suspected bottleneck. Two things the policy must get right: it is a *refill*, so the draw is `max(0, 5 - hand)` computed after the switch and after Surfer has left the hand — with a full hand it draws nothing; and it **competes with Salvatore for the one Supporter slot**, so going second with Bronzor benched the player cannot both switch and Salvatore-evolve. Switch, being an Item, does the positioning without spending the slot.
- **Brock's Training is unusable**, on two independent grounds: only printing is Hidden Fates 55 with no regulation mark and no legal reprint, and its effect targets Geodude/Graveler/Golem/Onix-GX/Cubone/Rhyhorn/Rhydon/Sudowoodo, none of which is in any list. Written up anyway so the question is not re-researched; the card file suggests Surfer as the card that does what was probably wanted.

### 2026-08-29 (Session 6 — decision drafts and the base simulator)

- Corrected the card request: **Brock's Scouting (JTG 146, reg I)**, not Brock's Training. Deleted the Brock's Training file. Scouting is "up to 2 Basic Pokemon **or** 1 Evolution Pokemon" to hand — two exclusive modes — and it is the **only free way to find Latias ex** (Poke Pad is blocked by the Rule Box, Poffin by the 210 HP, and only Ultra Ball otherwise reaches it, for two discards). In Basics mode it fetches Bronzor + Latias ex in one card, which is the exact pair the turn-1 line wants.
- Noted a consequence worth watching: the Supporter slot is now contested by **six** cards (Hilda, Salvatore, Lillie's, Brock's Scouting, Surfer, Ciphermaniac's) against one play per turn. Quantifying that contention is a part-6 job.
- **Wrote part 3** as two files. `docs/03_decision_tree.md` decomposes the target into four sub-goals (A: Bronzor in play, B: Bronzong on it, C: Bronzong **Active**, D: a `[P]` source attached), names the three resource conflicts, and gives the turn-by-turn procedure per branch. `docs/03a_card_playbook.md` is the per-card spec and maps directly onto the card-effect functions.
- The organising claim, recorded so it can be falsified rather than assumed: **sub-goal C is the one that fails.** A, B and D each have many redundant outs; C has few, and its cheapest out — leading Bronzor at setup — must be chosen before any card is drawn.
- **Built the base simulator** (no Monte Carlo, no policy): `cards_claude.R` (37 printings), `decklist_claude.R`, `game_state_claude.R`, `knowledge_claude.R`, `rules_claude.R`, `setup_claude.R`, `card_effects_claude.R`, plus `scripts/smoke_test_claude.R`.
- **Bug caught by the smoke test, worth remembering:** the decklist content-hash used a 32-bit FNV-1a, but R's `bitwXor` coerces to integer, so any accumulator above `.Machine$integer.max` silently became `NA`. Every decklist hashed to `dl_NA`, so the duplicate-detection dropped five of the six lists as "identical". Replaced with a polynomial rolling hash mod 2^31-1, whose widest intermediate stays under 2^53 and is therefore exact in double arithmetic. The failure mode is the dangerous kind — it looked like a working dedup.
- Design decision in the engine: every card-effect function takes and returns a `list(state, knowledge)` pair, because nearly every effect touches both — a search changes the board *and* teaches the player what is in the deck. Keeping them as one argument makes it hard to update one and forget the other.
- Search *targets* are chosen by the caller, not by the effect functions; the effects only enforce what each card may legally fetch. That is what will let part 5's policy be rewritten without touching the rules.
- Smoke test asserts the ADR 0003 guarantee directly: a prized card is believed findable before any search, exactly 6 cards are deduced unavailable after one, and a shuffle clears deck *order* knowledge while leaving *contents* knowledge intact.
- Open: the two draft docs end with numbered questions for Kevin — lead order at setup, Switch-vs-Surfer for the turn-1 kill, whether Ciphermaniac's is ever right on turn 1, the Ultra Ball discard priority, and whether to record turn-3 outcomes at all.

### 2026-08-29 (Session 7 — unit tests and three audit agents)

- Wrote the test suite: **1346 assertions** across six files under `tests/testthat/`, plus a runner. testthat could not be installed (R has no CRAN access here), so `tests/testthat_shim_claude.R` provides a testthat-**compatible** harness; the test files call testthat's real API bare, so deleting the shim and running `devtools::test()` will work unchanged once testthat exists.
- **The tests caught a bug on their first run:** `read_decklist()` asserted `verbose >= 0` while `read_decklist_dir()` passes `verbose - 1`, so the default call path failed its own precondition. Exactly the trap the R style guide warns about.
- Ran three audit agents in parallel: correctness, spec-alignment, and test-coverage. The third was stopped before reporting.
- **Spec-alignment agent — six real defects**, all fixed. Most consequential: Buneary's Run Around attacked with **zero Energy** (it costs `[C]`), which made sub-goal C free on every going-second replicate; and the belief state **snapshotted** deck contents at search time and never updated them. The snapshot failed in both directions — believing a card was still in the deck after drawing it, and believing a card was gone after Lillie's shuffled it back in from hand. Deck contents are now **derived** (`decklist - visible - known-prized`) rather than stored, since prizes are the only fact a search establishes that cannot change mid-game. Also: attacking did not end the turn, Run Errand had no once-per-turn limit, Salvatore was playable with the target fully discarded, and Stadiums/Itchy Pollen had no effect functions.
- **Correctness agent — nine more defects**, including **two I introduced with the spec fixes**. The nastiest: `play_stadium()` moves a card into `state$stadium`, which neither `count_copies()` nor `.visible_count()` counted, so a played Stadium vanished from the census and `knowledge_after_search()` deduced it was **prized while face up on the table**. Added `all_cards_in_game()` as the single definition of where cards can be.
  - **Process lesson worth keeping:** the test helper had its own separate census that *did* count the stadium, which is precisely why the suite masked the bug instead of catching it. A test fixture that reimplements a production invariant will hide a break in it. Assert against the production function.
  - Also mine: `can_act()` was only half-wired (benching/evolving/drawing still legal after an attack), and `is_salvatore_target()` subtracted only the discard so an in-play copy counted as findable.
  - Pre-existing: `set_prizes(0)` destroyed the whole deck (`deck_vec[-integer(0)]` is empty, not the deck), Meowth ex's Last-Ditch had no once-per-turn flag, `count_copies(character(0))` returned a list, `bool_decked_out` was uninitialised, `bench_idx` was unbounded below, and the mulligan bound fired one iteration late.
- **Confirmed clean by audit:** card conservation across all seven zone-changing functions, verified by a 300-game fuzz with a full 60-card census after every action — zero violations. All 37 card-table rows match `docs/cards/` field-by-field. No code path lets the policy read prizes or deck order.
- **Sequencing mistake to avoid repeating:** I edited files while the correctness agent was auditing them, so it had to re-verify everything against the moving tree. Run audits against a frozen commit, or serialise them.

### 2026-08-29 (Session 8 — coverage audit, third agent)

- Relaunched the test-coverage agent against a frozen commit (the earlier sequencing mistake). It found no new *crashes* but several **wrong-answer** paths, all now fixed and pinned. Suite is at **1517 assertions**.
- **Search cards fetched as many targets as asked.** Poke Pad, Ultra Ball, Hilda and Last-Ditch Catch each fetch ONE card but capped nothing, so passing a target *vector* — the natural thing for a policy to write, and what `play_pokegear()` already accepts — silently tutored several cards with no error and a conserved multiset. `max_targets` is now mandatory on the shared search helpers, which are the single enforcement point.
- **The decklist parser dropped unparsable lines in silence.** A lowercase set code, a `4x` count prefix, a missing space, or a PTCG-Live variant tag each produced a legal-looking 56-card deck. Worse, **`setup_game()` never called `validate_decklist()`** — only the smoke script did, and the runner does not run it. Both fixed: the parser errors on any non-header, non-blank line it cannot read, and setup validates.
- **A fractional `bench_idx` silently targeted `floor(idx)`**, because `[[` truncates a double and the range guards pass for 1.9. Added `check_whole_number()` and routed every index and count through it.
- **Belief queries answered `FALSE`/`0` for an unknown card id** instead of erroring, so a mistyped id would make the policy decline a search it should make — invisible in an aggregate rate. Now routed through `lookup_card()` for its loud-failure contract.
- **The metric measured availability, not the attack.** `can_use_evolution_jammer()` says the attack is *possible*; ADR 0004 asks whether the player *attacked*. A turn where Jammer was momentarily legal and the policy then switched away would have scored as a hit. Added `state$jammer_turn`, set only by `attack_evolution_jammer()`, and documented it as the field scoring reads.
- **Retreating always spent the first-attached Energy**, which could discard the Telepathic Psychic attached on turn 1 while keeping a Colorless Enriching — failing sub-goal D for a reason no player would choose, understating consistency. Now spends non-`[P]` first, with an optional explicit choice.
- **Weak assertions the audit named, all strengthened:** a literal tautology (`x || TRUE`), a length check where a multiset check was needed, a `<=` that passed when nothing happened, a vacuous `num_mulligans >= 0` (no test ever forced a mulligan), and a seed-dependent guard that fired on only 10 of 30 seeds.
- **The shim was not actually testthat-faithful.** `expect_silent` accepted an `info` argument real testthat does not take, and checked only for errors rather than output and warnings too — so the claim that the tests would run unchanged under `devtools::test()` was false. Fixed both.
- **Two of my own new tests failed, and both were the test's fault** — worth recording because the diagnosis was not obvious. At seed 6 the Ciphermaniac's card has *zero copies in the deck* (one in hand, one prized), so the fixture helper that "adds it if absent" inflated the total above the decklist count and broke the arithmetic under test. And at seeds 1 and 3 the Active is Mega Kangaskhan ex, where Telepathic's `[P]`-recipient trigger correctly does not fire. Added `.run_with()`, which skips a cell rather than manufacturing a position, plus a floor on cells run so the sweep cannot go vacuous.
- **Closed the audit's highest-value gap:** every prize-deduction test previously called `knowledge_after_search()` directly on a fresh setup. None went through a card — and the previous round's worst bug (a played Stadium deduced as prized) was exactly that shape. Now swept through seven real effects, asserting the deduced multiset *equals* the prize pile.
- Made `card_df$shuffles` live rather than dead data: a test now asserts that every card marked as shuffling actually clears known deck ordering when played.
- Fixed the smoke test's own fixture idiom, which overwrote in-play records wholesale — the audit showed that keeps the census at 60 while destroying one card and conjuring another, and would have reported 7 prized cards.

### 2026-08-29 (Session 9 — traces, mulligan metrics, and two vetting agents)

- Built the history-storage layer Kevin asked for: `R/trace_claude.R`, giving every run **two outputs** (ADR 0006) — a rate over all replicates, and a small stratified sample of readable traces for tuning the decision tree. Plus ADR 0005 (mulligans are never a miss) documented across the rules doc, `CLAUDE.md` and `CONTEXT.md`.
- Two agents vetted it. Between them they found a **crash and several wrong answers**, and the two most important findings are ones I would not have found by testing my own assumptions.
- **The crash:** `format_trace()` indexed `SUBGOAL_VEC[[NA]]` whenever all four sub-goals were met and the attack was simply never declared — i.e. *exactly* the case ADR 0004 exists to expose. Any driver keeping traces would have died on the first such replicate, killing a whole 10,000-replicate run.
- **The worst design error, and the lesson worth keeping:** reporting only the **first** unmet sub-goal quietly falsified the project's own central hypothesis. Because the order is A→B→C→D, C could only ever be reported when A and B both held, so the file said `C: 1/322` while 106 of 322 misses actually had a Bronzor or Bronzong in play and not Active. An agent reading the file concluded that `docs/03_decision_tree.md`'s headline claim — "C is the sub-goal that actually fails" — was refuted. It was masked by my reporting rule. Now reports the **set**; C shows as 303/322 and the hypothesis is supported.
  - Generalisable: **a summary that collapses a set to its first element can invert the conclusion the summary exists to support.** Report the set and let the reader collapse it.
- **`unused_outs` was accusing the decision tree of rule-enforced misses.** It was a bare `intersect(hand, outs)` with no playability test, so in the `item_lock` cell **56% of the reported "decision defects" were the Item lock itself**, and every flagged Telepathic Psychic Energy sat behind an already-spent attachment. Now checks `can_act`, the Item lock, the attachment, Ultra Ball's discard cost, Poffin's HP cap, and bench space.
- Also in that flag: **Hilda was listed as an out for sub-goal A** — it fetches an Evolution and an Energy, and Bronzor is a Basic, so it can never fix A. And a **Bronzor in hand was missing from A entirely**, the cheapest out there is. The flag was naming the card that could not help while staying silent about the one that could.
- **A residue check cannot see a misplayed card**, and its firing rate tracks hand size (0.20 at end-hand 2, 0.80 at 8). The clearest defect in the audited file — two Telepathic Energies attached to a Colorless body with the search declined both times — left no residue and carried no flag. Added **motif detection** over the event log, which catches exactly that class.
- **The single highest-value usability finding:** an agent reading 16 traces reported that it stopped reading them narratively and started counting substrings, and that the counting produced its main recommendation. The file now ships the counts — motif tallies over every miss — because the traces' real value is as a corpus to count over, not stories to read.
- `-> whiff` meant two opposite things: a search that *failed* (deck defect) and one the policy never *aimed* (decision defect). Merging them defeats the file's entire purpose. Now `DECLINED (no target named)` vs `whiff (X not in deck)`.
- The header omitted the decklist, giving only a content hash — so an agent asked to recommend changes proposed several cards that are not in the deck. Now spelled out, with a warning when it is not supplied.
- Smaller: `summarise_run` refused pooling across cells (ADR 0002 forbade it and nothing enforced it); `write_trace_file` now requires a `bronzong_summary` so the sample cannot be passed as its own summary; the ADR 0004 turn distribution and turn-1 rate are computed (Salvatore's whole value was invisible in every artefact); `.turn_lines` returned `list()` on an empty log and poisoned the trace; promotions now name the mechanism (Switch / retreat / Surfer), since sub-goal C is entirely about which resource you spend.
- Open: the demo runs going-second only, so the going-first branch of the decision tree is untunable from it. Worth crossing both when part 6 lands.

### 2026-08-29 (Session 10 — Kevin's answers to part 3, and the turn-2 window)

- Kevin answered all five open questions in `docs/03_decision_tree.md` §9. **Two of the five were deliberately not answered but deferred to the simulation logs** — the §3 lead order and whether Ciphermaniac's is right within its one legal cell. That is itself a decision: those two stop being prose to be believed and become measurements part 6 has to produce, so both are now written as defaults the traces are expected to overturn, alongside the §1 claim that sub-goal C is what actually fails.
- **A belief the draft held and Kevin corrected: Buneary's Run Around is not free positioning.** Both part-3 files described it as costing "the *turn* rather than a card". Kevin: *"this strategy also needs to sacrifice an energy."* Run Around costs `[C]`, so it spends the turn's one Energy attachment — the same resource sub-goal D needs — and worse, the Energy **rides Buneary to the Bench** when the switch resolves, where it can never pay for Evolution Jammer. The policy rule that follows: pay it with Enriching Energy if possible, and decline outright when the only Energy in hand is a `[P]` source and no second one is held, because that trades a failure of C for a failure of D. Budew's Itchy Pollen costs **zero** Energy, so the two §4.2 exceptions are not symmetric — the draft presented them as if they were.
- **Ciphermaniac's is playable-and-useful in exactly one cell, `P2T1`.** Kevin's reason was that he cannot evolve his Bronzor on his own first turn anyway; working it through, the other two cases close too — going first no Supporter is legal on turn 1 at all, and on turn 2 either side the draw step has already passed, so the stacked cards are never reached inside the window. Three separate rules fence one card into one cell.
- **Recorded ADR 0007**, because "the bar is turn 2" (ADR 0004) and "the engine stops at turn 2" are different claims and only the first was written down — the §7 draft explicitly assumed part 6 might still want a turn-3 distribution. Kevin closed it: no turn 3, but be thorough at the end of turn 2.
- **That thoroughness cost the compactness budget, and the trade was made knowingly.** The `end` summary went from one line to eight (every zone, plus damage and the turn each Pokémon was played or evolved), so the trace cap in the tests moved 12 → 16 lines. The cap is kept because the growth ADR 0006 actually feared is the *per-turn* lines, which scale with how much the policy does; the snapshot is a fixed cost per trace.
- **The snapshot names the prized cards, labelled as ground truth.** ADR 0003 constrains the *policy*, not the analysis, and "both Bronzong prized" is the single line that separates a variance miss from a decision defect. The label is written into the trace file itself so the field's existence is never mistaken for permission to read it from part 5.
- **Added a hit-rate-by-setup-lead table to `summarise_run()`, not to the traces** — this is the part that is easy to get wrong. ADR 0006 forbids computing a rate from the traces, so an answer to the lead-order question can only come from an aggregate over every replicate; had the lead only been recorded in the trace, the question Kevin deferred to the logs would have been unanswerable from them.
- **First data point on the lead order, and it is only half a result.** Over the 400-replicate demo (going second, `clear`, decklist2): leading Bronzor hits 54.4%, every other lead 3–13%. That corroborates the mechanism — C is the bottleneck — but says **nothing yet about the ordering among non-Bronzor leads**, because the demo's placeholder policy has no switch or retreat logic at all, so a non-Bronzor lead essentially cannot fix C by construction. Mega Kangaskhan ex, the current §3 recommendation, comes last at 3.4% for exactly that reason. Re-read this only after part 5 exists.
- **`CONTEXT.md` had gone stale against the code**: *Blocking sub-goal* still said it is "reported as the **first** unmet one", which is the reporting rule session 9 removed as actively misleading. Corrected to the set. Also added *Measured window*, a term the file used twice in other entries without ever defining.
- Open, unchanged: the four questions in `docs/03a_card_playbook.md` (Ultra Ball discard order, the Telepathic target, Mystery Garden, Rare Candy → Dusknoir) were not part of this batch.
- **`/code-review` then caught two measurement bugs in the same file, both of the class this project keeps producing — a count that is confidently wrong rather than absent.** Fixed, and the tallies over the 400-replicate demo moved substantially:
  - `never_promoted` **154 → 106**. The condition was "A met, C unmet", which is equally true of a Bronzor that *led at setup and was never evolved* — a sub-goal B failure with nothing to promote and no positioning mistake in it. 48 replicates were being counted under a label reading "never made Active", inside the tally headed "the counts worth acting on".
  - `supporter_slot_unused` **185 → 292**. It grepped the *whole* event log for a hard-coded list of Supporter names, so a replicate that played Hilda on turn 1 and wasted turn 2's slot was never flagged — 107 of them. It also could not see a Supporter the effects log under a label rather than a name ("Codebreaking stacked"), and omitted Boss's Orders, which decklist2 runs 2 copies of. Now per turn, off a canonical `supporter played` event written at `.play_supporter_from_hand()` — the single choke point every Supporter passes — and turn 1 going first is excluded, since no Supporter is legal then and an unspent slot is a rule rather than a choice.
- Two latent versions of the same "flagged an out that could not have helped" error, also from the review: Buddy-Buddy Poffin's check accepted any ≤70 HP **Basic** (Duskull, Buneary and Budew all pass) rather than a ≤70 HP **Bronzor**; and Telepathic Psychic Energy was an unconditional out for sub-goal A, though its route to A is a search that fires only on a `[P]` recipient. The Telepathic fix had to be sub-goal-specific rather than a playability rule — it stays an unconditional out for **D**, where it is wanted as a `[P]` source and searching nothing on a Metal Bronzor is fine.
- Worth knowing about the reviewing agent: it reported that the ~1600 assertions "cannot have been executed on this machine" because testthat is not installed. That is wrong — `tests/testthat_shim_claude.R` exists precisely for that, and the suite runs. Its code findings were nonetheless accurate and worth acting on; the environmental inference was not.

### 2026-08-29 (Session 11 — Kevin's corrections to the part-3 draft)

- Kevin read the revised `docs/03_decision_tree.md` and returned five corrections. Four were local; one contradicted the same instruction repeated in three sections.
- **The correction that mattered: bench space is a scarce resource, and the draft treated a benched body as free.** Three sections said to bench every Basic in hand. Five slots, one realistically reserved for Latias ex — and a benched Basic cannot be un-benched, so playing it converts a card that still had options (an Ultra Ball discard, a Lillie's redraw) into a body that does nothing unless it is Latias ex, Meowth ex, or the Bronzor itself. New rule, now §4.4: **bench nothing at setup** (his answer to a follow-up — Active only, not even Latias ex, since Skyliner does nothing before our first turn), then during a turn bench only Latias ex, Meowth ex for a *named absent* Supporter, a Bronzor for A, and everything else *only* ahead of Lillie's Determination, which shuffles the hand into the deck and would otherwise bury them.
  - Recorded alongside it: benching nothing is safe **only inside this window**. An empty Bench loses the game to a Knocked Out Active, and it is safe here purely because the strongest attack either scenario deals is Itchy Pollen's 10 against a ≥60 HP body. Without that note the rule reads as general and is dangerous.
- **A belief I had recorded as reasoning and Kevin corrected as wrong:** the draft said to play free Items before Salvatore "since Salvatore shuffles". A shuffle costs nothing when every play involved is a *search* — the reasoning only applies to a pending Ciphermaniac's stack. Only two orderings genuinely bind anywhere in the document, and this was not one of them.
- **The positioning ladder was missing its cheapest rung.** The draft went straight to Switch. Kevin: with Latias ex in play and a Basic Active, **retreat** — it is free, otherwise unspent, and costs no card. Now stated once as §4.3 (free retreat → Switch → Surfer → Run Around) and referenced from all four places that previously each said something slightly different. He also noted Surfer can beat Switch on a nearly empty hand, since it refills to 5; inside the §4.1 Salvatore line it stays excluded, because playing it does not lose the switch, it loses the kill.
- **The §8 non-goals were too absolute, and the Cursed Blast entry was backwards.** Kevin: a Dusclops stuck Active can evolve to Dusknoir and use Cursed Blast "just to get a Bronzor on my bench into the active". The mechanism is the *self*-Knock Out, not the damage — after a Knock Out the player whose Pokémon was Knocked Out chooses the replacement Active, so Cursed Blast is a switching effect costing no Switch, no Supporter slot, no retreat and no Energy. Why the Active gets stuck at all: **Skyliner zeroes Basics only**, so a Stage 1 Dusclops retreats for 2 even with Latias ex out.
  - Two things that look like traps and are not, both now asserted in tests rather than left to memory: our own Prize count is untouched (the opponent takes the Prize, from *their* pile, which this one-player simulator does not model), so **Lillie's still draws 8** on a Cursed Blast turn; and the Bench must be non-empty or we simply lose.
- **Rare Candy was on the engine's "inert for turns 1–2" list and should not have been** — it is the only route from a Duskull Active to a Dusknoir, so it enables the escape. The generalisable error: *"inert for the metric" is a claim about every line the card appears in, not about the card's headline use.* Same shape as the still-open Mystery Garden loose end.
- Kevin chose to build the engine support now rather than defer it: `can_rare_candy()` (a separate predicate, because `can_evolve()` matches `evolves_from` by name and so *correctly* refuses Duskull → Dusknoir), `knock_out()` with caller-chosen promotion, `play_rare_candy()`, `use_cursed_blast()`, and a `bool_no_pokemon` loss flag. The empty-Bench case is modelled faithfully in the rules layer and refused in the effect layer — a policy guard, not a rule, and the comment says which.
- The traces gained Rare Candy as an out for C **under the full compound condition** (Duskull Active that Rare Candy may legally evolve, a Dusknoir left in the deck, a Bronzor or Bronzong benched). It fired on 2 of the demo's 322 misses — rare, which is exactly why the loose version would have been the worst false accusation in the file.
- **`/code-review` caught three defects in that engine work, two of them mine and serious.** The Rare Candy out for C asked for the Dusknoir **in the deck** — Rare Candy does not search, so the condition was exactly inverted: it flagged the escape precisely when it was impossible and stayed silent when it was real. It had already produced 2 false "playable out unused" accusations in the shipped demo file, in the same edit where I wrote that a loose version would be the worst false accusation in the file. Root cause was one layer down: `can_rare_candy()` documented its argument as "the Stage 2 in hand" and never checked it, because unlike `can_evolve()` it has a caller (the diagnosis) that is *not* holding the card. Fixed at the predicate, matching the card's own "if you have a Stage 2 card in your hand" clause; the demo's unused-out count went back from 239 to 237.
- Second, related: the same check accepted a benched bare **Bronzor** as satisfying C, but C is `bronzong_active` — promoting a Bronzor does not meet it. Now requires either a benched Bronzong, or a benched Bronzor with a Bronzong in hand that `can_evolve()` says may legally go on it this turn.
- **The pattern is worth naming, because this is the third time**: after Hilda-under-A and Poffin-under-A, a new out was added whose *card* was clearly right and whose *precondition* was wrong in a way that only fires rarely. Rarity is what makes it survive review by eye — the demo showed 2 hits out of 322 misses, which reads as "working" rather than "backwards". Every future out entry needs a test that asserts the negative case with the card still in hand.

### 2026-08-29 (Session 12 — part 5, and a knitted demo)

- Kevin asked for a demo he could react to, explicitly not a finished product. That needed **part 5**, which did not exist: everything so far had been driven by a crude placeholder inside `scripts/demo_traces_claude.R` that benched every Basic, never retreated, and ignored most of the decision tree.
- **`R/decision_claude.R` is a section-by-section translation of `docs/03_decision_tree.md`**, so the two can be read side by side and the *tree* corrected where it is wrong. Written to be argued with rather than tuned.
- **Result of replacing the placeholder with the real tree: 19.5% → ~50% going second, 48% going first**, on decklist2 over 1,000 replicates a cell, with 12 turn-1 Salvatore kills going second and none going first. The `telepathic_on_colorless` motif went to **zero** — that motif was almost entirely an artefact of the placeholder attaching Telepathic to whatever was Active.
- **Writing the policy found three defects that only appear at scale**, all of the same shape: a rule that is right in the common case and fatal in an uncommon one.
  - The policy asked **Poké Pad for Latias ex**, which has a Rule Box and cannot be fetched. The effects assert legality with `stopifnot()`, so this is a crash, not a misplay — it killed a third of the seeds. Fixed by naming the per-card target predicates once (`ALLOWED_TARGET_LIST` in `R/card_effects_claude.R`) and having both the effects and the policy consult them, rather than the policy re-deriving each card's rule.
  - `.ultra_ball_discards()` used `setdiff()`, **which de-duplicates**: a hand holding two Bronzong offered one discard where two existed, padded the pair with `NA`, and `move_cards()` rejected it a hundred replicates in. Now works in hand *positions*.
  - The first narrated game in the demo did **nothing at all on turn 1** — a hand of two Telepathic Psychic Energies with no Bronzor in play. `.policy_energy()` only attached to the Bronzor line, so with no Bronzor it declined; but Telepathic on any `[P]` body is a *search* for two Basic `[P]` Pokémon, which is sub-goal A's cheapest out. That is why the playbook lists it under A.
- **The demo document itself found the first real question for the tree, which is what it was for.** The narrated game ends with **Salvatore in hand, unplayed, on turn 2**, flagged by the trace as a playable out — because §6 priority 1 reads "never otherwise on turn 1", which read literally means Salvatore is never played on turn 2 either. But on turn 2 it still fetches Bronzong *and* evolves in one card. Written up in the demo as an open question rather than silently patched, since it is a tree decision, not a code bug.
- **The by-lead table disagrees with §3 twice.** Mega Kangaskhan ex, §3's recommended non-Bronzor lead, comes near the bottom (39.5%); Latias ex, which §3 says to lead only as a last resort, is the best non-Bronzor lead (62.5%, n=32). Both are contaminated by the policy: it never uses Run Errand, so Kangaskhan is being judged with its upside switched off. Recorded in the demo as questions, not findings.
- **knitr and rmarkdown are not installable here** (base + recommended only, no CRAN), so `scripts/knit_rmd_claude.R` is a ~250-line stand-in that evaluates chunks and shells out to the pandoc bundled inside RStudio. Same shape as `tests/testthat_shim_claude.R`: the **source stays standard R Markdown** so `rmarkdown::render()` will produce the same document unchanged, and the shim can be deleted rather than migrated. Kevin chose this over leaving the `.Rmd` unrendered.
  - Two things it got wrong first, both worth knowing if it is ever extended: `knitr::opts_chunk$set()` cannot be shimmed with a variable, because `::` bypasses the search path and loads the namespace — the calls are dropped instead; and `strsplit(header, ",")` cuts `fig.cap = "rate by lead, going second"` in half, so chunk options need a quote-aware splitter.
- ADR 0003 is now enforced **statically**: `tests/testthat/test_decision.R` greps the policy source for `state$prize_vec` and `state$deck_vec`. Reading a field leaves no trace in the state, so no amount of playing games can prove the policy did not peek — grepping can.
- **`/code-review` found 13 defects in the new policy, and the useful thing is that almost none of them changed the headline rate.** Going second stayed at ~51% before and after; going first moved ~48% → ~50%. What they changed was **what the diagnostics mean**, which is what the tables are for:
  - **Poké Pad and Poffin were played unconditionally.** Both discard themselves *before* searching, so playing one with no believed target throws the card away. That was most of the `a search resolved with no target named` count — a motif whose whole job is to accuse the decision tree, and it was accusing this line. Down from 126 to 71 over 1,000 replicates.
  - **`.policy_evolve()` ran after the last `.policy_position()`**, so a Bronzong the policy had *just made on the Bench* could never be promoted that turn — the trace then reported an unused Switch as a decision defect. Evolving now happens before the final positioning step.
  - **Hilda could be played fetching nothing** (Bronzong and a `[P]` source both already in hand → both searches resolve to `NULL`, Supporter slot gone). Same shape for **Meowth ex**, benched even when no Supporter was worth fetching, spending one of five Bench slots for zero effect.
  - **`bool_lillies` dumped the whole hand onto the Bench for a Lillie's that priority 4 then never played** — and the full Bench blocked Poffin and Telepathic's search for the rest of the window.
  - **The Surfer branch returned unconditionally**, so when Surfer had no benched target the Supporter step ended having played nothing, and Ciphermaniac's below it was never reached.
  - **`supporter_slot_unused` went UP** (456 → 473) as a direct result, and that is the honest number: a Hilda played for nothing used to count as the slot being used.
- **The fix for the last three was structural, not local:** `.choose_supporter()` is now a pure decision returning a card id, and `.play_chosen_supporter()` executes it. Splitting them is what lets the answer be asked *before* benching (Lillie's changes what benching should do) and lets a card that would accomplish nothing fall through to the next priority instead of silently consuming the step.
- Two more worth keeping: `.kill_line_is_live()` accepted **Bronzong in hand** as satisfying its Bronzong requirement, but Salvatore searches the *deck* — so the kill line read as live in exactly the case where Salvatore would find nothing; and Run Around paid its `[C]` with Telepathic Psychic Energy, because `.psychic_in_hand()` sorts Telepathic first — correct when attaching to the line, exactly wrong on a Colorless Buneary, and the very waste the `telepathic_on_colorless` motif exists to flag.
- `play_replicate()` now stops when `bool_no_pokemon` or `bool_decked_out` is set. `begin_turn()` clears the per-turn flags, so `can_act()` cannot see either loss condition, and a lost game would have kept playing turn 2 and could still have recorded a hit — a metric-level lie rather than a bad play. Latent today (nothing calls `knock_out()` yet) and introduced alongside the new flag.
- Demo prose now uses **inline `r` expressions** for the lead-table figures it discusses, so the numbers cannot go stale against the tables above them on a re-knit.
- **Kevin's five checks on the demo. Two were already correct, three were real gaps**, and fixing them moved decklist2 from 50.8% to **54.0% going second** and 49.9% to **54.8% going first** over 1,000 replicates a cell.
  - **Prizes (already correct).** `set_prizes()` takes the top 6 off the shuffled deck and removes them; setup accounts to exactly 60 = 6 hand + 47 deck + 6 prizes + 1 Active, and the prized cards differ by seed. Already pinned by a test in `test_setup.R`.
  - **Lillie's 6-vs-8 (already correct).** Keyed on `length(prize_vec) == 6`, and both branches were already tested. Kevin is right that it is always 8 inside this window: our prize count only falls when *we* take prizes, which needs us to Knock out one of the opponent's Pokémon, and no opponent is modelled.
  - **Run Errand was never used.** Now taken first in the turn, before positioning — the §4.3 ladder is about to retreat or Switch Kangaskhan out of the only spot the Ability works. Note the wording: Run Errand is **draw 2**, not a search.
  - **Telepathic now always fetches two Basics, not just the wanted ones.** Kevin's reasoning, worth keeping: every card pulled out of the deck also *thins* it, so the second target is worth taking even when it is not wanted for its own sake — a thinner deck is a better chance the next draw is the Bronzong.
  - **Latias ex now leads the want-list when sub-goal C is the live blocker** (line in play, benched, no free retreat, no Switch in hand). Ultra Ball and Brock's Scouting are the only two cards that can fetch it — Poké Pad cannot, because Latias ex has a Rule Box, which is exactly why Poké Pad ends up being the card that finds Bronzong. Brock's guard also had to widen: it was "sub-goal A unmet", so with a Bronzor already benched the one Supporter that could unblock C was never chosen.
- **The Kangaskhan result is the cautionary one.** Implementing a two-card draw moved that lead from 40.9% (near the bottom, and I wrote it up as a possible argument against §3) to **55.8%**, the best of the common non-Bronzor leads. §3's recommendation was right and the policy was wrong. Nothing in a lead table means anything about the *deck* until the policy plays each lead's card properly.
- Now that Kangaskhan is played properly, the table's remaining oddity is **Buneary: §3's second choice, second from last (40.2%)**. Its whole case is Run Around, which §4.2 then makes a last resort because it spends the turn's Energy attachment — the tree may be disagreeing with itself.
- **Open tension worth a ruling:** Telepathic's deck-thinning fetch puts up to two more bodies on the Bench, and §4.4 says Bench space is scarce and one slot is reserved for Latias ex. The implementation caps the fetch by remaining space, so thinning yields to bench discipline rather than the other way round. Kevin has not said which should win.
- Every Supporter in the card database is implemented except **Boss's Orders**, deliberately: it moves the opponent's Pokémon and no opponent is modelled.

### 2026-08-29 (Session 13 — aligning the policy with the decision tree)

- Kevin asked for the code and the spec to agree before he goes back to editing the documents. I read both in full. **Divergences ran in both directions**: 7 places where the doc mandated something the code did not do, and 8 where the code did something the doc does not describe. He chose to have all 7 implemented, so the code is now a literal reading of today's document.
- Implemented: Buneary as a lead **going second only** (§3); **no shuffling Item while a Ciphermaniac's stack is pending** (§5, §7); Brock's Scouting in **Evolution mode** once Hilda is gone (§6 pri 3); the want-list's **second Bronzor and Meowth ex** (03a items 6–7); **playing a Stadium** (§4.2 step 6, Mystery Garden excluded); **Pokégear 3.0** (§5 step 6); and Ultra Ball's **explicit discard order and never-discard list** (03a).
- **The alignment cost 1.4 points**, 54.0% → 52.6% going second, and finding out *which* change did it was the useful part:
  - **The §7 pending-stack guard costs exactly nothing** (52.6% either way). Ciphermaniac's is priority 6 and rarely played, so the rule almost never fires. It is also weaker than it looks: the stack is placed on `P2T1`, turn 2's draw takes the first card, and the second is reachable inside the window **only through a draw effect** (Run Errand, Enriching Energy). Most turns it protects a card that can never be drawn.
  - **Ultra Ball's never-discard list is worth +5 points** — 47.6% without it, 52.6% with. That list is one of the playbook's four open questions and it is carrying real weight; it should not be relaxed casually.
  - **The want-list's items 6–7 cost the whole 1.4 points** (53.9% → 52.6% when they are the only change). Only 0.2 of that is bench-placing searches spending slots; the rest is hand searches spending *themselves* on insurance targets once the useful ones whiff.
- **The finding worth acting on, and it is a doc question rather than a code one:** 03a says "every search resolves against this ordered want-list", one list for every card. But the cards differ in what a fetch *costs* — Poké Pad is free, Ultra Ball costs two cards, and Poffin and Telepathic place onto the **Bench** rather than the hand. Walking the same list to the same depth means Ultra Ball will pay two cards for "a second Bronzor as insurance", and Poffin/Telepathic will put **Meowth ex** on the Bench, where Last-Ditch Catch never triggers because the Ability only fires when it is played from hand. **The list probably needs a floor that differs per card.**
- Added a **doc-section → function cross-reference** to the top of `R/decision_claude.R`, so that editing a section says what to change, and a divergence is findable rather than discovered.

### 2026-08-30 (Session 14 — the documents become the specification)

- Kevin settled the division of labour: **he edits `docs/03_decision_tree.md` and `docs/03a_card_playbook.md` and does not edit the R; the code is brought back into line with them.** Recorded in the master `CLAUDE.md` as its own section, because it governs every future session and is not derivable from the tree.
- **Wrote the eight code-outruns-doc behaviours into the documents**, since he reads the documents and was otherwise reading a spec that under-described the simulator: a new **§4.5 "Free Abilities, taken before anything else"** for Run Errand; Telepathic's two-target deck thinning (§4.2 step 5); Hilda skipped when she can fetch nothing and Brock's two modes stated precisely (§6); "hand is weak" defined as four cards or fewer, marked a default rather than a ruling; the dead Budew condition flagged in §3; Itchy Pollen and the Cursed Blast escape marked **specified and not implemented**; and what the §7 pending-stack guard is actually worth.
- Every claim written into a document was **re-checked against the function that implements it** rather than trusted from session notes — the whole value of the exercise is that the document can now be read as true.
- **The playbook gained the finding that matters most:** its want-list is walked by cards with very different costs. Poké Pad is free, Ultra Ball costs two discards, and Poffin and Telepathic place onto the **Bench**. So item 7 is actively wrong for the bench-placing cards — **Meowth ex fetched onto the Bench never triggers Last-Ditch Catch**, because the Ability fires only when it is played from hand. The list probably needs a per-card floor, not just a per-card legality filter.
- **Wrote the repo's first project-local skill, `.claude/skills/align-decision-tree/`.** Its shape follows Kevin's sketch: two agents in parallel, one per direction — **red** (the code fails what the document says) and **green** (the code does something no document describes) — then a failing test before each code fix, then drafted document wording for the green findings, then a re-measurement.
  - The design decision worth keeping: **the two questions must be asked separately.** An agent asked for "any divergence" finds the first kind and stops. This session's manual pass found 7 red and 8 green, and neither list contained the other's items.
  - It also requires **attributing** any rate movement to individual changes by neutralising them one at a time, because "alignment cost 1.4 points" was far less useful than "the want-list's items 6-7 cost all of it and the stack guard costs nothing".
- **Built the question registers and the scenario bank** (same session, after the alignment). `docs/03_decision_tree.md` §10 now carries **23 `DT-nn` questions** and `docs/03a_card_playbook.md` **14 `PB-nn`**, each one a rule the project states as a default rather than a ruling, numbered so an answer names what it settles.
- **`docs/03b_scenarios.md` is the new artefact and the one Kevin asked for**: 14 board positions, each with 3–4 concrete options, and **the tree's own answer held back to appendix A** so that reading a question does not anchor the answer. Kevin picked that format over showing the policy's choice inline.
- **The positions are real, not invented.** `scripts/generate_scenarios_claude.R` sweeps 500 seeds, snapshots the state at the start of a turn *after the draw and before the policy acts*, keeps the first match per predicate, and reports **how often a matching position arose** — 23.4% for the Salvatore-on-turn-2 spot, 2.2% for the Ultra-Ball-with-nothing-to-discard spot. The frequency is what tells Kevin which questions are worth answering first.
  - The rationale worth keeping: an invented hand can be answered "I would never be here", which settles nothing. A position the policy actually reached cannot be dismissed that way.
- **Appendix A is computed, not remembered.** The generator plays `policy_turn()` from each captured position and writes what the policy actually does. Writing what I believed the tree does is exactly how an appendix goes quietly wrong.
- Two predicates initially found **zero** examples, which was a result rather than a failure: both looked for turn 1, where the Bench is still empty because §3 benches nothing at setup. Moved to turn 2 they found 41 and 37.
- **A rules error I caught in my own constructed scenario:** the first draft of S-13 had a Dusclops Active being Rare Candy'd into Dusknoir. Rare Candy goes **Basic → Stage 2**, so a Stage 1 Active cannot use it — the escape from a Dusclops is its *own* Cursed Blast, and the Rare Candy route belongs to a **Duskull** Active. Fixed, and written into the new skill's traps.
- Every option in every scenario was **checked as legal in that exact position** — the retreat actually free, the Switch actually held, the Supporter slot actually unspent — because an option that cannot be played measures nothing.
- **Second project-local skill: `.claude/skills/generate-scenarios/`.** Its completion criterion is that every register entry is either matched to a scenario or recorded as one that prose answers better.

### 2026-08-30 (Session 15 — the decision documents go present-tense)

- Kevin ruled that **`docs/03_decision_tree.md` and `docs/03a_card_playbook.md` carry no history of their own**: they state the tree as it stands today and nothing about how it got there. The evolution of a decision goes to this file, or to an ADR the document then cites by number. Written into the master `CLAUDE.md` as a subsection of *The decision documents are the specification*.
- The rationale worth keeping: the documents are the thing he **reads to play the turn**, so a rule that arrives wrapped in "what the draft said → correction" costs a reader the work of figuring out which half is in force. Once the code follows the documents literally, an ambiguous half-sentence is also a code defect waiting to happen.
- **The rule draws a line that is easy to get wrong in the other direction:** an open question is not history. The `DT-nn` / `PB-nn` registers and any rule marked *default rather than ruling* describe the tree's **current** uncertainty and stay in the documents. What leaves is only the record of superseded states.
- **Not yet applied.** The convention is logged; the existing text still violates it in four known places, all from the 2026-08-29 review rounds: §9 of the decision tree (the answers table and the "corrections from Kevin, second round" table), the file header's pointer to §9, "for a different reason than the one previously given here" in §7, and "**No longer inert** (Kevin, 2026-08-29)" on Rare Candy in the playbook. Kevin was offered the migration and it was left for a later turn.
- The migration is not a delete: §9's five answers are **rulings that are still in force**, and three of them are only stated there (Switch over Surfer; Ciphermaniac's confined to `P2T1`; declining Run Around). Each has to be folded into the section it governs before the table goes, or a live rule disappears with the changelog.

### 2026-08-30 (Session 16 — Kevin's fourteen answers become rules, and the rate moves 23 points)

Kevin answered all fourteen positions in `docs/03b_scenarios.md`. Nine confirmed the tree; five changed it. The order was documents → code → measure → new bank, per `CLAUDE.md` → *The decision documents are the specification*.

**What the answers settled, and the non-obvious part of each.**

- **S-04 → the Supporter slot is never left idle.** Kevin: *"it's important to play at least one Supporter a turn whenever possible if it even increases my chances to get set up even by a little bit."* This is now §6 **priority 8**, a fallback below every named priority. The thresholds above it — Hilda's "can fetch something", Lillie's four-card hand, Ciphermaniac's single missing piece — turn out to be about *which* Supporter to prefer, never about whether to play one. Worth **15.2 points going second**, the single largest change the project has made.
- **The consequence I did not anticipate and had to measure.** A fallback Supporter played at the end of the turn draws eight cards the window can never spend — ADR 0007 closes the window at the end of turn 2. So the fallback alone was worth **nothing on turn 2**; all of its value came from turn 1 going second. §7 gained **step 6**: run bench / evolve / position / attach **a second time** over whatever the fallback drew. That second pass is worth **5.0 going second and 6.7 going first**, and it is what makes the fallback pay on the going-first branch at all (+3.4 there, against −0.1 without it). Rules-legal throughout: one evolution, one attachment, one retreat, each still capped by the rules rather than by the number of passes.
- **S-05 → Ciphermaniac's is gated on what it can *solve*, not on a count.** Kevin rejected my "≤2 sub-goals unmet" framing outright: *"I don't think it's good to think about this as 'the number of sub-goals.' Instead, you need to model what sub-goals each Supporter can solve."* Ciphermaniac's puts exactly one card into turn 2's draw, so it is right only when **exactly one** of B, C, D is missing. §6 is now headed by a *solves* table rather than by a priority list alone. Worth **4.4 going second**.
- **S-06 → Meowth ex fetches Hilda, not Salvatore.** Salvatore fixes sub-goal B alone, so it converts only where C is already free and D already secured; Hilda fixes B *and* D. The old condition was "`P2T1`, unconditionally". Worth **1.8**.
- **S-06 also → "sub-goal C is blocked" is prospective.** A Bronzor still *in hand* counts as the line, because by the time it has been benched the searches that could have found Latias ex are spent. Costs **0.3** and stays: it is a ruling, not an optimisation.
- **S-13 → the Cursed Blast escape is built.** `.policy_cursed_blast_escape()` is rung 5 of the §4.3 ladder; the engine machinery had existed since 2026-08-29 with no policy line reaching it. Kevin took option (a) unconditionally, not the going-second-only variant. Worth **0.5** — small, but it converts positions that were previously unwinnable by construction.
- **S-11 → the attachment is declined once D is paid.** Worth **−0.2**: it changes no outcome, only the board. Kept because it is correct by construction and because the fetches it declines were filling the Bench slot §4.4 reserves.
- **S-02 → Hilda takes both searches whatever the hand holds.** Kevin: *"make sure that Hilda always grabs an Energy... Hilda can find any type of Energy."* Her Energy search now falls through to Enriching Energy when no `[P]` source is findable, so a whiff there means something sharp — every Energy in the list is prized or discarded. Costs **0.3**; kept, same reason.
- **S-05 also → Ultra Ball's never-discard list gains "this turn's chosen Supporter"**, the general form of the existing Salvatore clause. Worth **0.7**. The discard *order* gained Night Stretcher and Ciphermaniac's third and fourth (worth 0.0 going second, 0.5 going first).

**Rates.** decklist2, 1,000 replicates: going second **52.6% → 75.8%**, going first **53.4% → 64.1%**, `item_lock` going first **49.0% → 60.7%**. Every point is attributed per change in `demo/demo_simulator_claude.md`.

**A method failure worth not repeating.** The first attribution run reported that ten of thirteen changes were worth exactly 0.0 — because the neutralising patches were multiline `perl` regexes written with `\n` against a **CRLF** source, so they matched nothing and `perl` still exited 0. The harness now `cmp`s each patched copy against the original and prints `SKIPPED` rather than measuring the unpatched policy. **A patch that silently does nothing reads as a change that costs nothing**, which is the same failure mode as the confidently-wrong diagnostics this project has hit three times.

**Open, and raised by the new bank rather than answered by it.**

- **PB-17, from S-20: the tree misses a position it could win.** With a Duskull Active, the line stranded on the Bench and a Rare Candy in hand, the Cursed Blast escape is one Dusknoir away — and **Dusknoir is an Evolution Pokémon, so Hilda can fetch it**. The want-list has no Dusknoir entry, so Hilda is never aimed at one and the Rare Candy has nothing to become. Should Dusknoir enter the want-list ahead of everything else exactly when the escape is the only route to C, the way Latias ex does when C is blocked? Not implemented — it is a new rule, and the documents are Kevin's.
- **DT-24 (S-15, 19.8% of games)**: the fallback plays Lillie's on a turn that is already won, where the eight cards are never used. Right, or noise in the board record?
- **DT-25 (S-16)**: Salvatore now outranks Hilda on turn 2 when the `[P]` source is secured. Is that the right discriminator, or should it be the evolution-timing case alone — the only thing Hilda genuinely cannot do?
- **PB-10 answered by unreachability.** The S-21 predicate — Night Stretcher in hand with a Bronzor or Bronzong in the discard — found **zero** examples in 500 games, because the Ultra Ball never-discard list keeps the line out of the discard in the first place. Recorded rather than deleted, so a decklist that changes the discard pattern re-raises it.

**Housekeeping.** §9 of the decision tree (the answers table and the corrections table) is **deleted**, closing the loose end logged in session 15. Its three rules that were stated only there were folded into their sections first — Switch over Surfer into §4.1 step 2, Ciphermaniac's confined to `P2T1` into §6, declining Run Around into §4.2 — and the rule set was diffed before the delete. Every `(Kevin, 2026-08-29)` stamp and every "the draft said…" clause is gone from both decision documents; §10 became §9 and now lists only what is still open. The generator gained position **dedupe**: two predicates matching the same seed used to render the same board twice under two ids, which asks one question while looking like two.

**Motif count that is no longer a defect.** "A turn ended with the Supporter slot unspent" is still the largest motif (393 of 1,000 going second), but only **80** of those replicates hold a Supporter at all: 28 a Salvatore with no Bronzor in play to put a Bronzong onto — not a legal declaration — and 56 a Ciphermaniac's whose stack the window can never draw. Hilda and Lillie's are **never** stranded. The number to watch is 80, not 393.

### 2026-08-30 (Session 17 — the second bank of answers, and the lead order stops being a guess)

Kevin answered all twelve positions in the S-15 to S-26 bank. Seven confirmed the
tree, four changed it, and one — S-24 — he explicitly refused to answer from
intuition and handed to the simulator. Order was documents → code → measure, per
`CLAUDE.md` → *The decision documents are the specification*.

**The answers, verbatim, because the bank itself is rewritten from S-27 and the
documents carry no history of their own.**

- **S-15** (19.8% of games, DT-24) — *"Yes, (a) is the clear answer."* Play the
  Lillie's on a turn that is already won. **DT-24 is now a ruling**, folded into
  §6 priority 8: the slot is destroyed if it is not used, and eight fresh cards
  are a better record of where the game stood.
- **S-16** (4.4%, DT-25) — *"(c) is the clear answer here."* The free Poké Pad
  finds the Bronzong and the Supporter slot is left for whatever is worth more
  afterwards. The general rule this states — **a free Item that closes the gap is
  played before the Supporter slot is considered at all** — is now the paragraph
  that opens §6. It also means **DT-25 was sidestepped rather than settled**: the
  Salvatore-versus-Hilda discriminator only ever binds where no Item can fetch
  the Bronzong, so DT-25 stays open, narrowed to that residual.
- **S-17** (2.4%) — *"(c) is the clear answer here."* Ultra Ball for the Bronzong
  outright **and then** Ciphermaniac's on top of it. Confirms the tree.
- **S-18** (4.8%, PB-16) — *"(c) is the correct choice — the turn will end with
  two different Bronzong, each with a Psychic energy attached."* This is a change,
  and it is the one that needed care: **S-26 says the opposite about a second
  Bronzor.** The two are not in conflict once the rule is scoped to the evolved
  body — a Bronzong holding a `[P]` source is a second attacker, a Bronzor holding
  one is still a Bronzor, and the Bench slots the Telepathic search would fill are
  worth more than the Energy. §4.2 step 6 now carries exactly that exception and
  no wider one.
- **S-19** (8%, DT-23 / PB-13) — *"Basically (b). The Supporter for the turn would
  be Ciphermaniac, but it's not too important since the goal is achieved already."*
  Rare Candy the benched Duskull into a Dusknoir on a turn that is already won.
  §8's non-goal is rewritten as being about **order** — Bronzong first, always;
  Dusknoir with what is left over.
- **S-20** (1.6%, PB-17) — *"(b) is the clear play, assuming there is a Dusknoir in
  the deck."* **This is the position the tree could win and did not.** Dusknoir now
  enters the want-list ahead of everything else exactly when the Cursed Blast
  escape is the only route to sub-goal C, and Hilda is aimed at it. The
  *"assuming there is a Dusknoir in the deck"* clause is ADR 0003 and is
  implemented as `believes_findable()`, so the promotion is the player's own
  deduction rather than a peek.
- **S-21** (0 examples, PB-10) — answered as a rule rather than a position:
  *"it's only okay to discard Bronzong… if there's a Night Stretcher in hand to
  easily re-find the Bronzong. It's almost always not ideal to discard Bronzor,
  because it will take an extra turn to evolve it into Bronzong unless there's a
  Salvatore in my hand."* The Ultra Ball never-discard list changes shape: the
  line is protected **by name rather than by count**, every copy included, and
  each is released only by the card that undoes the discard.
- **S-22** (12.8%, PB-09) — the longest answer, and two changes in it: *"I would
  Poke Pad for a Bronzor… Then… play the second Poke Pad to search for the
  Bronzong… Finally, I would attach the Enriching Energy onto the Latias ex, since
  it at least might have a chance to use the `[C]` in the future."* So **every
  Poké Pad in hand is played, not just the first**, and **Enriching Energy takes an
  attachment nothing else can use**, on a body that is not the attacker.
- **S-23** (9%, PB-07) — *"(a) is closer to the answer… it's critical to ensure
  Bronzor is on the field since I cannot evolve into Bronzong on the same turn
  Bronzor is played to the field."* Confirms the tree's division of labour: Poké
  Pad chases the Bronzor, Ultra Ball chases the Latias ex it is the only Item that
  can fetch.
- **S-24** (3% for that exact hand, DT-03) — *"Overall, opening Duskull would have
  been better, but this is something we would need the Monte Carlo simulator to
  answer decisively."* Handed to the simulator; see below.
- **S-25** (11.6%, DT-01) — *"Play Meowth ex onto the bench to find a Hilda, which
  will find both the Bronzong and `[P]` energy."* Confirms the tree.
- **S-26** (5.2%, PB-15 / DT-02) — *"(a) is the clear answer."* Attach nothing and
  leave the last Bench slot empty. Confirms the tree, and supplies the principle
  that narrows PB-15: on turn 2 a fetch whose only effect is to occupy a Bench slot
  buys nothing.

**Two places the letter of an answer was not followed, both flagged to Kevin
rather than buried.**

- **S-19's Supporter.** He named Ciphermaniac's and marked the choice unimportant.
  On a won turn 2 a Ciphermaniac's stack is two cards the window can never draw,
  while the Salvatore the fallback prefers puts a second Bronzong onto the benched
  Bronzor. The fallback order was left as it is and the question raised as
  **DT-26**.
- **DT-23's other half.** He ruled on the turn that is already *won*. Applying the
  same Rare Candy to a turn already *lost* is written into §8 as a proposal, and
  DT-23 stays in the register narrowed to that half.

**A latent crash the lead-order search found before a run did.** The first sweep
died on `card TEF-160 is not in zone 'hand'`. `.kill_line_is_live()` gates entry to
the §4.1 kill line, but the free Items run *inside* it and can make the line dead
again: Ultra Ball protects the Salvatore only while the line is live, liveness
reads `believes_findable()`, and a search that takes the last Bronzong out of the
**deck** — into hand, where Salvatore cannot reach it and turn 1 cannot evolve it —
releases the Salvatore onto the discard order. `is_salvatore_target()` then still
answers TRUE, because it reads public information and deliberately keeps a prized
Bronzong declarable, so it is no substitute for holding the card. The line now
re-checks both halves. **The general lesson is the one this project keeps
relearning**: a guard evaluated once at the top of a sequence is not a guard on the
sequence, and the second Poké Pad — a change worth a fraction of a point — is what
made a two-year-old-shaped bug common enough to fire.

**Rates.** decklist2, 1,000 replicates: going second **75.8% → 77.5%**, going
first **64.1% → 64.3%**, `item_lock` going first **60.7% → 61.6%**. That is
**1.7 points** against the previous bank's 23, and the honest reading is that the
policy is mostly right now: seven of twelve answers confirmed the tree. Two of the
changes measure exactly **0.0** and are supposed to — S-18 and S-19 alter the
board the window closes on, not whether the attack happens.

**The methodological addition worth keeping is the noise floor.** At 1,000 paired
replicates the standard error on a per-change difference is 0.2–0.4 points, so
most rows in `results/change_attribution.md` are honestly zero, and the file now
says so at the top. The previous session's table had no such line, and every row
in it was read as a measurement.

### 2026-08-30 (Session 17, part 2 — DT-03 settled, and the lead order stops being a guess)

Kevin's S-24 answer was *"we would need the Monte Carlo simulator to answer
decisively"*, and this is that. Recorded as **ADR 0008**, because the *method* is
the part worth re-reading rather than the answer.

- **The confounding was the whole problem, and it took a while to see.**
  `summarise_run()`'s `lead_hit_df` groups every replicate by the Basic that led
  and looks exactly like the right table. It is not: the hand that contains a
  Kangaskhan is not the hand that contains a Duskull, so it compares leads across
  different hands and reports a property of the hands. The lead is not
  randomised; it is chosen, by the rule under test. **The trace file's own header
  said "this is what settles it"** and has been rewritten to say the opposite.
- **The experiment is to vary the order**, which is what the policy controls, and
  read the cell rate. `LEAD_ORDER_LIST` and `make_policy_placement()` exist so
  `setup_game()`'s `placement_fn(state)` hook can carry it.
- **Greedy positional search, not 720 permutations.** Twenty evaluations per cell,
  valid because only the top-ranked Basic actually present in the hand is ever
  used, so the order acts as a ranking rather than as a sequence.
- **Out-of-sample confirmation is the step that mattered.** Going second the
  winner held on two disjoint seed blocks (+1.3, then **+0.68 with a standard
  error of 0.20**, paired). Going first it did not: three orders landed within
  **0.22 points**, so that branch was **left exactly as it was**. A greedy search
  is the maximum of twenty noisy numbers and will always report a winner.

**What moved, and what did not.** Kevin's specific guess — that Duskull would beat
Kangaskhan — was **not confirmed**; Kangaskhan is ahead in both cells. What
changed is the pair he was not asked about: **Latias ex rises from last to first
going second, and Buneary falls from second to last.** Buneary's fall is the tree
agreeing with itself at last — its whole case as a lead is Run Around, and §4.2
classes Run Around as a last resort because it spends the turn's Energy attachment
and strands it on the Bench.

**And the finding that outranks the ranking: the lead order is worth about a
point.** At rank 1 going second the six candidates span 74.9% to 75.8%. Against
the 23 points the Supporter rules moved, that is a rounding error — worth getting
right, and not where the deck is won.

### 2026-08-30 (Session 17, part 3 — two new decklists, ten new cards)

Kevin dropped **decklist7 and decklist8** into `decklists/` mid-session, and the
test suite found them within the minute: `unknown card id(s): PBL-063, SFA-019,
TWM-134, TWM-095, MEG-127, PBL-078, MEG-167, MEE-007`. They are **a different
deck, not a variation** on the six-list shell — no Mega Kangaskhan ex, no Boss's
Orders, no Ciphermaniac's, Rare Candy cut to 1, and a Darkness sub-theme.

**All ten cards were transcribed from primary sources, and the second query earned
its keep for the third time.** limitlesstcg lists **Dunsparce JTG 120's Trading
Places as an Ability**; pokemon.com and Bulbapedia both give it as an **attack
costing `[C]`**. That is the difference between a free rung on the §4.3 ladder and
a last resort that ends the turn — after Evolution Jammer and Itchy Pollen, the
third time this source has mis-rendered an attack as an Ability.

**Two of the ten cards cannot be used at all in the lists that run them**, and
both are decklist questions rather than simulator ones:

- **Blissey ex TWM 134 evolves from Chansey**, and neither list runs one. Rare
  Candy is Basic → Stage 2 and cannot reach a Stage 1; Salvatore fetches a card
  that evolves from a Pokémon we control. There is no route.
- **Buddy-Buddy Poffin cannot fetch a Bronzor in either list.** Both printings
  they run are 80 HP — TEF 68 and the new PBL 63 — against Poffin's 70 HP cap.
  Its only legal targets there are Duskull, Buneary and Dunsparce.

That is four of sixty cards in decklist7 doing nothing, and it still finishes in
the registry's top tier, which says something about how much slack the deck has.

**Two rules were implemented rather than deferred**, because scoring a list while
ignoring its cards is the confidently-wrong-number failure again:

- **Gwynn** (`play_gwynn()`), a draw Supporter that **keeps the hand** and pays in
  spare Pokémon. Which Pokémon count as spare reuses the Ultra Ball never-discard
  list rather than inventing a second one — two lists answering "which cards are
  spare" will disagree, and the disagreement will be silent. Extracting
  `.line_keep_idx()` was forced by a real recursion: `.ultra_ball_keep_idx()` asks
  `.choose_supporter()`, and Gwynn's branch inside that would have called back
  into itself.
- **Risky Ruins is never played**, under §4.2 step 7's existing *"not disruptive
  to us"*. Its text damages every Basic non-`[D]` Pokémon **any player** benches,
  and with no opposing board modelled that is only ever ours.

### 2026-08-30 (Session 17, part 4 — a document that disagreed with itself)

Reordering §6 to match the document surfaced something neither
`/align-decision-tree` direction had caught: **§6's priority table and §6's own
prose disagreed.** The table numbered Lillie's at 5 and Ciphermaniac's at 7; the
prose under Ciphermaniac's read *"it is not the answer to a hand missing three
things; there Lillie's, which replaces the whole hand, is"* — which only parses if
Ciphermaniac's is ahead. The code followed the prose. A test pinned the code.

**Measured, the prose is right by 1.92 points with a standard error of 0.22**
(4,000 paired replicates). The mechanism is clean: Ciphermaniac's is a **tutor**
for the one card the turn is missing, and Lillie's is **eight random cards out of
forty**. A tutor beats a lottery when the target is one named card. The table is
renumbered and now carries the measurement.

**The lesson is about where to look.** Both `/align-decision-tree` directions ask
whether the code and the document agree. Neither asks whether **the document
agrees with itself**, and a numbered table sitting above prose that argues against
it is exactly the shape that survives both audits.

### 2026-08-30 (Session 17, part 5 — the registry, and what it can and cannot say)

`scripts/score_decklists_claude.R` is part 6's first piece: **24 cells** — eight
decklists × {going second `clear`, going first `clear`, going first `item_lock`} —
at 1,000 replicates each. There is no going-second `item_lock` cell, because Itchy
Pollen is an attack and only a player who went second can use it.

**The first thing the registry says is what it cannot say.** At 1,000 replicates
the standard error on a rate near 75% is ±1.4 points and on a difference between
two decklists ±2.0, so a gap under about **4 points** is not resolved. The field
sorts into three tiers rather than eight positions, and **the top five (7, 5, 8, 2,
4) are a tie** inside a 1.5-point band. That caveat is generated into
`results/registry.md` rather than left to the reader.

**What is resolved is decklist1, and its cause.** It is the only list with no
Telepathic Psychic Energy, running four basic Psychic instead, and it is last in
every cell — by 13.7 points going second and **18.6 under the Item lock**. The
mechanism is visible rather than inferred: **its sub-goal A fails 101 times
against decklist2's 43**, on lists that both run two Bronzor. A basic Psychic
Energy pays sub-goal D and does nothing else; a Telepathic pays D **and** searches
two Basic `[P]` Pokémon onto the Bench, which is A's cheapest out and costs no
card. **The energy base is an A question wearing a D costume**, and that is the
most useful thing the registry found.

**Salvatore buys turn-1 kills and almost no rate**, which is ADR 0004 working as
designed. The two lists without it are the only two with a turn-1 count of zero;
every other list lands between 25 and 36 in 1,000 games. Its value has to be
argued from the turn-1 column, never from the hit rate.

**Sub-goal D is the largest unmet count in all 24 cells.** §1 claims C is the one
that actually fails, and DT-01 has been open on it since the first run; the claim
has now survived the rate rising twenty-five points without C and D changing
places. Not refuted — D can only be *unmet* once B and C are met — but worth
deciding rather than leaving open.

### 2026-08-30 (Session 17, part 6 — the third bank, and two more latent guards)

`docs/03b_scenarios.md` is rewritten as **S-27 to S-39**, and three things about it
are deliberate departures:

- **It leaves the going-second `clear` cell.** Every position S-15 to S-26 came
  from there, and that is one of three cells the registry reports — so two thirds
  of what the project measures had never been put as a question. **S-33, turn 2
  under the Item lock, arises in 30.2% of games** and is the most common position
  ever put in this file.
- **It leaves decklist2**, because decklist7's questions cannot be asked from it.
- **It asks about turns the metric has already lost**, since that is where the
  next decision defect lives.

**Two latent defects were found by reading the generator's own appendix**, which is
worth noting as a technique: the appendix prints what the policy *actually does*
from each captured position, and a line that reads oddly is a defect report.

- **S-27's line ended with a Meowth ex benched to fetch a Hilda that could never
  be played**, because Gwynn had already taken the Supporter slot.
  `.policy_bench_meowth()` checked that a Supporter was *wanted* and never that
  one could still be *played*. Fixed, with §4.4 gaining the clause.
- **S-39 is a defect the tree has not yet fixed, and it is the bank's headline.**
  With no Bronzor in play the policy attaches a Telepathic to whatever `[P]` body
  it has, purely to fire the search — and **the search is what puts the Bronzor
  into play**, one step too late to receive the Energy. The turn's one attachment
  buys sub-goal A and throws away sub-goal D. It arises in 3.8% of games, and D is
  the largest unmet count in every registry cell. Left for Kevin, because it is a
  rule change and the documents are his.

**Both this and the kill-line crash are the same class**, and it now has a name in
`CLAUDE_kevin.md`: **a guard evaluated once at the top of a sequence is not a guard
on the sequence.** Both were latent for weeks and became common only when an
unrelated change made the sequence frequent — a second Poké Pad in one case, Gwynn
taking the slot in the other.

**One tooling note.** A `cat <<'EOF'` heredoc silently ate a backslash while
writing an R regex into a test file: `"\\1-\\2"` arrived as `"\1-\2"`, and the test
then failed with a substitution that had matched nothing — the same
silent-wrong-answer shape as the CRLF patch failure. Write anything containing
backslashes with the file-writing tools.

### 2026-08-30 (Session 17, part 7 — /align-decision-tree, red and green)

Two agents in one message, one per direction, kept strictly apart because the
skill's own history says an agent asked for "any divergence" finds one kind and
stops. **18 red and 28 green**, and neither list contained the other's items.

**Step 1 mattered more than it looks.** The section-to-function map at the top of
`R/decision_claude.R` had no row for §1, §2, §4.5 or §9, and an absent row reads
as *not implemented* — which is the shape a divergence hides in. Every section
has a row now, including the two that describe rather than instruct, and the
three **specified and not implemented** cards are recorded as deliberately having
no function.

**Twelve red findings became code fixes, each with a test written first and
watched fail.** The ones worth remembering:

- **"In play" meant "on the Bench."** Three predicates asked
  `.bench_idx_named()` where both documents say *in play*, so an **Active** Latias
  ex was invisible to all of them. Survivable while §3 ranked Latias ex last —
  and ADR 0008 had just moved it to **first going second**, which is what turned
  a dormant bug into a live one. The lesson is the pairing rather than either
  half: a tuning change made a stale predicate expensive.
- **Want-list item 4's second clause reads "and **Bronzor** is not Active"** and
  was coded as "sub-goal C is not met", i.e. *Bronzong* not Active. So with a
  Bronzor Active the policy kept chasing a mover it did not need. **This one fix
  is worth 2.0 points going first on decklist7** and is almost the whole
  alignment gain.
- **Rare Candy had no discard protection at all**, though the playbook's order
  says "**surplus** Rare Candy" and its own entry says "never spending a copy the
  rung-5 escape still needs". decklist7 and decklist8 run **one**, so a single
  Ultra Ball could close the §4.3 rung-5 escape for the whole game. Same for
  "surplus Duskull beyond 1", which was never implemented either.
- **Hilda's Energy search was the literal `c(Telepathic, Psychic, Enriching)`**
  where the playbook says she "takes **any** Energy card". Basic Darkness Energy
  was invisible, and decklist7 runs three of them and no basic Psychic — so she
  could log `DECLINED` with Energy still in the deck, which is exactly the sharp
  inference the document says a whiff licenses.
- **A single Brock's or Poffin could fetch two Bronzor**, because `.want_vec()`
  emits every *printing* as its own entry and the multi-target loops walk them one
  at a time. The playbook is explicit that the list does not chase a second
  Bronzor, and that it cost 1.4 points where it used to sit there. Invisible on
  the six single-printing lists, which is why it survived every earlier audit.
- **The Telepathic went to Bench order rather than to the `[P]` printing**, so a
  Metal Bronzor in the first slot swallowed the attachment and fired nothing.
- **A second Latias ex was benched** while one was already in play, spending a
  slot §2 calls the fourth scarce resource. decklist7 and decklist8 run two.
- **The §6 priority 8 fallback was not last.** Five plays ran after it, and a
  fallback Lillie's shuffled away the **Dusknoir** §8's leftover Rare Candy needs
  — §4.4's bench-before-Lillie's rule saves Basics, and a Dusknoir is a Stage 2.
  The Stadium and the Rare Candy now precede the fallback.

**A thirteenth, found outside the agents' scope while they ran.** `unused_outs()`
in `R/trace_claude.R` held the Bronzor printings as a **hand-maintained literal of
three ids**, and PBL 63 arrived as a fourth. So a decklist7 trace could report *no
unused out* with a Bronzor sitting in hand — which reads as a **deck** problem
when it is a **decision** problem. This is the confidently-wrong-diagnostic
failure in its worst variant, because it **under**-reports and therefore raises
nothing at all. Fixed by resolving Bronzor by NAME at run time; every other site
in that file already did.

**Two red findings were resolved by changing the document instead**, and both are
worth saying out loud because the reflex is to change the code:

- **`03a` said every shuffling card must check the pending-stack flag.** Guarding
  the *Supporters* would mean playing **no Supporter at all on turn 2** whenever a
  `P2T1` Ciphermaniac's had fired — against §6 priority 8, the largest rule in the
  document — to protect a second stacked card the window can only reach through a
  draw effect. The rule is narrowed to Items, which is what it always meant.
- **§6 claimed "one evolution … capped at once per turn by the rules".** The rules
  cap evolution *per Pokémon*, not per turn, and §4.2 step 6's second-Bronzong
  exception presumes two Bronzong on one turn — which is what S-18 asked for. The
  document was simply wrong about the game.

**And one finding was a document arguing with itself, which neither audit
direction is built to catch.** §6's priority table numbered Lillie's at 5 and
Ciphermaniac's at 7; the prose under Ciphermaniac's argued the reverse. Both
`/align-decision-tree` directions ask whether the code and the document agree;
neither asks whether **the document agrees with itself**, and a numbered table
sitting above prose that contradicts it survives both. Worth adding to the skill.

**The 28 green findings are all written into the documents** rather than left in
a chat message, per step 4 — as rules where the code is clearly right, and as
**defaults rather than rulings** where it is a judgement call. Five new register
entries came out of it: **DT-28** (unranked Basics tie-broken by hand order, with
Meowth ex tying where §3 rules it out), **DT-29** (every Poké Pad but only one
Poffin, though Poffin is free too), **DT-30** (Ciphermaniac's declined when A is
unmet — should it stack the **Bronzor** instead?), **DT-31** (a fallback Brock's
has no mode rule), **DT-32** (§7 numbers C before B and the turn does the
reverse), plus **PB-19** and **PB-20**.

**Attribution.** decklist7 **79.0% → 80.5%** going second, **65.8% → 67.2%** going
first, **63.7% → 65.1%** under the lock — and essentially all of it is the
want-list item 4 fix. decklist2 moved +0.3 / −0.4 / −0.4, which is **unattributed
and is noise**: both fixes measured on it come out at 0.0, and seven of the nine
need two Bronzor printings, two Latias ex or a Darkness Energy to bite at all.

**One fix costs points and stays**: protecting a Duskull and a Rare Candy is worth
+0.4 going second and **−0.6 going first**, because a protected Duskull more often
leaves Ultra Ball with fewer than two spare cards. It stays because the playbook
says so and because decklist7 and decklist8 run one Rare Candy. It is also why
**decklist1 fell 1.7 points** — that list leans on Ultra Ball hardest, having no
Telepathic search to find bodies for free.

**The registry re-run sharpened the field.** Five lists inside 1.5 points became
**three** — decklist5, decklist7 and decklist8, level in all three cells — with
decklist2 and decklist4 a clear 1.7 behind and decklist1 now **18.4** behind.
2,080 assertions pass.
