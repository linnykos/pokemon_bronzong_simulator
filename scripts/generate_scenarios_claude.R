# Find real board states worth asking Kevin about, and render them.
#
# The scenario bank in docs/03b_scenarios.md exists to compare Kevin's intuition
# against docs/03_decision_tree.md. That works only if the positions are ones
# the simulator actually reaches -- an invented hand can be answered "I would
# never be here", which settles nothing. So each OBSERVED scenario is a real
# state from a named seed, carrying how often a state like it came up.
#
# The frequency is the point as much as the position is. A question about a spot
# that arises in 1 game in 500 is not worth Kevin's afternoon; one that arises
# in a third of games is.
#
# States are snapshotted at the start of a turn, AFTER the draw and BEFORE the
# policy acts, which is the moment a player would actually be deciding.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" \
#     scripts/generate_scenarios_claude.R

rm(list = ls())

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

card_df <- build_card_database()
decklist <- read_decklist(file.path("decklists", "decklist2.txt"), card_df)
num_seeds <- 500L

# ---------------------------------------------------------------------------
# Reaching a decision point
# ---------------------------------------------------------------------------

#' Play up to the start of a turn and stop before deciding
#'
#' @param seed_number the replicate's seed.
#' @param turn_number 1 or 2; turn 2 has turn 1 played by the policy first.
#' @param bool_going_first the coin flip.
#' @param scenario the opponent model.
#'
#' @returns The `list(state, knowledge)` pair at the decision point, or `NULL`
#'   if the game ended first.
#' @noRd
.state_at_decision <- function(seed_number,
                               turn_number,
                               bool_going_first = FALSE,
                               scenario = "clear"){
  pair <- setup_game(decklist, card_df,
                     bool_going_first = bool_going_first,
                     placement_fn = policy_placement,
                     scenario = scenario,
                     seed_number = seed_number)

  for(one_turn in seq_len(turn_number)){
    pair$state <- begin_turn(pair$state)
    pair <- draw_to_hand(pair, num_cards = 1L)
    if(one_turn == turn_number) return(pair)

    pair <- policy_turn(pair)
    if(isTRUE(pair$state$bool_no_pokemon)) return(NULL)
  }

  pair
}

# ---------------------------------------------------------------------------
# What makes a position worth asking about
# ---------------------------------------------------------------------------

#' Every card in the game, wherever it is
#'
#' The same census the tests use, repeated here because it lives in
#' `tests/testthat/helper_fixtures.R` and this script does not load the test
#' harness. A scenario that is not a legal 60 teaches the wrong lesson.
#' @noRd
.census <- function(state){
  in_play_vec <- unlist(lapply(all_in_play(state), function(x) x$stack_vec))
  energy_vec <- unlist(lapply(all_in_play(state), function(x) x$energy_vec))

  sort(c(state$deck_vec, state$hand_vec, state$prize_vec, state$discard_vec,
         in_play_vec, energy_vec, state$stadium[!is.na(state$stadium)]))
}

#' Does the hand hold this card?
#' @noRd
.holds <- function(pair, card_id) card_id %in% pair$state$hand_vec

#' Is the Bronzor line in play but not Active?
#' @noRd
.line_benched <- function(pair){
  length(.bench_idx_named(pair$state, c("Bronzor", "Bronzong"))) > 0 &&
    !.active_is(pair$state, c("Bronzor", "Bronzong"))
}

# One predicate per question worth asking. Each names the sections and question
# ids it probes, so a scenario cannot drift loose from the document it is for.
PREDICATE_LIST <- list(
  list(id = "S-01",
       label = "Free retreat and a Switch both available for the same job",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-08, DT-09",
       test = function(pair){
         .line_benched(pair) && .holds(pair, "MEG-130") &&
           length(.bench_idx_named(pair$state, "Latias ex")) > 0 &&
           can_retreat(pair$state) && retreat_cost(pair$state) == 0
       }),
  list(id = "S-02",
       label = "Kangaskhan Active on turn 2, the line on the Bench",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-11, DT-04",
       test = function(pair){
         .active_is(pair$state, "Mega Kangaskhan ex") && .line_benched(pair)
       }),
  list(id = "S-03",
       label = "Lillie's and Hilda in the same hand",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-15, DT-14",
       test = function(pair){
         .holds(pair, "MEG-119") && .holds(pair, "WHT-084")
       }),
  list(id = "S-04",
       label = "Hilda in hand with both her targets already held",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-14",
       test = function(pair){
         .holds(pair, "WHT-084") && .holds(pair, "TEF-069") &&
           length(.psychic_in_hand(pair$state)) > 0
       }),
  list(id = "S-05",
       label = "Ciphermaniac's on P2T1 with another Supporter in hand",
       turn_number = 1L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-17",
       test = function(pair){
         .holds(pair, "TEF-145") &&
           any(c("WHT-084", "MEG-119") %in% pair$state$hand_vec)
       }),
  list(id = "S-06",
       label = "Salvatore still in hand on turn 2",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-13",
       test = function(pair) .holds(pair, "TEF-160")),
  list(id = "S-07",
       label = "Ultra Ball with nothing spare to pay for it",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "PB-05, PB-06",
       test = function(pair){
         .holds(pair, "MEG-131") && is.null(.ultra_ball_discards(pair))
       }),
  list(id = "S-08",
       label = "Buneary Active with the line benched",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-06, DT-07",
       test = function(pair){
         .active_is(pair$state, "Buneary") && .line_benched(pair)
       }),
  list(id = "S-09",
       label = "Going first, turn 1, no Supporter legal",
       turn_number = 1L, bool_going_first = TRUE, scenario = "clear",
       probes = "DT-12, DT-19",
       test = function(pair){
         length(intersect(pair$state$hand_vec,
                          c("WHT-084", "MEG-119", "TEF-145", "TEF-160"))) > 0
       }),
  list(id = "S-10",
       label = "Items locked on turn 2, going first",
       turn_number = 2L, bool_going_first = TRUE, scenario = "item_lock",
       probes = "DT-20",
       test = function(pair){
         items_are_locked(pair$state) &&
           length(intersect(pair$state$hand_vec,
                            c("MEG-130", "MEG-131", "POR-081"))) > 0
       }),
  list(id = "S-11",
       label = "Bench nearly full while Telepathic wants two more bodies",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-10, PB-03",
       test = function(pair){
         .holds(pair, "POR-088") && length(pair$state$bench_list) >= 3 &&
           can_attach_energy(pair$state)
       }),
  list(id = "S-12",
       label = "Two Bronzong in hand and nothing to put them on",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       probes = "DT-03, PB-08",
       test = function(pair){
         sum(pair$state$hand_vec == "TEF-069") >= 1 &&
           !.active_is(pair$state, c("Bronzor", "Bronzong")) &&
           !.line_benched(pair)
       }))

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

#' One position, as the reader sees it
#'
#' Deliberately does NOT show what the policy did next: the tree's answer lives
#' in appendix A so that reading the question cannot anchor the answer.
#' @noRd
.render_position <- function(pair, spec_list, num_hits){
  state <- pair$state
  cell_str <- paste0("turn ", state$turn_number, ", going ",
                     if(state$bool_going_first) "first" else "second",
                     ", `", state$scenario, "`")

  bench_str <- if(length(state$bench_list) == 0) "(empty)" else
    paste0(sapply(state$bench_list, function(one){
      .in_play_str(state$card_df, one)
    }), collapse = " | ")

  prior_vec <- readable_log(state)
  prior_vec <- prior_vec[!grepl("^hand\\[", prior_vec)]

  c(paste0("### ", spec_list$id, " — ", spec_list$label),
    "",
    paste0("*", cell_str, ". Seed ", state$seed_label,
           "; a position like this arose in ", num_hits, " of ", num_seeds,
           " games (", round(100 * num_hits / num_seeds, 1), "%).*"),
    "",
    "```",
    paste0("  active   ", if(is.null(state$active)) "-" else
      .in_play_str(state$card_df, state$active)),
    paste0("  bench    ", bench_str),
    paste0("  hand     ", .zone_str(state$card_df, state$hand_vec)),
    paste0("  discard  ", .zone_str(state$card_df, state$discard_vec)),
    paste0("  deck     ", length(state$deck_vec), " cards   prizes ",
           length(state$prize_vec), "   stadium ",
           if(is.na(state$stadium)) "-" else
             .short_name(state$card_df, state$stadium)),
    "```",
    "",
    if(length(prior_vec) == 0) "Nothing has happened yet this game." else
      paste0("Already played: ", paste0(prior_vec, collapse = "; "), "."),
    "",
    paste0("**Probes ", spec_list$probes, ".**"),
    "")
}

# ---------------------------------------------------------------------------
# The sweep
# ---------------------------------------------------------------------------

print(paste0("sweeping ", num_seeds, " seeds for ", length(PREDICATE_LIST),
             " positions"))

hit_list <- vector("list", length(PREDICATE_LIST))
count_vec <- integer(length(PREDICATE_LIST))

for(i in seq_along(PREDICATE_LIST)){
  spec_list <- PREDICATE_LIST[[i]]
  for(one_seed in seq_len(num_seeds)){
    pair <- .state_at_decision(one_seed,
                               turn_number = spec_list$turn_number,
                               bool_going_first = spec_list$bool_going_first,
                               scenario = spec_list$scenario)
    if(is.null(pair)) next
    if(!spec_list$test(pair)) next

    count_vec[i] <- count_vec[i] + 1L
    if(is.null(hit_list[[i]])){
      # A scenario must be a legal position or it teaches the wrong lesson.
      stopifnot(length(.census(pair$state)) == 60)
      pair$state$seed_label <- one_seed
      hit_list[[i]] <- pair
    }
  }
  print(paste0(spec_list$id, ": ", count_vec[i], "/", num_seeds,
               if(is.null(hit_list[[i]])) "  (NO EXAMPLE FOUND)" else ""))
}

line_vec <- character(0)
for(i in seq_along(PREDICATE_LIST)){
  if(is.null(hit_list[[i]])) next
  line_vec <- c(line_vec,
                .render_position(hit_list[[i]], PREDICATE_LIST[[i]],
                                 count_vec[i]))
}

# What the policy does from each position, computed rather than remembered. This
# is the appendix material: it must be true, and the way to make it true is to
# run it.
answer_vec <- c("", "## What the policy does from each position", "")
for(i in seq_along(PREDICATE_LIST)){
  if(is.null(hit_list[[i]])) next

  played <- policy_turn(hit_list[[i]])
  action_vec <- readable_log(played$state,
                             turn_number = played$state$turn_number)
  action_vec <- action_vec[!grepl("^hand\\[", action_vec)]
  answer_vec <- c(answer_vec,
                  paste0("- **", PREDICATE_LIST[[i]]$id, "** — ",
                         if(length(action_vec) == 0) "nothing at all." else
                           paste0(paste0(action_vec, collapse = "; "), ".")))
}

out_path <- file.path("docs", "03b_generated_positions.md")
writeLines(c("<!-- Generated by scripts/generate_scenarios_claude.R.",
             "     Positions only: the questions and options are written by",
             "     hand into docs/03b_scenarios.md. -->",
             "",
             line_vec, answer_vec),
           out_path)
print(paste0("wrote ", out_path))
