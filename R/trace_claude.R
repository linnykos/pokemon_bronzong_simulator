# Replicate results, diagnosis, and human/agent-readable traces.
#
# Two outputs, for two different questions:
#
#   1. The RATE -- one number per cell, computed over every replicate. This is
#      what part 6 aggregates and what ranks decklists. Traces are not stored
#      for these, because 10,000 traces per cell is unusable.
#   2. The TRACE -- a compact account of what happened in one replicate, stored
#      for a small sampled subset. This is what you read (or point an agent at)
#      when the question is "should the DECISION TREE change", not "which deck
#      is better". See ADR 0006.
#
# The trace's job is to make a decision defect visible. A trace that only says
# MISS is nearly useless; one that says "MISS, blocked on sub-goal C, and Switch
# was in hand the whole time" identifies a policy bug in one line. That is what
# `blocking_subgoal` and `unused_out_vec` are for.

# ---------------------------------------------------------------------------
# Diagnosis
# ---------------------------------------------------------------------------

#' The four sub-goals of the target event
#'
#' From docs/03_decision_tree.md section 1. Ordered, because the diagnosis
#' reports the FIRST unmet one -- that is the thing that actually stopped the
#' line, and reporting all of them would bury it.
#'
#' @export
SUBGOAL_VEC <- c(A = "bronzor_in_play",
                 B = "bronzong_on_it",
                 C = "bronzong_active",
                 D = "psychic_attached")

#' Which sub-goal blocked this replicate?
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#'
#' @returns A single character: `"A"`, `"B"`, `"C"`, `"D"`, or `NA` when all
#'   four are met (in which case the miss was a timing or legality problem, not
#'   a missing piece).
#' @export
blocking_subgoal <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  in_play_list <- all_in_play(state)
  if(length(in_play_list) == 0) return("A")

  name_vec <- sapply(in_play_list, function(one){
    lookup_card(state$card_df, top_card(one))$name
  })
  top_vec <- sapply(in_play_list, top_card)

  # A: a Bronzor OR a Bronzong is in play -- a Bronzong satisfies A implicitly,
  # since it can only have got there by sitting on a Bronzor.
  if(!any(name_vec %in% c("Bronzor", "Bronzong"))) return("A")

  bronzong_idx_vec <- which(top_vec == "TEF-069")
  if(length(bronzong_idx_vec) == 0) return("B")

  # C and D are evaluated on the Bronzong best placed to attack: an Active one
  # if there is one, otherwise any.
  bool_active_bronzong <- !is.null(state$active) &&
    top_card(state$active) == "TEF-069"
  if(!bool_active_bronzong) return("C")

  if(!has_evolution_jammer_cost(state, state$active)) return("D")

  NA_character_
}

#' Outs that were sitting unused when the replicate ended
#'
#' The most useful field in the whole trace. If the blocking sub-goal was C and
#' a Switch was in hand, the deck was not the problem -- the DECISION was. This
#' is precisely the signal that tells you to change docs/03_decision_tree.md
#' rather than the 60 cards.
#'
#' Reads the hand only, which is information the player unambiguously had.
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#' @param subgoal_str the blocking sub-goal from \code{blocking_subgoal()}.
#'
#' @returns A character vector of card ids in hand that could have advanced the
#'   blocked sub-goal, empty when there were none.
#' @export
unused_outs <- function(state, subgoal_str){
  stopifnot(inherits(state, "bronzong_state"))
  if(is.na(subgoal_str)) return(character(0))

  # Cards that advance each sub-goal, per docs/03a_card_playbook.md. Only cards
  # playable from HAND appear: an out in the deck is not an unused out, it is an
  # undrawn one.
  out_list <- list(
    A = c("POR-081", "MEG-131", "TEF-144", "JTG-146", "WHT-084", "POR-088"),
    B = c("TEF-160", "WHT-084", "JTG-146", "POR-081", "MEG-131", "TEF-069"),
    C = c("MEG-130", "SSP-187"),
    D = c("SVE-005", "POR-088"))

  intersect(state$hand_vec, out_list[[subgoal_str]])
}

# ---------------------------------------------------------------------------
# Replicate results
# ---------------------------------------------------------------------------

#' Summarise one finished replicate
#'
#' Called once per replicate, whether or not a trace is being kept. Everything
#' the aggregate needs is here; the trace is an optional extra.
#'
#' @param pair the finished `list(state, knowledge)`.
#' @param decklist_id the decklist's content hash.
#' @param seed_number the seed this replicate ran under, so any result can be
#'   reproduced exactly.
#' @param bool_keep_trace whether to attach the formatted trace.
#'
#' @returns An object of class `"bronzong_result"`: a list with
#'   \describe{
#'     \item{decklist_id, scenario, bool_going_first, seed_number}{the cell.}
#'     \item{jammer_turn}{integer turn the attack was made, or `NA`.}
#'     \item{bool_hit}{whether Evolution Jammer was used by the player's own
#'       turn 2 -- the primary outcome (ADR 0004).}
#'     \item{num_mulligans}{how many times this player mulliganed. An ORTHOGONAL
#'       metric: mulligans never count as a miss (ADR 0005).}
#'     \item{bool_mulliganed}{whether at least one mulligan was needed.}
#'     \item{blocking_subgoal}{`"A"`-`"D"` or `NA`; see
#'       \code{blocking_subgoal()}.}
#'     \item{unused_out_vec}{outs left in hand; see \code{unused_outs()}.}
#'     \item{trace_vec}{formatted trace lines, or `NULL`.}
#'   }
#' @export
summarise_replicate <- function(pair,
                                decklist_id,
                                seed_number = NA_integer_,
                                bool_keep_trace = FALSE){
  stopifnot(is.list(pair), inherits(pair$state, "bronzong_state"))
  state <- pair$state

  subgoal_str <- if(is.na(state$jammer_turn)) blocking_subgoal(state) else
    NA_character_

  result <- structure(
    list(decklist_id = decklist_id,
         scenario = state$scenario,
         bool_going_first = state$bool_going_first,
         seed_number = as.integer(seed_number),
         jammer_turn = state$jammer_turn,
         # ADR 0004: the bar is the player's own turn 2, and it is the ATTACK
         # that counts, not the attack merely having been available.
         bool_hit = !is.na(state$jammer_turn) && state$jammer_turn <= 2L,
         num_mulligans = state$num_mulligans,
         bool_mulliganed = state$num_mulligans > 0L,
         blocking_subgoal = subgoal_str,
         unused_out_vec = unused_outs(state, subgoal_str),
         trace_vec = NULL),
    class = "bronzong_result")

  if(bool_keep_trace) result$trace_vec <- format_trace(pair, result)

  result
}

#' Format one replicate as compact trace lines
#'
#' Optimised for reading, not for parsing: short card names, one line per turn,
#' the verdict first. Level-2 log entries (zone moves, shuffles, draws) are
#' dropped -- keeping them triples the length and hides the decisions, which is
#' the one thing the trace exists to show.
#'
#' @param pair the finished `list(state, knowledge)`.
#' @param result the `"bronzong_result"` for the same replicate.
#'
#' @returns A character vector of trace lines.
#' @export
format_trace <- function(pair, result){
  state <- pair$state
  card_df <- state$card_df

  verdict_str <- if(result$bool_hit){
    paste0("HIT t", result$jammer_turn)
  } else if(!is.na(result$jammer_turn)){
    paste0("LATE t", result$jammer_turn)
  } else {
    paste0("MISS block=", result$blocking_subgoal,
           " (", SUBGOAL_VEC[[result$blocking_subgoal]], ")")
  }

  header_str <- paste0("#", result$seed_number, " ",
                       if(state$bool_going_first) "1st" else "2nd", " ",
                       state$scenario,
                       " mull=", result$num_mulligans,
                       " | ", verdict_str)

  # The unused-out line is the whole point of the trace: it separates "the deck
  # did not give me the card" from "I had the card and did not play it".
  unused_str <- if(length(result$unused_out_vec) > 0){
    paste0("  !! UNUSED OUT in hand: ",
           paste0(.short_name(card_df, result$unused_out_vec), collapse = ", "))
  } else NULL

  board_str <- paste0("  end  active=",
                      if(is.null(state$active)) "-" else
                        .short_name(card_df, top_card(state$active)),
                      .energy_suffix(card_df, state$active),
                      "  bench=",
                      if(length(state$bench_list) == 0) "-" else
                        paste0(sapply(state$bench_list, function(one){
                          paste0(.short_name(card_df, top_card(one)),
                                 .energy_suffix(card_df, one))
                        }), collapse = ","),
                      "  hand=", length(state$hand_vec))

  c(header_str, unused_str, .turn_lines(state), board_str)
}

# ---------------------------------------------------------------------------
# Trace sampling
# ---------------------------------------------------------------------------

#' Create a trace sampler
#'
#' Traces are STRATIFIED by outcome, not a random subsample, because misses are
#' what you learn from and a random 200 out of 10,000 would be mostly hits once
#' a decklist is any good. That makes the trace file deliberately unrepresentative
#' of the rate -- see ADR 0006 -- so the written file carries a warning and no
#' rate may ever be computed from it.
#'
#' @param max_miss how many missed replicates to keep.
#' @param max_hit how many hit replicates to keep.
#'
#' @returns An object of class `"bronzong_sampler"`.
#' @export
new_trace_sampler <- function(max_miss = 150L, max_hit = 50L){
  check_whole_number(max_miss, "max_miss", 0L)
  check_whole_number(max_hit, "max_hit", 0L)

  structure(list(max_miss = as.integer(max_miss),
                 max_hit = as.integer(max_hit),
                 num_miss = 0L,
                 num_hit = 0L),
            class = "bronzong_sampler")
}

#' Should this replicate's trace be kept?
#'
#' Asked BEFORE the replicate runs is impossible -- whether it hit is only known
#' at the end -- so the caller records the trace unconditionally into the result
#' and then asks this to decide whether to retain it. Traces are cheap to build
#' and expensive only to store, so this ordering costs little.
#'
#' @param sampler a `"bronzong_sampler"`.
#' @param bool_hit whether the replicate hit.
#'
#' @returns A list with `sampler` (updated counts) and `bool_keep`.
#' @export
sampler_take <- function(sampler, bool_hit){
  stopifnot(inherits(sampler, "bronzong_sampler"))

  if(bool_hit){
    bool_keep <- sampler$num_hit < sampler$max_hit
    if(bool_keep) sampler$num_hit <- sampler$num_hit + 1L
  } else {
    bool_keep <- sampler$num_miss < sampler$max_miss
    if(bool_keep) sampler$num_miss <- sampler$num_miss + 1L
  }

  list(sampler = sampler, bool_keep = bool_keep)
}

#' Is the sampler full?
#'
#' Lets a run stop building traces once both quotas are met.
#'
#' @param sampler a `"bronzong_sampler"`.
#'
#' @returns A single logical.
#' @export
sampler_is_full <- function(sampler){
  sampler$num_hit >= sampler$max_hit && sampler$num_miss >= sampler$max_miss
}

# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

#' Write sampled traces to a text file
#'
#' The file is meant to be read whole by a person or an agent, so it opens with
#' the aggregate numbers it must NOT be used to recompute, then a diagnosis
#' tally, then the traces themselves.
#'
#' @param result_list list of `"bronzong_result"` objects with traces attached.
#' @param file_path where to write.
#' @param summary_list the aggregate over ALL replicates -- see
#'   \code{summarise_run()}. Written into the header so a reader has the true
#'   rate beside the unrepresentative sample.
#'
#' @returns The path, invisibly.
#' @export
write_trace_file <- function(result_list, file_path, summary_list){
  stopifnot(is.list(result_list), is.list(summary_list))

  line_vec <- c(
    "# Decision traces",
    "",
    "# READ THIS FIRST. These traces are a STRATIFIED sample, deliberately",
    "# over-weighted toward misses, because misses are what a decision tree is",
    "# tuned against. They are NOT representative of the outcome distribution.",
    "# Never compute a rate from this file -- the true rates are below and come",
    "# from every replicate in the run.",
    "",
    paste0("decklist       : ", summary_list$decklist_id),
    paste0("scenario       : ", summary_list$scenario),
    paste0("going          : ", if(summary_list$bool_going_first) "first" else
      "second"),
    paste0("replicates     : ", summary_list$num_replicates),
    paste0("hit rate (t<=2): ", .fmt_pct(summary_list$hit_rate)),
    paste0("mulligan rate  : ", .fmt_pct(summary_list$mulligan_rate),
           "   mean mulligans: ",
           format(round(summary_list$mean_mulligans, 3), nsmall = 3)),
    "",
    "# Mulligans never count as a miss (ADR 0005): a hand with no Basic is",
    "# redrawn, and the redraw is what gets played. The two mulligan figures",
    "# above are ORTHOGONAL metrics, reported beside the hit rate, not folded",
    "# into it.",
    "",
    "# blocking sub-goal among misses (see docs/03_decision_tree.md section 1):",
    paste0("#   ", names(summary_list$block_tally_vec), " ",
           SUBGOAL_VEC[names(summary_list$block_tally_vec)], ": ",
           summary_list$block_tally_vec),
    paste0("# misses with an unused out still in hand: ",
           summary_list$num_unused_out,
           "  <- these are DECISION defects, not deck defects"),
    "",
    paste0("traces kept    : ", length(result_list)),
    "",
    "# ------------------------------------------------------------------")

  for(one_result in result_list){
    line_vec <- c(line_vec, "", one_result$trace_vec)
  }

  writeLines(line_vec, file_path)

  invisible(file_path)
}

#' Aggregate every replicate in one cell
#'
#' @param result_list list of `"bronzong_result"` objects, traced or not.
#'
#' @returns A list of aggregate figures, including the two orthogonal mulligan
#'   metrics and the blocking-sub-goal tally.
#' @export
summarise_run <- function(result_list){
  stopifnot(is.list(result_list), length(result_list) > 0)

  hit_vec <- sapply(result_list, function(x) x$bool_hit)
  mull_vec <- sapply(result_list, function(x) x$num_mulligans)
  block_vec <- sapply(result_list, function(x) x$blocking_subgoal)
  unused_vec <- sapply(result_list, function(x) length(x$unused_out_vec) > 0)

  block_tally_vec <- sapply(names(SUBGOAL_VEC), function(one){
    sum(block_vec == one, na.rm = TRUE)
  })

  list(decklist_id = result_list[[1]]$decklist_id,
       scenario = result_list[[1]]$scenario,
       bool_going_first = result_list[[1]]$bool_going_first,
       num_replicates = length(result_list),
       hit_rate = mean(hit_vec),
       # Orthogonal to the hit rate, never folded into it (ADR 0005).
       mulligan_rate = mean(mull_vec > 0),
       mean_mulligans = mean(mull_vec),
       max_mulligans = max(mull_vec),
       block_tally_vec = block_tally_vec,
       num_unused_out = sum(unused_vec))
}

#' Log the current hand as a trace-visible snapshot
#'
#' The hand is the input to every decision, so a trace without it shows what was
#' done but not what could have been done -- which is exactly the comparison a
#' decision tree is tuned on. The turn driver should call this immediately after
#' the draw step, and \code{setup_game()} calls it for the opening hand.
#'
#' @param state a `"bronzong_state"`.
#' @param label_str a short prefix, e.g. `"hand"`.
#'
#' @returns The updated state.
#' @export
log_hand_snapshot <- function(state, label_str = "hand"){
  stopifnot(inherits(state, "bronzong_state"))

  hand_str <- if(length(state$hand_vec) == 0) "-" else
    paste0(sort(state$hand_vec), collapse = "+")

  .log_event(state, paste0(label_str, "[", hand_str, "]"))
}

#' @export
print.bronzong_result <- function(x, ...){
  cat(paste0(x$trace_vec, collapse = "\n"), "\n")
  invisible(x)
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

#' One line per turn, semantic actions only
#' @noRd
.turn_lines <- function(state){
  keep_vec <- state$event_level_vec == 1L
  if(!any(keep_vec)) return(character(0))

  message_vec <- sub("^T[0-9-]+: ", "", state$event_log[keep_vec])
  message_vec <- .substitute_card_names(state$card_df, message_vec)
  turn_vec <- state$event_turn_vec[keep_vec]

  # "begin turn N" is structural, not an action; the turn label carries it.
  drop_vec <- grepl("^begin turn", message_vec)
  message_vec <- message_vec[!drop_vec]
  turn_vec <- turn_vec[!drop_vec]

  sapply(sort(unique(turn_vec)), function(one_turn){
    idx_vec <- which(turn_vec == one_turn)
    label_str <- if(one_turn == 0L) "  setup" else paste0("  T", one_turn, "   ")

    paste0(label_str, " ", paste0(message_vec[idx_vec], collapse = " | "))
  })
}

#' Replace card ids with short names inside free-text log messages
#'
#' The engine logs ids because they are unambiguous; a trace is read by eye and
#' by agents, for whom "attach TelepathicPsychicEnergy to Bronzong" beats
#' "attach POR-088 to TEF-069". Substituting here rather than logging names
#' keeps the engine's log canonical.
#' @noRd
.substitute_card_names <- function(card_df, message_vec){
  if(length(message_vec) == 0) return(message_vec)

  id_vec <- unique(unlist(regmatches(message_vec,
                                     gregexpr("[A-Z]{3}-[0-9]{3}", message_vec))))
  if(length(id_vec) == 0) return(message_vec)

  # Only substitute ids the database actually knows; a log line could in
  # principle contain a pattern-matching string that is not a card.
  known_vec <- id_vec[id_vec %in% c(card_df$card_id, "MEE-005")]
  if(length(known_vec) == 0) return(message_vec)

  name_vec <- .short_name(card_df, known_vec)
  for(i in seq_along(known_vec)){
    message_vec <- gsub(known_vec[i], name_vec[i], message_vec, fixed = TRUE)
  }

  message_vec
}

#' Short, readable card names for a trace
#'
#' Traces are read by eye and by agents, and "TEF-069" is worse than "Bronzong"
#' for both. Ambiguous names keep their set code, since three cards are called
#' "Bronzor".
#' @noRd
.short_name <- function(card_df, card_id_vec){
  if(length(card_id_vec) == 0) return(character(0))

  row_df <- lookup_card(card_df, card_id_vec)
  name_vec <- gsub("[^A-Za-z0-9 ]", "", row_df$name)
  name_vec <- gsub(" ", "", name_vec)

  bool_ambiguous <- name_vec %in% c("Bronzor", "PsychicEnergy")
  name_vec[bool_ambiguous] <- paste0(name_vec[bool_ambiguous], "(",
                                     substr(row_df$card_id[bool_ambiguous], 1, 3),
                                     ")")
  name_vec
}

#' Attached-energy suffix, e.g. "+P" or "+C"
#' @noRd
.energy_suffix <- function(card_df, in_play){
  if(is.null(in_play) || length(in_play$energy_vec) == 0) return("")

  provided_vec <- lookup_card(card_df, in_play$energy_vec)$energy_provided

  paste0("+", paste0(provided_vec, collapse = ""))
}

#' @noRd
.fmt_pct <- function(value_val){
  paste0(format(round(100 * value_val, 2), nsmall = 2), "%")
}
