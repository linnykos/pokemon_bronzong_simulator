context("Test replicate results, diagnosis, and traces")

## The trace exists to make a DECISION defect visible, so these tests are mostly
## about whether the diagnosis fields say the right thing. A trace that renders
## prettily but mis-diagnoses is worse than no trace, because it sends the reader
## to change the wrong thing -- which is exactly what two audits caught it doing.

.finished_pair <- function(active_id = "TEF-068",
                           bench_id_vec = character(0),
                           hand_id_vec = character(0),
                           energy_vec = character(0),
                           bool_evolved = FALSE,
                           bool_attacked = FALSE){
  pair <- .make_pair(active_id = active_id, bench_id_vec = bench_id_vec,
                     hand_id_vec = hand_id_vec, turn_number = 2L)
  if(bool_evolved && !is.null(pair$state$active)){
    pair$state$active$stack_vec <- c(pair$state$active$stack_vec, "TEF-069")
  }
  if(!is.null(pair$state$active)) pair$state$active$energy_vec <- energy_vec
  if(bool_attacked) pair <- attack_evolution_jammer(pair)

  pair
}

# ---------------------------------------------------------------------------
# Sub-goal diagnosis
# ---------------------------------------------------------------------------

test_that("unmet_subgoals reports the SET, not just the first", {
  ## The single most damaging defect the audits found. Because the order is
  ## A,B,C,D, reporting only the first meant C could be reported ONLY when A and
  ## B both held -- so a run with 106 of 322 misses having a Bronzor or Bronzong
  ## in play and not Active reported "C: 1". An agent read that as refuting the
  ## decision tree's central hypothesis ("C is the sub-goal that actually
  ## fails"). It was masked by the reporting rule, not refuted.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)

  ## Bronzor benched, never evolved: A is met, B, C and D are not.
  expect_equal(unmet_subgoals(pair$state), c("B", "C", "D"))
  expect_true("C" %in% unmet_subgoals(pair$state))
})

test_that("each sub-goal predicate is meaningful without the earlier ones", {
  ## Empty board: all four unmet.
  empty_pair <- .make_pair(active_id = NULL, turn_number = 2L)
  expect_equal(unmet_subgoals(empty_pair$state), c("A", "B", "C", "D"))

  ## Bronzor only: A met.
  bronzor_pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  expect_equal(unmet_subgoals(bronzor_pair$state), c("B", "C", "D"))

  ## Bronzong benched WITH energy: only C unmet -- this combination was
  ## unreportable under the old first-only rule.
  bench_pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                           turn_number = 2L)
  bench_pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  bench_pair$state$bench_list[[1]]$energy_vec <- "SVE-005"
  expect_equal(unmet_subgoals(bench_pair$state), "C")

  ## Active Bronzong, no energy: only D unmet.
  active_pair <- .finished_pair(bool_evolved = TRUE)
  expect_equal(unmet_subgoals(active_pair$state), "D")

  ## All four met.
  done_pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  expect_length(unmet_subgoals(done_pair$state), 0)
})

test_that("Enriching Energy does not satisfy sub-goal D", {
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SSP-191")

  expect_true("D" %in% unmet_subgoals(pair$state))
})

test_that("a Bronzong in play satisfies sub-goal A implicitly", {
  ## It can only have got there by sitting on a Bronzor.
  pair <- .finished_pair(bool_evolved = TRUE)

  expect_false("A" %in% unmet_subgoals(pair$state))
})

test_that("blocking_subgoal is a labelled rollup, not the cause", {
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)

  expect_equal(blocking_subgoal(pair$state), "B")
  expect_true(is.na(blocking_subgoal(
    .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")$state)))
})

# ---------------------------------------------------------------------------
# Unused outs
# ---------------------------------------------------------------------------

test_that("an out is only reported when it could actually have been played", {
  ## The audits' worst finding: a bare intersect(hand, outs) charged every
  ## UNPLAYABLE card in hand to the decision tree. In the item_lock cell 56% of
  ## the reported "decision defects" were the Item lock itself -- a rule, not a
  ## choice.
  locked <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                       hand_id_vec = "MEG-130", turn_number = 2L,
                       bool_going_first = TRUE, scenario = "item_lock")
  locked$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")

  expect_false(can_play_item(locked$state))
  expect_length(unused_outs(locked$state, unmet_subgoals(locked$state)), 0)

  ## The same board without the lock does report it.
  open <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)
  open$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  expect_equal(unused_outs(open$state, unmet_subgoals(open$state)), "MEG-130")
})

test_that("an Energy is not an unused out once the attachment is spent", {
  ## Every flagged Telepathic Psychic Energy in the shipped file sat behind an
  ## already-spent attachment.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088",
                     turn_number = 2L)
  pair$state$turn_flag_list$bool_energy_attached <- TRUE

  expect_length(unused_outs(pair$state, "D"), 0)

  pair$state$turn_flag_list$bool_energy_attached <- FALSE
  expect_equal(unused_outs(pair$state, "D"), "POR-088")
})

test_that("nothing is an unused out once the turn is over", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "MEG-130",
                     turn_number = 2L)
  pair$state$turn_flag_list$bool_turn_over <- TRUE

  expect_length(unused_outs(pair$state, c("B", "C", "D")), 0)
})

test_that("Hilda is not an out for sub-goal A", {
  ## Outright spec bug. Hilda fetches "an Evolution Pokemon and an Energy card";
  ## Bronzor is a Basic, so Hilda can never fix A. The deck runs 4.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "WHT-084",
                     turn_number = 2L)

  expect_true("A" %in% unmet_subgoals(pair$state))
  expect_false("WHT-084" %in% unused_outs(pair$state, "A"))
  ## It IS an out for B and D, which it can genuinely fetch.
  expect_true("WHT-084" %in% unused_outs(pair$state, "B"))
})

test_that("a Bronzor in hand is an out for sub-goal A", {
  ## The cheapest out there is -- bench it, free -- and it was missing from the
  ## list entirely, so the flag named a card that could not help while staying
  ## silent about the one that could.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-068",
                     turn_number = 2L)

  expect_true("A" %in% unmet_subgoals(pair$state))
  expect_equal(unused_outs(pair$state, "A"), "TEF-068")
})

test_that("a Bronzor in hand is not an out when the bench is full", {
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = rep("PRE-035", 5),
                     hand_id_vec = "TEF-068", turn_number = 2L)

  expect_length(unused_outs(pair$state, "A"), 0)
})

test_that("EVERY Bronzor printing is an out for A, resolved by name", {
  ## The out list held three Bronzor ids by hand, and Bronzor PBL 63 arrived
  ## with decklist7 and decklist8 as a fourth. It was therefore invisible to the
  ## diagnosis: a trace could say "no unused out" with a Bronzor sitting in
  ## hand, which reads as a DECK problem when it is a DECISION problem -- the
  ## confidently-wrong-diagnostic failure this repo has now hit four times, and
  ## the worst variant of it, because under-reporting raises nothing at all.
  ##
  ## Swept over every printing rather than adding PBL 63 to a literal, because
  ## a literal is what broke: the fix is to resolve Bronzor by NAME at run time,
  ## the way .bronzor_ids() already does in the policy, so a fifth printing
  ## cannot reintroduce this.
  card_df <- .test_card_df()
  bronzor_vec <- card_df$card_id[card_df$name == "Bronzor"]
  expect_true(length(bronzor_vec) >= 4)

  for(one_id in bronzor_vec){
    pair <- .make_pair(active_id = "PRE-035", hand_id_vec = one_id,
                       turn_number = 2L)

    expect_true("A" %in% unmet_subgoals(pair$state), info = one_id)
    expect_equal(unused_outs(pair$state, "A"), one_id, info = one_id)
  }
})

test_that("Latias ex is an out for sub-goal C", {
  ## Section 1 lists "Latias ex + retreat" for C: Skyliner zeroes a Basic
  ## Active's retreat. It was missing.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "SSP-076", turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")

  expect_true("SSP-076" %in% unused_outs(pair$state, "C"))
})

test_that("Ultra Ball is not an out without cards to discard", {
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "MEG-131",
                     turn_number = 2L)
  pair$state$hand_vec <- "MEG-131"

  expect_length(unused_outs(pair$state, "A"), 0)
})

test_that("Buddy-Buddy Poffin is not an out with no legal target in the deck", {
  ## It caps at 70 HP and every shipped decklist runs the 80 HP Bronzor, so
  ## listing it unconditionally as an A-out was wrong for every current list.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-144",
                     turn_number = 2L)
  ## Strip every <=70 HP Basic from the deck.
  hp_vec <- lookup_card(pair$state$card_df, pair$state$deck_vec)$hp
  stage_vec <- lookup_card(pair$state$card_df, pair$state$deck_vec)$stage
  keep_vec <- !(!is.na(hp_vec) & hp_vec <= 70 & stage_vec == "basic")
  pair$state$deck_vec <- pair$state$deck_vec[keep_vec]

  expect_length(unused_outs(pair$state, "A"), 0)
})

# ---------------------------------------------------------------------------
# Motifs
# ---------------------------------------------------------------------------

test_that("a misplayed card is caught by a motif, not by the residue check", {
  ## The residue check can only see a card LEFT in hand. The clearest decision
  ## defect in the audited file -- two Telepathic Energies attached to a
  ## Colorless body with the search declined both times -- left no residue and
  ## carried no flag at all.
  pair <- .make_pair(active_id = "MEG-104", hand_id_vec = "POR-088",
                     turn_number = 1L)
  pair <- attach_energy(pair, "POR-088", target_is_active = TRUE)

  unmet_vec <- unmet_subgoals(pair$state)
  motif_vec <- detect_motifs(pair$state, unmet_vec)

  expect_true("telepathic_on_colorless" %in% motif_vec)
  expect_length(unused_outs(pair$state, unmet_vec), 0)
})

test_that("a declined search is a distinct motif from a failed one", {
  ## "whiff" meant both "the search failed" (deck) and "the policy named no
  ## target" (decision). Merging them defeats the file's purpose.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-081",
                     turn_number = 2L)
  pair <- play_poke_pad(pair, target_id = NULL)

  expect_true(any(grepl("DECLINED", pair$state$event_log)))
  expect_true("search_declined" %in%
                detect_motifs(pair$state, unmet_subgoals(pair$state)))
})

test_that("a genuine whiff names what was not found", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-081",
                     turn_number = 2L)
  pair$state$deck_vec <- pair$state$deck_vec[pair$state$deck_vec != "TEF-069"]
  pair <- play_poke_pad(pair, target_id = "TEF-069")

  log_str <- paste0(pair$state$event_log, collapse = " ")
  expect_true(grepl("whiff", log_str))
  expect_true(grepl("not in deck", log_str))
  expect_false(grepl("DECLINED", log_str))
})

test_that("never_promoted fires when the piece was in play and left benched", {
  ## The motif that the old first-unmet-only reporting hid completely.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)
  unmet_vec <- unmet_subgoals(pair$state)

  expect_true("never_promoted" %in% detect_motifs(pair$state, unmet_vec))
})

test_that("attack_never_declared fires when the combo was assembled unused", {
  ## Precisely the ADR 0004 case: available is not the same as attacked.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")

  expect_length(unmet_subgoals(pair$state), 0)
  expect_true("attack_never_declared" %in%
                detect_motifs(pair$state, unmet_subgoals(pair$state)))
})

# ---------------------------------------------------------------------------
# Results and aggregation
# ---------------------------------------------------------------------------

test_that("a hit is recorded from the attack, not from availability", {
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  expect_true(can_use_evolution_jammer(pair$state))

  not_attacked <- summarise_replicate(pair, "dl_test", 1L)
  expect_false(not_attacked$bool_hit)
  expect_true(is.na(not_attacked$jammer_turn))

  attacked <- summarise_replicate(attack_evolution_jammer(pair), "dl_test", 1L)
  expect_true(attacked$bool_hit)
  expect_equal(attacked$jammer_turn, 2L)
})

test_that("a turn-3 attack is a miss but is still diagnosed", {
  ## The tally used to skip late attacks, so per-sub-goal counts silently failed
  ## to add up to the miss count.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 3L)
  pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$active$energy_vec <- "SVE-005"
  result <- summarise_replicate(attack_evolution_jammer(pair), "dl_test", 1L)

  expect_false(result$bool_hit)
  expect_equal(result$jammer_turn, 3L)
  expect_length(result$unmet_vec, 0)
})

test_that("a turn-1 attack is a hit, like a turn-2 one", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)
  pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$active$energy_vec <- "POR-088"
  result <- summarise_replicate(attack_evolution_jammer(pair), "dl_test", 1L)

  expect_true(result$bool_hit)
  expect_equal(result$jammer_turn, 1L)
})

test_that("mulligans are recorded but never make a replicate a miss", {
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  pair$state$num_mulligans <- 2L
  result <- summarise_replicate(attack_evolution_jammer(pair), "dl_test", 1L)

  expect_true(result$bool_hit)
  expect_equal(result$num_mulligans, 2L)
  expect_true(result$bool_mulliganed)
})

test_that("mulligan metrics are orthogonal to the hit rate", {
  result_list <- lapply(1:10, function(i){
    pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
    pair$state$num_mulligans <- if(i %% 2 == 0) 1L else 0L
    summarise_replicate(attack_evolution_jammer(pair), "dl_test", i)
  })
  summary_list <- summarise_run(result_list)

  expect_equal(summary_list$hit_rate, 1)
  expect_equal(summary_list$mulligan_rate, 0.5)
  expect_equal(summary_list$mean_mulligans, 0.5)
})

test_that("the unmet tally counts a miss in every row it belongs to", {
  result_list <- list(
    summarise_replicate(.make_pair(active_id = "PRE-035", turn_number = 2L),
                        "dl_test", 1L),
    summarise_replicate(.make_pair(active_id = "TEF-068", turn_number = 2L),
                        "dl_test", 2L))
  summary_list <- summarise_run(result_list)

  ## Replicate 1 is missing everything; replicate 2 has a Bronzor.
  expect_equal(as.integer(summary_list$unmet_tally_vec[["A"]]), 1L)
  expect_equal(as.integer(summary_list$unmet_tally_vec[["C"]]), 2L)
  expect_equal(as.integer(summary_list$unmet_tally_vec[["D"]]), 2L)
  expect_equal(summary_list$num_miss, 2L)
})

test_that("never_promoted excludes a Bronzor that was Active all along", {
  ## Found by review. The condition was "A met, C unmet", which is equally true
  ## of a Bronzor that led at setup and was simply never evolved -- a sub-goal B
  ## failure with nothing to promote and no positioning mistake in it. It was
  ## being counted under a label reading "never made Active", in a tally headed
  ## "the counts worth acting on". Demo seed 13 was one such replicate.
  active_pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  benched_pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                             turn_number = 2L)

  expect_false("never_promoted" %in%
                 detect_motifs(active_pair$state,
                               unmet_subgoals(active_pair$state)))
  ## The genuine case still fires: the Bronzor is on the Bench.
  expect_true("never_promoted" %in%
                detect_motifs(benched_pair$state,
                              unmet_subgoals(benched_pair$state)))
})

test_that("supporter_slot_unused is per turn, not per game", {
  ## Found by review. The check grepped the whole event log for a hard-coded
  ## list of Supporter names, so a replicate that played Hilda on turn 1 and
  ## wasted turn 2's slot was never flagged -- the more interesting of the two
  ## cases. It also could not see a Supporter the effects log under a label
  ## rather than its name ("Codebreaking stacked"), nor one not on the list at
  ## all (Boss's Orders, 2 copies in decklist2).
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "WHT-084",
                     turn_number = 1L)
  pair <- play_hilda(pair, evolution_id = NULL, energy_id = NULL)
  pair$state <- begin_turn(pair$state)

  expect_equal(pair$state$turn_number, 2L)
  expect_true("supporter_slot_unused" %in%
                detect_motifs(pair$state, unmet_subgoals(pair$state)))

  ## Turn 1 going first cannot spend a Supporter at all, so an unspent slot
  ## there is a rule, not a choice -- the same distinction that stopped the Item
  ## lock being charged to the decision tree.
  first_pair <- .make_pair(active_id = "TEF-068", turn_number = 1L,
                           bool_going_first = TRUE)
  expect_false("supporter_slot_unused" %in%
                 detect_motifs(first_pair$state,
                               unmet_subgoals(first_pair$state)))
})

test_that("Buddy-Buddy Poffin is an out for A only with a <=70 HP Bronzor", {
  ## Found by review. The playability test accepted any <=70 HP Basic in the
  ## deck -- Duskull (60), Buneary (70), Budew (30) all pass -- so against a
  ## list running only the 80 HP TEF-068 the flag accused the decision tree of
  ## not playing a card that cannot fix A at all.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-144",
                     turn_number = 2L)

  expect_true("A" %in% unmet_subgoals(pair$state))
  expect_false("TEF-144" %in% unused_outs(pair$state, "A"))

  ## With a 70 HP Bronzor in the deck it is a real out again.
  pair$state$deck_vec <- c("PRE-066", pair$state$deck_vec)
  expect_true("TEF-144" %in% unused_outs(pair$state, "A"))
})

test_that("Telepathic is an out for A only when a [P] body can receive it", {
  ## Found by review. Its route to sub-goal A is the search, which fires only on
  ## a [P] recipient; on an all-Colorless board the attach is legal and the
  ## search is dead. Flagging it charges the tree for the very play the
  ## telepathic_on_colorless motif warns against.
  colorless_pair <- .make_pair(active_id = "MEG-104", hand_id_vec = "POR-088",
                               turn_number = 2L)
  expect_false("POR-088" %in% unused_outs(colorless_pair$state, "A"))

  ## But it stays an unconditional out for D, where it is wanted as a [P]
  ## SOURCE: on a Metal Bronzor it searches nothing and still carries a [P]
  ## through evolution.
  metal_pair <- .make_pair(active_id = "PRE-066", hand_id_vec = "POR-088",
                           turn_number = 2L)
  expect_true("POR-088" %in% unused_outs(metal_pair$state, "D"))
})

test_that("Rare Candy is an out for C only with the whole line in place", {
  ## The Cursed Blast escape (docs/03_decision_tree.md section 8) is the only
  ## way Rare Candy reaches sub-goal C, and every piece has to be held at once.
  ##
  ## The first version of this check got two things backwards and a review
  ## caught both, after they had already produced false accusations in the
  ## shipped demo file. It asked for the Dusknoir in the DECK -- Rare Candy does
  ## not search, so that flagged the escape exactly when it was impossible --
  ## and it accepted a benched bare Bronzor, though sub-goal C is
  ## `bronzong_active` and promoting a Bronzor does not meet it.
  full <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = c("MEG-125", "PRE-037", "TEF-069"),
                     turn_number = 2L)

  expect_true("C" %in% unmet_subgoals(full$state))
  expect_true("MEG-125" %in% unused_outs(full$state, "C"))

  ## A benched Bronzong needs no Bronzong in hand: C is met by promoting it.
  evolved <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                        hand_id_vec = c("MEG-125", "PRE-037"),
                        turn_number = 2L)
  evolved$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  expect_true("MEG-125" %in% unused_outs(evolved$state, "C"))

  ## Each missing precondition, one at a time.
  no_dusknoir <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                            hand_id_vec = c("MEG-125", "TEF-069"),
                            turn_number = 2L)
  expect_true("PRE-037" %in% no_dusknoir$state$deck_vec)
  expect_false("MEG-125" %in% unused_outs(no_dusknoir$state, "C"))

  ## A bare benched Bronzor with no Bronzong to put on it: promoting it leaves C
  ## exactly as unmet as before.
  bare_bronzor <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                             hand_id_vec = c("MEG-125", "PRE-037"),
                             turn_number = 2L)
  expect_false("MEG-125" %in% unused_outs(bare_bronzor$state, "C"))

  no_bronzor <- .make_pair(active_id = "PRE-035", bench_id_vec = "MEG-104",
                           hand_id_vec = c("MEG-125", "PRE-037", "TEF-069"),
                           turn_number = 2L)
  expect_false("MEG-125" %in% unused_outs(no_bronzor$state, "C"))

  wrong_active <- .make_pair(active_id = "MEG-104", bench_id_vec = "TEF-068",
                             hand_id_vec = c("MEG-125", "PRE-037", "TEF-069"),
                             turn_number = 2L)
  expect_false("MEG-125" %in% unused_outs(wrong_active$state, "C"))

  ## Turn 1: Rare Candy's own text forbids it, so the line does not exist yet.
  too_early <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                          hand_id_vec = c("MEG-125", "PRE-037", "TEF-069"),
                          turn_number = 1L)
  expect_false("MEG-125" %in% unused_outs(too_early$state, "C"))
})

test_that("the run is grouped by the Basic that led at setup", {
  ## Kevin deferred the section 3 lead order to "the simulation logs"
  ## (2026-08-29). ADR 0006 forbids reading a rate off the traces, which are
  ## stratified toward misses, so this aggregate over EVERY replicate is the
  ## only place the answer can legitimately come from -- and it is worth a test
  ## because a per-lead rate that silently pools leads answers the question
  ## wrongly rather than not at all.
  hit_pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  hit_pair$state$lead_card_id <- "TEF-068"
  hit_pair <- attack_evolution_jammer(hit_pair)
  miss_pair <- .finished_pair(active_id = "MEG-104")
  miss_pair$state$lead_card_id <- "MEG-104"

  result_list <- c(lapply(1:3, function(i){
    summarise_replicate(hit_pair, "dl_test", i)
  }), lapply(4:5, function(i){
    summarise_replicate(miss_pair, "dl_test", i)
  }))
  lead_hit_df <- summarise_run(result_list)$lead_hit_df

  expect_equal(sort(lead_hit_df$lead_card_id), c("MEG-104", "TEF-068"))
  bool_bronzor_vec <- lead_hit_df$lead_card_id == "TEF-068"
  expect_equal(lead_hit_df$num_replicates[bool_bronzor_vec], 3L)
  expect_equal(lead_hit_df$hit_rate[bool_bronzor_vec], 1)
  expect_equal(lead_hit_df$hit_rate[!bool_bronzor_vec], 0)

  ## And it reaches the file as a rate the reader is told they MAY use, beside
  ## the sample they may not.
  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(), tmp_file, summarise_run(result_list))
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("HIT RATE BY THE BASIC THAT LED", line_vec)))
  expect_true(any(grepl("Bronzor\\(TEF\\)", line_vec)))
})

test_that("a state that never had a setup lead is grouped as unknown", {
  ## lookup_card() rejects "unknown", so the header block has to route around
  ## it; a fixture-built state is exactly this case.
  result <- summarise_replicate(.make_pair(turn_number = 2L), "dl_test", 1L)
  summary_list <- summarise_run(list(result))

  expect_true(is.na(result$lead_card_id))
  expect_equal(summary_list$lead_hit_df$lead_card_id, "unknown")

  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(), tmp_file, summary_list)
  expect_true(any(grepl("unknown", readLines(tmp_file))))
})

test_that("summarise_run refuses to pool across cells", {
  ## ADR 0002 forbids it, and the function used to label the run from the first
  ## element and average the rest with no warning.
  first_pair <- .finished_pair(bool_evolved = TRUE)
  first_pair$state$bool_going_first <- TRUE
  second_pair <- .finished_pair(bool_evolved = TRUE)

  mixed_list <- list(summarise_replicate(first_pair, "dl_test", 1L),
                     summarise_replicate(second_pair, "dl_test", 2L))

  expect_error(summarise_run(mixed_list), regexp = "different cells")
})

test_that("the turn distribution required by ADR 0004 is computed", {
  ## Salvatore's whole value is the turn-1 rate, and it was computed nowhere.
  t1_pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)
  t1_pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  t1_pair$state$active$energy_vec <- "SVE-005"
  t2_pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")

  result_list <- c(
    lapply(1:2, function(i){
      summarise_replicate(attack_evolution_jammer(t1_pair), "dl_test", i)
    }),
    lapply(3:4, function(i){
      summarise_replicate(attack_evolution_jammer(t2_pair), "dl_test", i)
    }),
    list(summarise_replicate(.make_pair(active_id = "PRE-035",
                                        turn_number = 2L), "dl_test", 5L)))
  summary_list <- summarise_run(result_list)

  expect_equal(as.integer(summary_list$turn_tally_vec[["t1"]]), 2L)
  expect_equal(as.integer(summary_list$turn_tally_vec[["t2"]]), 2L)
  expect_equal(as.integer(summary_list$turn_tally_vec[["never"]]), 1L)
  expect_equal(summary_list$turn1_rate, 0.4)
})

# ---------------------------------------------------------------------------
# Trace formatting and file writing
# ---------------------------------------------------------------------------

test_that("formatting a fully-assembled unattacked combo does not crash", {
  ## It threw "subscript out of bounds" whenever all four sub-goals were met and
  ## the attack was never declared -- the exact case ADR 0004 exists to expose.
  ## A driver keeping traces would have died on the first such replicate,
  ## killing a whole 10,000-replicate run.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")

  expect_silent(summarise_replicate(pair, "dl_test", 1L,
                                    bool_keep_trace = TRUE))
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  expect_true(grepl("unmet=none", result$trace_vec[1]))
  expect_true(grepl("never declared", result$trace_vec[1]))
})

test_that("the trace is kept only when asked for", {
  pair <- .finished_pair(bool_evolved = TRUE)

  expect_true(is.null(summarise_replicate(pair, "dl_test", 1L)$trace_vec))
  expect_false(is.null(summarise_replicate(pair, "dl_test", 1L,
                                           bool_keep_trace = TRUE)$trace_vec))
})

test_that("the trace header names the unmet SET and the seed", {
  pair <- .finished_pair(bool_evolved = TRUE)
  pair$state$num_mulligans <- 1L
  result <- summarise_replicate(pair, "dl_test", 7L, bool_keep_trace = TRUE)

  expect_true(grepl("^#7 ", result$trace_vec[1]))
  expect_true(grepl("mull=1", result$trace_vec[1]))
  expect_true(grepl("unmet=D", result$trace_vec[1]))
})

test_that("mull= is omitted when there were no mulligans", {
  ## It appeared on 86.5% of headers carrying no information.
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)

  expect_false(grepl("mull=", result$trace_vec[1]))
})

test_that("a playable unused out is flagged prominently", {
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  result <- summarise_replicate(pair, "dl_test", 4L, bool_keep_trace = TRUE)

  expect_true(any(grepl("PLAYABLE OUT unused", result$trace_vec)))
  expect_true(any(grepl("Switch", result$trace_vec)))
})

test_that("the end block marks Pokemon type and names attached energy", {
  ## "+PP" was ambiguous between two [P] cards and one card giving [P][P], and
  ## hid WHICH cards were spent. Type marks decide whether Telepathic's search
  ## can fire at all.
  ##
  ## Asserted over the whole block rather than the last line: the snapshot grew
  ## from one line to nine (Kevin, 2026-08-29, "be thorough at the end of turn
  ## 2"), and indexing the last line pinned it to the prize row.
  pair <- .finished_pair(active_id = "MEG-104", energy_vec = "POR-088")
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  block_str <- paste0(result$trace_vec, collapse = "\n")

  expect_true(grepl("MegaKangaskhanex[C]", block_str, fixed = TRUE))
  expect_true(grepl("TelepathicPsychicEnergy", block_str, fixed = TRUE))
  expect_true(grepl("deck=", block_str))
})

test_that("the end-of-window snapshot reports every zone", {
  ## Kevin, 2026-08-29: stop at turn 2, but be thorough THERE, because the board
  ## reached by the end of turn 2 is a question he wants to ask later. A miss
  ## whose hand, discard, Stadium and prizes are unrecorded cannot answer it, so
  ## every zone is asserted here rather than trusting the format by eye.
  pair <- .finished_pair(active_id = "TEF-068", bench_id_vec = "PRE-035",
                         hand_id_vec = "MEG-130", energy_vec = "SVE-005")
  pair$state$discard_vec <- c(pair$state$discard_vec, "MEG-131")
  pair$state$stadium <- "TWM-149"
  pair$state$prize_vec <- c("TEF-069", "SVE-005")
  pair$state$lead_card_id <- "TEF-068"
  pair$state$turn_flag_list$bool_energy_attached <- TRUE
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  block_str <- paste0(result$trace_vec, collapse = "\n")

  ## Per-line, not over the pasted block: R's default regex engine lets `.`
  ## match a newline, so a block-wide pattern would happily match a card named
  ## on some other zone's line.
  hand_str <- grep("^    hand ", result$trace_vec, value = TRUE)
  discard_str <- grep("^    discard ", result$trace_vec, value = TRUE)

  expect_true(grepl("end of turn 2", block_str, fixed = TRUE))
  expect_true(grepl("Switch", hand_str, fixed = TRUE))
  expect_true(grepl("UltraBall", discard_str, fixed = TRUE))
  expect_true(grepl("stadium=FestivalGrounds", block_str))
  expect_true(grepl("prizes=2", block_str, fixed = TRUE))
  expect_true(grepl("energy=spent", block_str, fixed = TRUE))
  expect_true(grepl("supporter=unplayed", block_str, fixed = TRUE))
  expect_true(grepl("setup lead=Bronzor\\(TEF\\)", block_str))
  expect_true(grepl("played=T0", block_str, fixed = TRUE))

  ## The prizes are ground truth. Recording them is what separates "the deck
  ## never offered it" from "the decision was wrong"; the label is what stops
  ## the field being wired into the policy, which ADR 0003 forbids.
  expect_true(grepl("GROUND TRUTH, never visible to the policy", block_str))
  expect_true(grepl("Bronzong", block_str, fixed = TRUE))
})

test_that("the snapshot names the whole evolution stack, not just the top", {
  ## Which Bronzor is under a Bronzong decides whether Poffin (<=70 HP) or
  ## Telepathic Psychic Energy ([P] only) could have found it, so a board state
  ## naming only "Bronzong" cannot be reasoned about after the run.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  active_str <- grep("^    active ", result$trace_vec, value = TRUE)

  expect_true(grepl("Bronzor(TEF)>Bronzong", active_str, fixed = TRUE))
})

test_that("the snapshot renders an empty board without erroring", {
  ## Every zone is empty in a decked-out or never-placed replicate, and the
  ## block is built by paste0() over vectors that are then length 0 -- which
  ## silently yields character(0) and drops the line rather than failing loudly.
  pair <- .make_pair(active_id = NULL, turn_number = 2L)
  pair$state$hand_vec <- character(0)
  pair$state$discard_vec <- character(0)
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  block_str <- paste0(result$trace_vec, collapse = "\n")

  expect_true(grepl("active   -", block_str, fixed = TRUE))
  expect_true(grepl("bench    -", block_str, fixed = TRUE))
  expect_true(grepl("hand     -", block_str, fixed = TRUE))
  expect_true(grepl("stadium=-", block_str, fixed = TRUE))
  expect_true(grepl("setup lead=-", block_str, fixed = TRUE))
  expect_true(all(!is.na(result$trace_vec)))
})

test_that("the snapshot reports the Item lock only when it is actually on", {
  ## items_are_locked(), not can_play_item(): the latter is FALSE once the turn
  ## is over, which is true of EVERY trace, so it reported a lock in the `clear`
  ## scenario too -- the same class of bug as charging the lock to the decision
  ## tree in unused_outs().
  locked <- .make_pair(active_id = "TEF-068", turn_number = 2L,
                       bool_going_first = TRUE, scenario = "item_lock")
  locked$state$turn_flag_list$bool_turn_over <- TRUE
  open <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  open$state$turn_flag_list$bool_turn_over <- TRUE

  locked_str <- paste0(summarise_replicate(locked, "dl_test", 1L,
                                           bool_keep_trace = TRUE)$trace_vec,
                       collapse = "\n")
  open_str <- paste0(summarise_replicate(open, "dl_test", 1L,
                                         bool_keep_trace = TRUE)$trace_vec,
                     collapse = "\n")

  expect_true(grepl("items=locked", locked_str, fixed = TRUE))
  expect_true(grepl("items=open", open_str, fixed = TRUE))
  expect_false(can_play_item(open$state))
})

test_that("a promotion names the mechanism that paid for it", {
  ## Sub-goal C is entirely about WHICH resource you spend, and the log said
  ## only "promote X".
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)
  pair <- play_switch(pair, bench_idx = 1L)

  expect_true(any(grepl("promote .* via Switch", pair$state$event_log)))
})

test_that("traces show card names, not ids, and hide level-2 primitives", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-069",
                     turn_number = 2L)
  pair <- evolve_pokemon(pair, "TEF-069", target_is_active = TRUE)
  result <- summarise_replicate(pair, "dl_test", 5L, bool_keep_trace = TRUE)
  trace_str <- paste0(result$trace_vec, collapse = " ")

  expect_true(grepl("Bronzong", trace_str))
  expect_false(grepl("TEF-069", trace_str))
  expect_false(grepl("move 1 hand->discard", trace_str))
})

test_that("the trace stays compact enough to read many of at once", {
  ## The cap was 12 lines and is now 18. That is a deliberate re-pricing, not a
  ## drift: Kevin asked (2026-08-29) for a thorough record of the board at the
  ## end of turn 2, which turned the one-line `end` summary into an eight-line
  ## block naming every zone. The cap still exists, and still has to fail, if
  ## the per-turn lines start sprawling -- that is the growth ADR 0006 was
  ## worried about, since it scales with how much the policy does, whereas the
  ## snapshot is a fixed cost per trace.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:15){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    pair$state <- begin_turn(pair$state)
    pair$state <- log_hand_snapshot(pair$state)
    pair$state <- begin_turn(pair$state)
    pair$state <- log_hand_snapshot(pair$state)
    result <- summarise_replicate(pair, "dl_test", one_seed,
                                  bool_keep_trace = TRUE)

    expect_true(length(result$trace_vec) <= 18,
                info = paste0("seed ", one_seed, ": ",
                              length(result$trace_vec), " lines"))
  }
})

test_that("the sampler stratifies toward misses and respects both quotas", {
  sampler <- new_trace_sampler(max_miss = 3L, max_hit = 1L)

  keep_vec <- logical(0)
  for(bool_hit in c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)){
    take_list <- sampler_take(sampler, bool_hit)
    sampler <- take_list$sampler
    keep_vec <- c(keep_vec, take_list$bool_keep)
  }

  expect_equal(keep_vec, c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE))
  expect_true(sampler_is_full(sampler))
})

test_that("a zero quota keeps nothing and is immediately full", {
  sampler <- new_trace_sampler(max_miss = 0L, max_hit = 0L)

  expect_false(sampler_take(sampler, TRUE)$bool_keep)
  expect_false(sampler_take(sampler, FALSE)$bool_keep)
  expect_true(sampler_is_full(sampler))
})

test_that("write_trace_file refuses a summary that is not from the whole run", {
  ## ADR 0006 calls this the trap, and nothing used to enforce it: a
  ## bronzong_result is a list, so passing the SAMPLE as its own summary was
  ## accepted and printed a rate derived from the traces.
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  tmp_file <- tempfile(fileext = ".txt")

  expect_error(write_trace_file(list(result), tmp_file, result),
               regexp = "summarise_run")
  expect_error(write_trace_file(list(result), tmp_file, list(a = 1)),
               regexp = "summarise_run")
})

test_that("write_trace_file refuses a summary covering fewer replicates", {
  pair <- .finished_pair(bool_evolved = TRUE)
  result_list <- lapply(1:3, function(i){
    summarise_replicate(pair, "dl_test", i, bool_keep_trace = TRUE)
  })
  summary_list <- summarise_run(result_list[1])
  tmp_file <- tempfile(fileext = ".txt")

  expect_error(write_trace_file(result_list, tmp_file, summary_list),
               regexp = "whole run")
})

test_that("the file warns against computing a rate and reports the run's rate", {
  hit_pair <- attack_evolution_jammer(
    .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005"))
  miss_pair <- .finished_pair(bool_evolved = TRUE)

  result_list <- c(lapply(1:3, function(i){
    summarise_replicate(hit_pair, "dl_test", i)
  }), lapply(4:10, function(i){
    summarise_replicate(miss_pair, "dl_test", i)
  }))
  summary_list <- summarise_run(result_list)

  ## Keep one HIT trace, so the sample is 100% hits and the run is 30%.
  kept <- summarise_replicate(hit_pair, "dl_test", 1L, bool_keep_trace = TRUE)
  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(kept), tmp_file, summary_list)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("Never", line_vec)))
  expect_true(any(grepl("NOT a representative sample", line_vec)))
  expect_true(any(grepl("30.00%", line_vec)))
  expect_true(any(grepl("replicates : 10", line_vec)))
  expect_true(any(grepl("orthogonal", line_vec)))
})

test_that("the file spells out the decklist when it is supplied", {
  ## Without it the header gave only a content hash, and an agent asked to
  ## recommend changes proposed several cards that are not in the deck.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, decklist$decklist_id, 1L,
                                bool_keep_trace = TRUE)
  summary_list <- summarise_run(list(result))

  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(result), tmp_file, summary_list, decklist = decklist)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("THE 60 CARDS IN THIS DECK", line_vec)))
  expect_true(any(grepl("Bronzong", line_vec)))

  ## And warns when it is not supplied, rather than silently omitting it.
  write_trace_file(list(result), tmp_file, summary_list)
  expect_true(any(grepl("may name absent cards", readLines(tmp_file))))
})

test_that("the file carries motif counts over every miss", {
  ## The highest-value addition: an agent reading traces reported that it
  ## stopped reading and started counting, and the counting produced its main
  ## finding. Ship the counts.
  pair <- .make_pair(active_id = "MEG-104", hand_id_vec = "POR-088",
                     turn_number = 1L)
  pair <- attach_energy(pair, "POR-088", target_is_active = TRUE)
  result_list <- lapply(1:4, function(i){
    summarise_replicate(pair, "dl_test", i)
  })
  summary_list <- summarise_run(result_list)

  expect_equal(as.integer(summary_list$motif_tally_vec[["telepathic_on_colorless"]]),
               4L)

  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(), tmp_file, summary_list)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("PLAY MOTIFS", line_vec)))
  expect_true(any(grepl("Colorless body", line_vec)))
  expect_true(any(grepl("UNMET SUB-GOALS", line_vec)))
})

test_that("the trace index and the seed are both shown in the file", {
  ## "#N" alone was the seed but read as an index, so the file appeared to skip
  ## numbers and look buggy.
  pair <- .finished_pair(bool_evolved = TRUE)
  result_list <- lapply(c(3L, 17L), function(i){
    summarise_replicate(pair, "dl_test", i, bool_keep_trace = TRUE)
  })
  summary_list <- summarise_run(result_list)

  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(result_list, tmp_file, summary_list)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("#1/2 seed=3", line_vec, fixed = TRUE)))
  expect_true(any(grepl("#2/2 seed=17", line_vec, fixed = TRUE)))
})

test_that("log_hand_snapshot records the hand and is level 1", {
  pair <- .make_pair(hand_id_vec = c("MEG-130", "TEF-069"), turn_number = 1L)
  state <- log_hand_snapshot(pair$state)

  expect_true(grepl("hand\\[", state$event_log[length(state$event_log)]))
  expect_equal(state$event_level_vec[length(state$event_level_vec)], 1L)
})

test_that("turn lines return a character vector even with nothing to show", {
  ## sapply over an empty vector returns list(), which promoted the whole trace
  ## to a list and broke writeLines().
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)
  pair$state$event_log <- character(0)
  pair$state$event_level_vec <- integer(0)
  pair$state$event_turn_vec <- integer(0)
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)

  expect_true(is.character(result$trace_vec))
  tmp_file <- tempfile(fileext = ".txt")
  expect_silent(writeLines(result$trace_vec, tmp_file))
})
