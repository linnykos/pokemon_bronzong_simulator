# How the Bronzong simulator works

*Kevin Z. Lin &mdash; 2026-08-29*



# Overview

This is a walkthrough of the simulator as it stands, built to be argued with.
The policy it runs — `R/decision_claude.R` — is a **first draft translation of
`docs/03_decision_tree.md`**, written so the tree and the code can be read side
by side. It will make choices you disagree with. Those disagreements are the
output this document is for.

**The question the whole thing answers:** over many simulated games, how often
can the player attack with **Evolution Jammer on or before their own turn 2**?
One fixed bar, the same going first and going second (ADR 0004), reported
separately for the two coin-flip branches and never pooled (ADR 0002).

| Stage | What it does | Functions |
|---|---|---|
| Setup | Shuffle, mulligan, place the Active, set prizes | `setup_game()`, `policy_placement()` |
| Turns 1–2 | Draw, then play the decision tree | `policy_turn()`, `play_replicate()` |
| Measure | One replicate → hit / miss, turn achieved, diagnosis | `summarise_replicate()` |
| Aggregate | Many replicates → one rate per cell | `summarise_run()` |
| Diagnose | A stratified sample of readable traces | `write_trace_file()` |

Two things the simulator is careful about, because both are easy to get silently
wrong:

- **The policy may not see hidden information** (ADR 0003). It reads the hand,
  the board and the discard, plus a belief state that only learns what a real
  player would learn. A search that fails because the card was prized is
  information the player *earns*.
- **Mulligans are never a miss** (ADR 0005). A hand with no Basic is redrawn and
  the redraw is played; the cost is reported beside the rate, never folded into
  it.

``` r
for(one_file in list.files("../R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

card_df <- build_card_database()
decklist <- read_decklist("../decklists/decklist2.txt", card_df)
```

# The deck

`decklist2`, chosen because it runs **both** Salvatore and Latias ex — so the
turn-1 kill line and the free-retreat rung of the §4.3 ladder both get
exercised.

``` r
count_vec <- decklist$count_vec
data.frame(count = as.integer(count_vec),
           card = lookup_card(card_df, names(count_vec))$name,
           row.names = NULL)
```

```
   count                        card
1      1                       Budew
2      2             Night Stretcher
3      2          Mega Kangaskhan ex
4      2               Boss's Orders
5      4      Lillie's Determination
6      4                  Rare Candy
7      3                      Switch
8      4                  Ultra Ball
9      2                     Buneary
10     2             Mega Lopunny ex
11     1                   Meowth ex
12     4                    Poke Pad
13     4   Telepathic Psychic Energy
14     4                     Duskull
15     2                    Dusclops
16     4                    Dusknoir
17     1                   Latias ex
18     1            Enriching Energy
19     2                     Bronzor
20     2                    Bronzong
21     1                Flutter Mane
22     2 Ciphermaniac's Codebreaking
23     1                   Salvatore
24     1               Jamming Tower
25     4                       Hilda
```

The four sub-goals that must all hold at the attack step, from §1 of the
decision tree:

| | Sub-goal | Satisfied by |
|---|---|---|
| **A** | A Bronzor is in play | setup, Poké Pad, Ultra Ball, Brock's Scouting, benching one |
| **B** | Bronzong is on it | Hilda, Salvatore, or drawn and evolved |
| **C** | Bronzong is **Active** | led at setup, free retreat, Switch, Surfer, Run Around, Cursed Blast |
| **D** | A `[P]` source is attached | basic Psychic or Telepathic Psychic Energy |

# One game, played slowly

The most useful part of this document. A single seed, going second, played turn
by turn — every decision the policy takes is logged as it happens.

``` r
seed_number <- 8L

pair <- setup_game(decklist, card_df,
                   bool_going_first = FALSE,
                   placement_fn = policy_placement,
                   seed_number = seed_number)

print(paste0("opening hand: ",
             paste0(lookup_card(card_df, pair$state$hand_vec)$name,
                    collapse = ", ")))
print(paste0("led: ", lookup_card(card_df, top_card(pair$state$active))$name))
print(paste0("bench: ", length(pair$state$bench_list), " Pokemon"))
```

```
[1] "opening hand: Telepathic Psychic Energy, Salvatore, Telepathic Psychic Energy, Rare Candy, Rare Candy, Dusknoir"
[1] "led: Flutter Mane"
[1] "bench: 0 Pokemon"
```

Note the empty Bench. §3 says to place the Active and stop: a benched Basic can
never be un-benched, and the slots are wanted for Latias ex.

## Turn 1

``` r
pair$state <- begin_turn(pair$state)
pair <- draw_to_hand(pair, num_cards = 1L)
pair <- policy_turn(pair)

writeLines(readable_log(pair$state, turn_number = 1L))
```

```
attach TelepathicPsychicEnergy to FlutterMane
Telepathic Psychic Energy -> Bronzor(TEF), Latiasex
evolve into Bronzong
Salvatore -> Bronzong
promote Bronzong via retreat(free)
```

## Turn 2

``` r
pair$state <- begin_turn(pair$state)
pair <- draw_to_hand(pair, num_cards = 1L)
pair <- policy_turn(pair)

writeLines(readable_log(pair$state, turn_number = 2L))
```

```
attach TelepathicPsychicEnergy to Bronzong
Telepathic Psychic Energy -> Duskull, Bronzor(TEF)
EVOLUTION JAMMER
```

## What the window closed on

``` r
result <- summarise_replicate(pair, decklist$decklist_id, seed_number,
                              bool_keep_trace = TRUE)

print(paste0("hit: ", result$bool_hit,
             "   turn achieved: ", result$jammer_turn))
writeLines(result$trace_vec)
```

```
[1] "hit: TRUE   turn achieved: 2"
#8  HIT t2
  setup hand[RareCandy+RareCandy+TelepathicPsychicEnergy+TelepathicPsychicEnergy+Dusknoir+FlutterMane+Salvatore] | lead FlutterMane
  T1    attach TelepathicPsychicEnergy to FlutterMane | Telepathic Psychic Energy -> Bronzor(TEF), Latiasex | evolve into Bronzong | Salvatore -> Bronzong | promote Bronzong via retreat(free)
  T2    attach TelepathicPsychicEnergy to Bronzong | Telepathic Psychic Energy -> Duskull, Bronzor(TEF) | EVOLUTION JAMMER
  end of turn 2 -- board state when the window closed; setup lead=FlutterMane
    active   Bronzor(TEF)>Bronzong[P]{TelepathicPsychicEnergy} played=T1 evo=T1
    bench    FlutterMane[P]{TelepathicPsychicEnergy} played=T0 | Latiasex[P] played=T1 | Duskull[P] played=T2 | Bronzor(TEF)[P] played=T2
    hand     RareCandy, RareCandy, Dusknoir, BosssOrders, Buneary
    discard  Salvatore
    zones    deck=40 prizes=6 stadium=-
    turn     energy=spent supporter=unplayed items=open
    prized   GROUND TRUTH, never visible to the policy (ADR 0003): Duskull, Budew, PokePad, Bronzong, NightStretcher, TelepathicPsychicEnergy
```

That block is what a trace looks like. `end of turn 2` is recorded in full
(ADR 0007) because the board reached by turn 2 is a question worth asking later,
and the window stops there — there is no turn 3 anywhere in the simulator.

# Both cells, at scale

Going first and going second are different games and get different numbers. Each
cell is 1,000 replicates of the `clear` scenario.

``` r
num_replicates <- 1000L

run_cell <- function(bool_going_first, scenario = "clear"){
  lapply(seq_len(num_replicates), function(i){
    one_pair <- play_replicate(decklist, card_df,
                               bool_going_first = bool_going_first,
                               scenario = scenario,
                               seed_number = i)
    summarise_replicate(one_pair, decklist$decklist_id, i)
  })
}

second_list <- run_cell(bool_going_first = FALSE)
first_list <- run_cell(bool_going_first = TRUE)

second_summary <- summarise_run(second_list)
first_summary <- summarise_run(first_list)

data.frame(cell = c("going second", "going first"),
           hit_rate = c(second_summary$hit_rate, first_summary$hit_rate),
           turn1 = c(second_summary$turn_tally_vec[["t1"]],
                     first_summary$turn_tally_vec[["t1"]]),
           turn2 = c(second_summary$turn_tally_vec[["t2"]],
                     first_summary$turn_tally_vec[["t2"]]),
           never = c(second_summary$turn_tally_vec[["never"]],
                     first_summary$turn_tally_vec[["never"]]),
           row.names = NULL)
```

```
          cell hit_rate turn1 turn2 never
1 going second    0.758    30   728   242
2  going first    0.641     0   641   359
```

Going second hits on turn 1 sometimes and going first never does — that is
Salvatore, and it is the only place its speed is visible, because the primary
outcome deliberately prices a turn-1 kill and a turn-2 conventional line the
same.

**Mulligans, reported beside the rate and never inside it** (ADR 0005):

``` r
data.frame(cell = c("going second", "going first"),
           mulligan_rate = c(second_summary$mulligan_rate,
                             first_summary$mulligan_rate),
           mean_mulligans = c(second_summary$mean_mulligans,
                              first_summary$mean_mulligans),
           row.names = NULL)
```

```
          cell mulligan_rate mean_mulligans
1 going second         0.135          0.149
2  going first         0.135          0.149
```

## Which sub-goal actually fails

Counted as a **set**, so a miss appears in every row it belongs to. Rows sum to
more than the miss count on purpose: reporting only the first unmet sub-goal
made C look like it never failed, which is the exact opposite of the truth.

``` r
data.frame(subgoal = names(SUBGOAL_VEC),
           meaning = as.character(SUBGOAL_VEC),
           going_second = as.integer(second_summary$unmet_tally_vec),
           going_first = as.integer(first_summary$unmet_tally_vec),
           row.names = NULL)
```

```
  subgoal          meaning going_second going_first
1       A  bronzor_in_play           51          54
2       B   bronzong_on_it          153         252
3       C  bronzong_active          177         282
4       D psychic_attached          221         337
```

§1 of the decision tree claims **C is the sub-goal that actually fails** —
getting Bronzong *Active*, not drawing it. These counts are the first real test
of that claim.

## Hit rate by the Basic that led

§3's lead order is an untested default that you asked to settle from the logs.
This is the table that settles it — computed over every replicate, so unlike the
traces it may be read as a rate.

``` r
lead_df <- second_summary$lead_hit_df
lead_df$lead <- lookup_card(card_df, lead_df$lead_card_id)$name
lead_df[order(-lead_df$hit_rate), c("lead", "num_replicates", "num_hit",
                                    "hit_rate")]
```

```
                lead num_replicates num_hit  hit_rate
7            Bronzor            251     226 0.9003984
2 Mega Kangaskhan ex            215     162 0.7534884
6          Latias ex             32      24 0.7500000
5            Duskull            243     180 0.7407407
1              Budew             41      29 0.7073171
4          Meowth ex             26      17 0.6538462
3            Buneary            164     104 0.6341463
8       Flutter Mane             28      16 0.5714286
```

``` r
plot_df <- lead_df[order(lead_df$hit_rate), ]
graphics::par(mar = c(4, 11, 2, 2))
graphics::barplot(plot_df$hit_rate, names.arg = plot_df$lead, horiz = TRUE,
                  las = 1, xlim = c(0, 1), col = "#4C72B0",
                  xlab = "hit rate (Evolution Jammer by turn 2)")
graphics::abline(v = second_summary$hit_rate, lty = 2, col = "#C44E52")
```

![Hit rate by opening lead, going second](figure/fig-12.png)

The dashed line is the cell's overall rate. Leading a Bronzor is worth far more
than any other lead, which is what §3 assumes.

**Two things in this table argue against §3 as written**, and both need a better
policy before they are worth acting on:


- **§3's choice of Mega Kangaskhan ex looks right, but only once Run Errand is
  actually used** (75.3%, n = 215).
  In the first draft of this policy it came out near the bottom at 40.9%, purely
  because the policy never used the Ability. Implementing a two-card draw moved
  one lead by 15 points — worth remembering before reading any of these numbers
  as facts about the *deck* rather than about the *policy*.
- **Buneary is §3's second choice and comes out second from last**
  (63.4%, n = 164). Its whole case is Run
  Around, which §4.2 then makes a last resort because it spends the turn's
  Energy attachment. That may be the tree disagreeing with itself.
- **Latias ex is the best non-Bronzor lead here**
  (75.0%, n = 32), and §3 says to lead it
  only when nothing else is available. Skyliner works from the Bench, so the
  tree's reasoning is sound — but leading it does get the free retreat online on
  turn 1 with no card spent. The sample is small; treat it as a question, not a
  result.

This is exactly the loop the trace machinery exists for: the tree makes a claim,
the run tests it, and the disagreement is where the next revision goes.

## Play motifs

Counted over every miss. These are the counts to act on: each one names a
pattern the policy produced, so a high count is a decision to change rather than
a card to add.

``` r
data.frame(motif = as.character(MOTIF_VEC),
           going_second = as.integer(second_summary$motif_tally_vec),
           going_first = as.integer(first_summary$motif_tally_vec),
           row.names = NULL)
```

```
                                                  motif going_second
1 Telepathic attached to a Colorless body (search dead)            0
2                a search resolved with no target named           19
3        Bronzor/Bronzong in play but never made Active           28
4          a turn ended with the Supporter slot unspent          140
5   combo assembled but Evolution Jammer never declared            0
  going_first
1           0
2          13
3          44
4         104
5           0
```

**"A turn ended with the Supporter slot unspent" is still the largest count, and
it is no longer a defect.** §6 priority 8 now plays a Supporter whenever one can
do anything, so the remaining count is hands that had none to play. Going second,
393 replicates in 1,000 end turn 2 with the slot unspent, and only **80** of those
still hold a Supporter at all — 28 a Salvatore with no Bronzor in play to put a
Bronzong onto, which is not a legal declaration, and 56 a Ciphermaniac's, whose
stack the window can never draw. **Hilda and Lillie's are never stranded.** The
motif is worth keeping because it would catch a regression, but the number to
watch is 80, not 393.

# The trace file

The second output. A run writes a small sample of readable traces, **stratified
toward misses on purpose** (ADR 0006), because hits teach nothing about what to
change.

``` r
sampler <- new_trace_sampler(max_miss = 8L, max_hit = 2L)
trace_list <- list()

for(i in seq_along(second_list)){
  take_list <- sampler_take(sampler, second_list[[i]]$bool_hit)
  sampler <- take_list$sampler
  if(!take_list$bool_keep) next

  one_pair <- play_replicate(decklist, card_df, bool_going_first = FALSE,
                             seed_number = i)
  trace_list[[length(trace_list) + 1]] <- summarise_replicate(
    one_pair, decklist$decklist_id, i, bool_keep_trace = TRUE)
}

trace_path <- "demo_traces.txt"
write_trace_file(trace_list, trace_path, second_summary, decklist = decklist)
```

> **Never compute a rate from a trace file.** The sample is deliberately not
> representative of the outcome distribution — it is roughly 80% misses by
> construction. The file leads with the true rates for exactly this reason, and
> the natural thing for a reader to do is count the traces anyway.

Two of the sampled traces:

``` r
line_vec <- readLines(trace_path)
start_idx <- grep("^#[0-9]+/", line_vec)
writeLines(line_vec[start_idx[1]:(start_idx[3] - 1)])
```

```
#1/10 seed=1  HIT t2
  setup hand[Budew+MegaKangaskhanex+Buneary+TelepathicPsychicEnergy+Duskull+Dusknoir+Hilda] | lead MegaKangaskhanex
  T1    hand[Budew+Buneary+TelepathicPsychicEnergy+Duskull+Dusknoir+Dusknoir+Hilda] | Run Errand | bench Latiasex | Hilda (evolution) -> Bronzong | Hilda (energy) -> TelepathicPsychicEnergy | attach TelepathicPsychicEnergy to Latiasex | Telepathic Psychic Energy -> Bronzor(TEF), Duskull | promote Bronzor(TEF) via retreat(free)
  T2    hand[Budew+LilliesDetermination+Buneary+TelepathicPsychicEnergy+Duskull+Dusclops+Dusknoir+Dusknoir+Bronzong] | evolve into Bronzong | attach TelepathicPsychicEnergy to Bronzong | Telepathic Psychic Energy -> Duskull, FlutterMane | Lillie's Determination, drew 8 | EVOLUTION JAMMER
  end of turn 2 -- board state when the window closed; setup lead=MegaKangaskhanex
    active   Bronzor(TEF)>Bronzong[P]{TelepathicPsychicEnergy} played=T1 evo=T2
    bench    Latiasex[P]{TelepathicPsychicEnergy} played=T1 | MegaKangaskhanex[C] played=T0 | Duskull[P] played=T1 | Duskull[P] played=T2 | FlutterMane[P] played=T2
    hand     Duskull, Duskull, CiphermaniacsCodebreaking, Switch, Hilda, LilliesDetermination, MegaLopunnyex, Dusknoir
    discard  Hilda, LilliesDetermination
    zones    deck=35 prizes=6 stadium=-
    turn     energy=spent supporter=played items=open
    prized   GROUND TRUTH, never visible to the policy (ADR 0003): RareCandy, Switch, Bronzong, TelepathicPsychicEnergy, UltraBall, Bronzor(TEF)

#2/10 seed=2 mull=1  HIT t2
  setup hand[Budew+UltraBall+Meowthex+Duskull+Duskull+Bronzong+FlutterMane] | lead Duskull
  T1    hand[Budew+MegaKangaskhanex+UltraBall+Meowthex+Duskull+Bronzong+FlutterMane] | bench Meowthex | Last-Ditch Catch -> Hilda | Ultra Ball -> Bronzor(TEF) | Hilda (evolution) -> Bronzong | Hilda (energy) -> TelepathicPsychicEnergy | bench Bronzor(TEF) | attach TelepathicPsychicEnergy to Bronzor(TEF) | Telepathic Psychic Energy -> Latiasex | promote Bronzor(TEF) via retreat(free)
  T2    hand[Budew+MegaKangaskhanex+Switch+Bronzong+Bronzong] | evolve into Bronzong | EVOLUTION JAMMER
  end of turn 2 -- board state when the window closed; setup lead=Duskull
    active   Bronzor(TEF)>Bronzong[P]{TelepathicPsychicEnergy} played=T1 evo=T2
    bench    Meowthex[C] played=T1 | Duskull[P] played=T0 | Latiasex[P] played=T1
    hand     Budew, MegaKangaskhanex, Bronzong, Switch
    discard  UltraBall, Duskull, FlutterMane, Hilda
    zones    deck=40 prizes=6 stadium=-
    turn     energy=unspent supporter=unplayed items=open
    prized   GROUND TRUTH, never visible to the policy (ADR 0003): Hilda, Switch, Hilda, TelepathicPsychicEnergy, Dusknoir, LilliesDetermination

```

Each trace carries two fields that exist to separate a **deck** problem from a
**decision** problem. `unmet=` names the sub-goals that were still open, and a
`!! PLAYABLE OUT unused` line means the card that would have fixed it was in
hand and was not played — that is a bug in `docs/03_decision_tree.md`, not in
the 60 cards.

# Where the rate came from

The policy is aligned to the decision documents as of 2026-08-30, after Kevin
answered all fourteen positions in `docs/03b_scenarios.md`. Going second the rate
moved **52.6% → 75.8%**, going first **53.4% → 64.1%**, `item_lock` going first
**49.0% → 60.7%**. That is a lump, and a lump is not useful, so each change was
neutralised on its own and both cells re-run. In order of what it is worth:

| Change | Going second | Going first |
|---|---|---|
| §6 priority 8 — never end a turn with the Supporter slot unspent | **15.2** | **3.4** |
| §7 step 6 — assemble the turn again over what the fallback drew | **5.0** | **6.7** |
| §6 priority 6 — Ciphermaniac's only when one card finishes the job | **4.4** | 0.0 |
| Meowth ex fetches Hilda rather than Salvatore | **1.8** | 0.0 |
| the want-list stops chasing a second Bronzor | **1.0** | **0.8** |
| Ultra Ball never discards this turn's chosen Supporter | **0.7** | **0.2** |
| §4.3 rung 5 — the Cursed Blast escape | **0.5** | **0.4** |
| §6 priority 2 — Salvatore ranked against Hilda on turn 2 | **0.3** | **0.2** |
| Ultra Ball discard order gains Night Stretcher and Ciphermaniac's | 0.0 | **0.5** |
| Meowth ex dropped from the bench-placing searches | 0.0 | 0.0 |
| the attachment is declined once sub-goal D is paid | −0.2 | 0.0 |
| Hilda takes both searches once she is played | −0.3 | 0.0 |
| sub-goal C counts as blocked while the Bronzor is still in hand | −0.3 | −0.4 |

**Two changes are almost all of it, and they are the same change twice.** Playing
a Supporter every turn is worth 15.2 going second; making the turn *use* what that
Supporter drew is worth another 5.0 going second and 6.7 going first. Without the
second pass the fallback is worth nothing at all on turn 2 — the window closes
before the eight cards can be played, which is exactly why it needed measuring
rather than assuming.

**The four at the bottom cost points and stay anyway.** They came from Kevin's
answers to S-02, S-06 and S-11 — they are rulings about how the deck should be
played, not optimisations — and the documents are the specification. Each is worth
a fraction of a point, which is roughly four replicates in a thousand.

# What the policy does not do yet

Stated plainly so your feedback lands on decisions rather than on known gaps.

- **It never plays Pokégear 3.0**, which is the only Item that digs for a
  Supporter and is exactly what the going-first branch lacks.
- **Retreat is only taken when free.** A paid retreat is never considered, even
  when the Energy spent would have been wasted anyway.
- **Boss's Orders is the one Supporter with no implementation**, deliberately:
  it moves the *opponent's* Pokémon, and no opponent is modelled.
- **The `item_lock` scenario is not shown here** — only `clear`. It is
  implemented and runs; it just is not in this document.

# What we glossed over

- **The opponent is a scenario, not a board.** No opposing decklist is modelled,
  which is also why the opening hand omits the bonus cards owed for an
  opponent's mulligans — biasing every rate slightly downward by an unknown
  amount.
- **Only one decklist appears here.** Part 6 is the registry that runs all six
  across both cells and both scenarios; this document runs one cell pair by hand.
- **The lead order and Ciphermaniac's timing are defaults, not rulings.** Both
  are written to be overturned by the tables above once the policy is good
  enough for those tables to mean something.

# References

- `docs/01_rules_standard.md` — the rules this engine implements
- `docs/03_decision_tree.md` — the tree this policy translates, §9 for the
  questions it still states as defaults rather than rulings
- `docs/adr/` — the seven decisions that were expensive to make
- `CONTEXT.md` — what this project's words mean
