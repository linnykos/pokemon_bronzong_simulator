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
num_seeds <- 500L

# Positions are drawn from more than one decklist now. decklist2 is still the
# reference -- it runs both Salvatore and Latias ex, so the turn-1 kill and the
# free-retreat rung are both expressible in it -- but decklist7 is a different
# deck rather than a variation, and the questions it raises (Gwynn, Risky Ruins,
# a Poffin that cannot fetch a Bronzor) cannot be asked from decklist2 at all.
DECKLIST_LIST <- lapply(stats::setNames(nm = c("decklist2", "decklist7")),
                        function(one_name){
                          read_decklist(file.path("decklists",
                                                  paste0(one_name, ".txt")),
                                        card_df)
                        })

# ---------------------------------------------------------------------------
# Reaching a decision point
# ---------------------------------------------------------------------------

#' Play up to the start of a turn and stop before deciding
#'
#' @param seed_number the replicate's seed.
#' @param turn_number 1 or 2; turn 2 has turn 1 played by the policy first.
#' @param bool_going_first the coin flip.
#' @param scenario the opponent model.
#' @param decklist_name which list in `DECKLIST_LIST` to play.
#'
#' @returns The `list(state, knowledge)` pair at the decision point, or `NULL`
#'   if the game ended first.
#' @noRd
.state_at_decision <- function(seed_number,
                               turn_number,
                               bool_going_first = FALSE,
                               scenario = "clear",
                               decklist_name = "decklist2"){
  pair <- setup_game(DECKLIST_LIST[[decklist_name]], card_df,
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

#' Which of sub-goals B, C, D would still be open if the turn stopped now
#'
#' Re-exported from the policy so a predicate can ask the same question section
#' 6 asks. Naming it here rather than inlining the arithmetic keeps the bank and
#' the tree reading the same way.
#' @noRd
.gaps <- function(pair) .missing_bcd_vec(pair)

# One predicate per question worth asking. Each names the sections and question
# ids it probes, so a scenario cannot drift loose from the document it is for.
#
# The bank is renumbered from S-27: S-01 to S-26 are answered, their answers are
# rules in docs/03_decision_tree.md and docs/03a_card_playbook.md now, and the
# answers themselves are archived verbatim in HISTORY_kevin.md.
#
# THREE THINGS ARE DELIBERATELY DIFFERENT ABOUT THIS BANK.
#
# It leaves the going-second `clear` cell. Every position S-15 to S-26 came from
# there, and it is one of three cells the registry reports -- so two thirds of
# what the project measures had never been put as a question. Going first is the
# weaker branch by twelve points and has never been asked about at all.
#
# It leaves decklist2. decklist7 is a different deck rather than a variation, and
# the questions it raises cannot be asked from decklist2: a Gwynn to rank, a
# Stadium that damages our own Bench, and a Buddy-Buddy Poffin that cannot fetch
# a Bronzor because both printings in that list are 80 HP.
#
# And it asks about turns the metric has already lost. The registry's misses are
# where the next decision defect lives, and a bank made only of winnable
# positions cannot find one.
PREDICATE_LIST <- list(
  list(id = "S-27",
       label = "Gwynn and Lillie's competing for the same slot",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist7", probes = "DT-27",
       test = function(pair){
         .holds(pair, "PBL-078") && .holds(pair, "MEG-119") &&
           length(.gwynn_discards(pair)) > 0
       }),
  list(id = "S-28",
       label = "A won turn with a spare Salvatore and a spare Ciphermaniac's",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "DT-26",
       test = function(pair){
         .holds(pair, "TEF-160") && .holds(pair, "TEF-145") &&
           length(.missing_bcd_vec(pair)) == 0
       }),
  list(id = "S-29",
       label = "Rare Candy on a turn the metric has already lost",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "DT-23, PB-13",
       test = function(pair){
         .holds(pair, "MEG-125") && .holds(pair, "PRE-037") &&
           !believes_findable(pair$knowledge, pair$state, "TEF-069") &&
           !.holds(pair, "TEF-069") && !.subgoal_status(pair$state)[["b"]]
       }),
  list(id = "S-30",
       label = "Salvatore against Hilda with no Item that can fetch Bronzong",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "DT-25",
       test = function(pair){
         .holds(pair, "TEF-160") && .holds(pair, "WHT-084") &&
           !.holds(pair, "POR-081") && !.holds(pair, "MEG-131") &&
           !.subgoal_status(pair$state)[["b"]] && !.holds(pair, "TEF-069") &&
           .psychic_secured(pair$state)
       }),
  list(id = "S-31",
       label = "Ultra Ball paying two cards for a Duskull",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "PB-01, PB-15",
       test = function(pair){
         if(!.holds(pair, "MEG-131")) return(FALSE)
         if(is.null(.ultra_ball_discards(pair))) return(FALSE)

         target_id <- .first_findable(pair,
                                      c(.want_vec(pair), "SSP-076"),
                                      ALLOWED_TARGET_LIST$ultra_ball)
         identical(target_id, "PRE-035")
       }),
  list(id = "S-32",
       label = "Turn 1 going first, where no Supporter may be played",
       turn_number = 1L, bool_going_first = TRUE, scenario = "clear",
       decklist = "decklist2", probes = "DT-18, and section 5 as a whole",
       test = function(pair){
         # A Supporter in hand that cannot be played, and a Meowth ex that can
         # fetch another -- the position section 5 step 1 calls the one branch
         # where benching Meowth ex is close to automatic.
         .holds(pair, "POR-062") &&
           length(intersect(pair$state$hand_vec,
                            c("WHT-084", "MEG-119", "TEF-160"))) > 0
       }),
  list(id = "S-33",
       label = "Turn 2 under the Item lock, with the Supporter alone",
       turn_number = 2L, bool_going_first = TRUE, scenario = "item_lock",
       decklist = "decklist2", probes = "the `item_lock` cell, never asked",
       test = function(pair){
         length(.missing_bcd_vec(pair)) >= 1 &&
           length(intersect(pair$state$hand_vec,
                            c("WHT-084", "MEG-119", "TEF-160"))) > 0 &&
           length(intersect(pair$state$hand_vec,
                            c("MEG-131", "POR-081", "MEG-130"))) > 0
       }),
  # PB-11 asks which Stadium to play when holding two. Left in the list rather
  # than deleted, because "no example found" is itself the answer while no
  # decklist runs two DIFFERENT Stadiums -- decklist2 runs one Jamming Tower,
  # and decklist7's two copies are both Risky Ruins, which cannot replace each
  # other. A future list that runs two names re-raises it automatically.
  list(id = "S-34",
       label = "Two different Stadiums in hand and one slot",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "PB-11",
       test = function(pair){
         hand_df <- lookup_card(pair$state$card_df, pair$state$hand_vec)
         stadium_vec <- hand_df$name[!is.na(hand_df$subtype) &
                                       hand_df$subtype == "stadium"]
         length(unique(stadium_vec)) >= 2
       }),
  list(id = "S-35",
       label = "A Poffin that cannot fetch the Bronzor the turn needs",
       turn_number = 1L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist7", probes = "PB-01, and the Bronzor printing",
       test = function(pair){
         .holds(pair, "TEF-144") && !.subgoal_status(pair$state)[["a"]] &&
           length(intersect(pair$state$hand_vec,
                            .bronzor_ids(pair$state$card_df))) == 0
       }),
  list(id = "S-36",
       label = "Risky Ruins as the only Stadium in hand",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist7", probes = "PB-11, and section 4.2 step 7",
       test = function(pair){
         .holds(pair, "MEG-127") && is.na(pair$state$stadium) &&
           length(pair$state$bench_list) > 0
       }),
  list(id = "S-37",
       label = "Blissey ex in hand, and no Chansey in the deck",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist7", probes = "a decklist question, not a policy one",
       test = function(pair) .holds(pair, "TWM-134")),
  list(id = "S-38",
       label = "A miss where the attachment was the only thing missing",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "DT-01",
       test = function(pair){
         identical(.missing_bcd_vec(pair), "d") &&
           length(.psychic_in_hand(pair$state)) == 0
       }),
  # Found by reading S-36's own turn-1 log rather than by asking for it: the
  # Telepathic went onto a Latias ex because no Bronzor was in play at the
  # moment of attaching, and the search it fired then put a Bronzor into play a
  # moment too late to receive it. Sub-goal D is unmet and the [P] source is
  # sitting on a body that can never attack.
  list(id = "S-39",
       label = "The [P] source stranded on a body that cannot attack",
       turn_number = 2L, bool_going_first = FALSE, scenario = "clear",
       decklist = "decklist2", probes = "DT-01, and section 4.2 step 6",
       test = function(pair){
         state <- pair$state
         if(.psychic_secured(state)) return(FALSE)
         if(!.subgoal_status(state)[["a"]]) return(FALSE)

         # A [P] source attached SOMEWHERE, but not on the line -- which is what
         # .psychic_secured() having returned FALSE already tells us.
         any(sapply(all_in_play(state), function(one){
           .has_psychic_attached(state, one)
         }))
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
                     ", `", state$scenario, "`, **", spec_list$decklist, "**")

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
shown_vec <- character(0)

for(i in seq_along(PREDICATE_LIST)){
  spec_list <- PREDICATE_LIST[[i]]
  for(one_seed in seq_len(num_seeds)){
    pair <- .state_at_decision(one_seed,
                               turn_number = spec_list$turn_number,
                               bool_going_first = spec_list$bool_going_first,
                               scenario = spec_list$scenario,
                               decklist_name = spec_list$decklist)
    if(is.null(pair)) next
    if(!spec_list$test(pair)) next

    count_vec[i] <- count_vec[i] + 1L
    # Two predicates can both match the same seed, and rendering one position
    # twice under two ids asks the reader the same question twice while looking
    # like two questions. Keep the count -- the frequency is still true -- but
    # show a different example.
    key_str <- paste0(one_seed, "/", spec_list$turn_number, "/",
                      spec_list$bool_going_first, "/", spec_list$scenario,
                      "/", spec_list$decklist)
    if(is.null(hit_list[[i]]) && !key_str %in% shown_vec){
      # A scenario must be a legal position or it teaches the wrong lesson.
      stopifnot(length(.census(pair$state)) == 60)
      pair$state$seed_label <- one_seed
      hit_list[[i]] <- pair
      shown_vec <- c(shown_vec, key_str)
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
