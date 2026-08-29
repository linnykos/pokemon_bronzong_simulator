context("Test replicate results, diagnosis, and traces")

## The trace exists to make a DECISION defect visible, so these tests are mostly
## about whether the diagnosis fields say the right thing. A trace that renders
## prettily but mis-diagnoses is worse than no trace, because it sends the
## reader to change the wrong thing.

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
  pair$state$active$energy_vec <- energy_vec
  if(bool_attacked) pair <- attack_evolution_jammer(pair)

  pair
}

test_that("blocking_subgoal reports the first unmet sub-goal", {
  ## Order matters: reporting all of them buries the one that actually stopped
  ## the line, which is the only one worth acting on.

  ## A: nothing Bronzor-shaped in play at all.
  pair <- .make_pair(active_id = "PRE-035", turn_number = 2L)
  expect_equal(blocking_subgoal(pair$state), "A")

  ## B: a Bronzor is down but never evolved.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  expect_equal(blocking_subgoal(pair$state), "B")

  ## C: Bronzong exists but is stuck on the Bench.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  expect_equal(blocking_subgoal(pair$state), "C")

  ## D: Active Bronzong with no [P] attached.
  pair <- .finished_pair(bool_evolved = TRUE)
  expect_equal(blocking_subgoal(pair$state), "D")

  ## All four met.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  expect_true(is.na(blocking_subgoal(pair$state)))
})

test_that("Enriching Energy does not satisfy sub-goal D", {
  ## The same trap as everywhere else: it is an Energy card that cannot pay.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SSP-191")

  expect_equal(blocking_subgoal(pair$state), "D")
})

test_that("a Bronzong in play satisfies sub-goal A implicitly", {
  ## A Bronzong can only have got there by sitting on a Bronzor, so reporting
  ## "no Bronzor in play" once it has evolved would be misleading.
  pair <- .finished_pair(bool_evolved = TRUE)

  expect_false(blocking_subgoal(pair$state) == "A")
})

test_that("an empty board reports sub-goal A rather than erroring", {
  pair <- .make_pair(active_id = NULL, turn_number = 2L)

  expect_equal(blocking_subgoal(pair$state), "A")
})

test_that("unused_outs finds a card that was in hand and not played", {
  ## THE diagnostic that separates a deck problem from a decision problem. A
  ## miss blocked on C with a Switch in hand means the decision tree is wrong,
  ## not the 60 cards.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = c("MEG-130", "SSP-187"), turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")

  expect_equal(blocking_subgoal(pair$state), "C")
  expect_equal(sort(unused_outs(pair$state, "C")), sort(c("MEG-130", "SSP-187")))
})

test_that("unused_outs ignores outs that are not in hand", {
  ## An out in the DECK is an undrawn out, not an unused one -- conflating them
  ## would blame the decision for a draw problem.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")

  expect_length(unused_outs(pair$state, "C"), 0)
})

test_that("unused_outs is empty when nothing was blocked", {
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")

  expect_length(unused_outs(pair$state, NA_character_), 0)
})

test_that("unused_outs is sub-goal specific", {
  ## A Switch is an out for C and irrelevant to D; the reverse for an Energy.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("MEG-130", "SVE-005"), turn_number = 2L)

  expect_equal(unused_outs(pair$state, "C"), "MEG-130")
  expect_equal(unused_outs(pair$state, "D"), "SVE-005")
})

test_that("a hit is recorded from the attack, not from availability", {
  ## ADR 0004. can_use_evolution_jammer() reports that the attack is POSSIBLE.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  expect_true(can_use_evolution_jammer(pair$state))

  not_attacked <- summarise_replicate(pair, decklist_id = "dl_test",
                                      seed_number = 1L)
  expect_false(not_attacked$bool_hit)
  expect_true(is.na(not_attacked$jammer_turn))

  attacked <- summarise_replicate(attack_evolution_jammer(pair),
                                  decklist_id = "dl_test", seed_number = 1L)
  expect_true(attacked$bool_hit)
  expect_equal(attacked$jammer_turn, 2L)
})

test_that("an attack after turn 2 is not a hit", {
  ## The bar is the player's OWN turn 2 (ADR 0004), so a turn-3 attack scores as
  ## a miss even though the attack happened.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 3L)
  pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$active$energy_vec <- "SVE-005"
  pair <- attack_evolution_jammer(pair)

  result <- summarise_replicate(pair, decklist_id = "dl_test", seed_number = 1L)

  expect_false(result$bool_hit)
  expect_equal(result$jammer_turn, 3L)
})

test_that("a turn-1 attack is a hit, like a turn-2 one", {
  ## The fixed bar deliberately counts both the same (ADR 0004); the difference
  ## shows up only in jammer_turn.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L,
                     bool_going_first = FALSE)
  pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$active$energy_vec <- "POR-088"
  pair <- attack_evolution_jammer(pair)

  result <- summarise_replicate(pair, decklist_id = "dl_test", seed_number = 1L)

  expect_true(result$bool_hit)
  expect_equal(result$jammer_turn, 1L)
})

test_that("mulligans are recorded but never make a replicate a miss", {
  ## ADR 0005. A game that mulliganed twice and then hit is a hit, full stop.
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  pair$state$num_mulligans <- 2L
  pair <- attack_evolution_jammer(pair)

  result <- summarise_replicate(pair, decklist_id = "dl_test", seed_number = 1L)

  expect_true(result$bool_hit)
  expect_equal(result$num_mulligans, 2L)
  expect_true(result$bool_mulliganed)
})

test_that("mulligan metrics are orthogonal to the hit rate", {
  ## Constructed so the two move independently: every replicate hits, and half
  ## mulliganed. If the two were entangled the hit rate would not be 1.
  result_list <- lapply(1:10, function(i){
    pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
    pair$state$num_mulligans <- if(i %% 2 == 0) 1L else 0L
    summarise_replicate(attack_evolution_jammer(pair),
                        decklist_id = "dl_test", seed_number = i)
  })

  summary_list <- summarise_run(result_list)

  expect_equal(summary_list$hit_rate, 1)
  expect_equal(summary_list$mulligan_rate, 0.5)
  expect_equal(summary_list$mean_mulligans, 0.5)
  expect_equal(summary_list$max_mulligans, 1L)
})

test_that("summarise_run tallies blocking sub-goals over every replicate", {
  result_list <- list(
    summarise_replicate(.make_pair(active_id = "PRE-035", turn_number = 2L),
                        "dl_test", 1L),
    summarise_replicate(.make_pair(active_id = "PRE-035", turn_number = 2L),
                        "dl_test", 2L),
    summarise_replicate(.make_pair(active_id = "TEF-068", turn_number = 2L),
                        "dl_test", 3L))

  summary_list <- summarise_run(result_list)

  expect_equal(as.integer(summary_list$block_tally_vec[["A"]]), 2L)
  expect_equal(as.integer(summary_list$block_tally_vec[["B"]]), 1L)
  expect_equal(summary_list$num_replicates, 3L)
  expect_equal(summary_list$hit_rate, 0)
})

test_that("the trace is kept only when asked for", {
  ## 10,000 traces per cell is the thing the sampling design exists to avoid, so
  ## the default must be off.
  pair <- .finished_pair(bool_evolved = TRUE)

  expect_true(is.null(summarise_replicate(pair, "dl_test", 1L)$trace_vec))
  expect_false(is.null(summarise_replicate(pair, "dl_test", 1L,
                                           bool_keep_trace = TRUE)$trace_vec))
})

test_that("the trace header carries the verdict, side and mulligan count", {
  pair <- .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005")
  pair$state$num_mulligans <- 1L
  result <- summarise_replicate(attack_evolution_jammer(pair), "dl_test",
                                seed_number = 7L, bool_keep_trace = TRUE)

  expect_true(grepl("^#7 ", result$trace_vec[1]))
  expect_true(grepl("2nd", result$trace_vec[1]))
  expect_true(grepl("mull=1", result$trace_vec[1]))
  expect_true(grepl("HIT t2", result$trace_vec[1]))
})

test_that("a missed trace names the blocking sub-goal in its header", {
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, "dl_test", seed_number = 3L,
                                bool_keep_trace = TRUE)

  expect_true(grepl("MISS block=D", result$trace_vec[1]))
  expect_true(grepl("psychic_attached", result$trace_vec[1]))
})

test_that("an unused out is flagged prominently in the trace", {
  ## This line is the reason the trace exists, so it must be impossible to miss
  ## when skimming a file of them.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  result <- summarise_replicate(pair, "dl_test", seed_number = 4L,
                                bool_keep_trace = TRUE)

  expect_true(any(grepl("UNUSED OUT", result$trace_vec)))
  expect_true(any(grepl("Switch", result$trace_vec)))
})

test_that("traces show card names, not ids, and hide level-2 primitives", {
  ## Card ids are unambiguous but unreadable; and keeping zone moves, shuffles
  ## and draws triples the length while hiding the decisions.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-069",
                     turn_number = 2L)
  pair <- evolve_pokemon(pair, "TEF-069", target_is_active = TRUE)
  result <- summarise_replicate(pair, "dl_test", seed_number = 5L,
                                bool_keep_trace = TRUE)
  trace_str <- paste0(result$trace_vec, collapse = " ")

  expect_true(grepl("Bronzong", trace_str))
  expect_false(grepl("TEF-069", trace_str))
  expect_false(grepl("move 1 hand->discard", trace_str))
})

test_that("the trace is compact enough to read many of at once", {
  ## A trace nobody will read is a trace that does not do its job. Cap the
  ## per-replicate line count so a 200-trace file stays skimmable.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:15){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    pair$state <- begin_turn(pair$state)
    pair$state <- log_hand_snapshot(pair$state)
    pair$state <- begin_turn(pair$state)
    pair$state <- log_hand_snapshot(pair$state)

    result <- summarise_replicate(pair, "dl_test", seed_number = one_seed,
                                  bool_keep_trace = TRUE)
    expect_true(length(result$trace_vec) <= 8,
                info = paste0("seed ", one_seed, ": ",
                              length(result$trace_vec), " lines"))
  }
})

test_that("the sampler stratifies toward misses and respects both quotas", {
  ## ADR 0006. A uniform sample of a good decklist is mostly hits, and hits
  ## teach nothing about what to change.
  sampler <- new_trace_sampler(max_miss = 3L, max_hit = 1L)

  keep_vec <- logical(0)
  for(bool_hit in c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)){
    take_list <- sampler_take(sampler, bool_hit)
    sampler <- take_list$sampler
    keep_vec <- c(keep_vec, take_list$bool_keep)
  }

  expect_equal(keep_vec, c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE))
  expect_equal(sampler$num_miss, 3L)
  expect_equal(sampler$num_hit, 1L)
  expect_true(sampler_is_full(sampler))
})

test_that("a zero quota keeps nothing and is immediately full", {
  sampler <- new_trace_sampler(max_miss = 0L, max_hit = 0L)

  expect_false(sampler_take(sampler, TRUE)$bool_keep)
  expect_false(sampler_take(sampler, FALSE)$bool_keep)
  expect_true(sampler_is_full(sampler))
})

test_that("the trace file warns that no rate may be computed from it", {
  ## The natural thing for a reader -- or an agent told to "look at the traces"
  ## -- is to count them. The file has to say, up front, that counting is wrong.
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, "dl_test", 1L, bool_keep_trace = TRUE)
  summary_list <- summarise_run(list(result))

  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(result), tmp_file, summary_list)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("Never compute a rate", line_vec)))
  expect_true(any(grepl("STRATIFIED", line_vec)))
  expect_true(any(grepl("hit rate", line_vec)))
  expect_true(any(grepl("mulligan rate", line_vec)))
  expect_true(any(grepl("Mulligans never count as a miss", line_vec)))
})

test_that("the trace file reports rates from the run, not from the sample", {
  ## The header numbers must come from summarise_run() over every replicate, so
  ## that a file holding 1 trace can still report a rate over 400 games.
  hit_pair <- attack_evolution_jammer(
    .finished_pair(bool_evolved = TRUE, energy_vec = "SVE-005"))
  miss_pair <- .finished_pair(bool_evolved = TRUE)

  result_list <- c(lapply(1:3, function(i){
    summarise_replicate(hit_pair, "dl_test", i)
  }), lapply(4:10, function(i){
    summarise_replicate(miss_pair, "dl_test", i)
  }))
  summary_list <- summarise_run(result_list)

  ## Keep a single HIT trace, so the sample is 100% hits and the run is 30%.
  kept <- summarise_replicate(hit_pair, "dl_test", 1L, bool_keep_trace = TRUE)
  tmp_file <- tempfile(fileext = ".txt")
  write_trace_file(list(kept), tmp_file, summary_list)
  line_vec <- readLines(tmp_file)

  expect_true(any(grepl("hit rate \\(t<=2\\): 30.00%", line_vec)))
  expect_true(any(grepl("replicates     : 10", line_vec)))
  expect_true(any(grepl("traces kept    : 1", line_vec)))
})

test_that("every replicate records its seed so a trace can be replayed", {
  ## A trace you cannot reproduce is an anecdote.
  pair <- .finished_pair(bool_evolved = TRUE)
  result <- summarise_replicate(pair, "dl_test", seed_number = 4242L)

  expect_equal(result$seed_number, 4242L)
})

test_that("log_hand_snapshot records the hand and is level 1", {
  pair <- .make_pair(hand_id_vec = c("MEG-130", "TEF-069"), turn_number = 1L)
  state <- log_hand_snapshot(pair$state)

  expect_true(grepl("hand\\[", state$event_log[length(state$event_log)]))
  expect_equal(state$event_level_vec[length(state$event_level_vec)], 1L)
})

test_that("an empty hand snapshot renders as a dash, not an empty string", {
  pair <- .make_pair(active_id = NULL, turn_number = 1L)
  pair$state$hand_vec <- character(0)
  state <- log_hand_snapshot(pair$state)

  expect_true(grepl("hand\\[-\\]", state$event_log[length(state$event_log)]))
})
