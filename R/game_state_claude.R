# The ground-truth game state.
#
# This is what is TRUE, not what the player knows. The policy must never read
# this directly -- it reads the belief state in knowledge_claude.R instead
# (ADR 0003). Keeping the two apart is the whole reason this file exposes no
# convenience accessor for the deck's contents or ordering.
#
# Only one player is modelled. The opponent is a scenario, not a board; see
# CLAUDE.md and docs/03a_card_playbook.md.

#' Create an empty game state
#'
#' The state is created before the deck is shuffled; \code{setup_game()} in
#' setup_claude.R fills it.
#'
#' @param decklist a `"bronzong_decklist"`.
#' @param card_df the card database.
#' @param bool_going_first whether this player takes the first turn of the game.
#' @param scenario character, the opponent model; `"clear"` or `"item_lock"`.
#'
#' @returns An object of class `"bronzong_state"`: a list with
#'   \describe{
#'     \item{deck_vec}{character vector of card ids, position 1 is the top.}
#'     \item{hand_vec}{character vector of card ids.}
#'     \item{prize_vec}{character vector of 6 card ids, face down.}
#'     \item{discard_vec}{character vector of card ids.}
#'     \item{active}{an in-play record, or `NULL`.}
#'     \item{bench_list}{list of in-play records, at most 5.}
#'     \item{stadium}{card id of the Stadium in play, or `NA`.}
#'     \item{turn_number}{integer, this player's own turn count; 0 before play.}
#'     \item{bool_going_first}{logical.}
#'     \item{scenario}{character.}
#'     \item{turn_flag_list}{per-turn limits; see \code{.new_turn_flags()}.}
#'     \item{num_mulligans}{integer, how many times this player mulliganed.}
#'     \item{event_log}{character vector, appended to by every mutation.}
#'   }
#' @export
new_game_state <- function(decklist,
                           card_df,
                           bool_going_first,
                           scenario = "clear"){
  stopifnot(inherits(decklist, "bronzong_decklist"),
            is.data.frame(card_df),
            is.logical(bool_going_first), length(bool_going_first) == 1,
            scenario %in% c("clear", "item_lock"))

  structure(list(deck_vec = decklist$card_id_vec,
                 hand_vec = character(0),
                 prize_vec = character(0),
                 discard_vec = character(0),
                 active = NULL,
                 bench_list = list(),
                 stadium = NA_character_,
                 turn_number = 0L,
                 bool_going_first = bool_going_first,
                 scenario = scenario,
                 turn_flag_list = .new_turn_flags(),
                 num_mulligans = 0L,
                 card_df = card_df,
                 event_log = character(0)),
            class = "bronzong_state")
}

#' Create an in-play Pokemon record
#'
#' @param card_id the card id of the Pokemon on top of the stack.
#' @param turn_played this player's turn number when it entered play; 0 for a
#'   setup placement.
#'
#' @returns A list with `stack_vec` (bottom to top), `energy_vec`,
#'   `damage`, `turn_played`, and `turn_evolved`.
#' @export
new_in_play <- function(card_id, turn_played){
  stopifnot(is.character(card_id), length(card_id) == 1)

  list(stack_vec = canonical_card_id(card_id),
       energy_vec = character(0),
       damage = 0L,
       turn_played = as.integer(turn_played),
       turn_evolved = NA_integer_)
}

#' The card id currently on top of an in-play stack
#'
#' @param in_play an in-play record.
#'
#' @returns A single card id.
#' @export
top_card <- function(in_play){
  in_play$stack_vec[length(in_play$stack_vec)]
}

#' Every in-play record, Active first
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A list of in-play records. The Active is element 1 when present.
#' @export
all_in_play <- function(state){
  if(is.null(state$active)) return(state$bench_list)

  c(list(state$active), state$bench_list)
}

#' Fresh per-turn limit flags
#'
#' Every entry is a limit from docs/01_rules_standard.md section 4 that resets
#' at the start of each turn.
#'
#' @returns A named list of logicals.
#' @noRd
.new_turn_flags <- function(){
  list(bool_energy_attached = FALSE,
       bool_supporter_played = FALSE,
       bool_stadium_played = FALSE,
       bool_retreated = FALSE,
       bool_attacked = FALSE,
       bool_turn_over = FALSE,
       bool_run_errand_used = FALSE)
}

#' Begin this player's next turn
#'
#' Resets the per-turn flags and increments the turn counter. The
#' `turn_evolved` marks on in-play Pokemon are deliberately NOT cleared:
#' \code{can_evolve()} compares them against the current `turn_number`, so a
#' Pokemon that evolved last turn is already free to evolve again, and clearing
#' them would only discard history the event log is meant to preserve.
#'
#' Does NOT draw -- \code{draw_cards()} is called separately, because the draw
#' can lose the game (deck-out) and the caller decides how to handle that.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns The updated state.
#' @export
begin_turn <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  state$turn_number <- state$turn_number + 1L
  state$turn_flag_list <- .new_turn_flags()
  state <- .log_event(state, paste0("begin turn ", state$turn_number))

  state
}

#' Draw cards from the top of the deck
#'
#' @param state a `"bronzong_state"`.
#' @param num_cards how many to draw.
#'
#' @returns The updated state. If the deck holds fewer than `num_cards`, draws
#'   what is there and sets `state$bool_decked_out`; the caller decides what a
#'   deck-out means. In the turn-1/turn-2 window this cannot happen with a legal
#'   deck, but the flag exists so a bug shows up as a flag rather than silently
#'   drawing `NA`s.
#' @export
draw_cards <- function(state, num_cards){
  stopifnot(inherits(state, "bronzong_state"), num_cards >= 0)

  num_available <- length(state$deck_vec)
  if(num_cards > num_available){
    state$bool_decked_out <- TRUE
    num_cards <- num_available
  }
  if(num_cards == 0) return(state)

  idx_vec <- seq_len(num_cards)
  state$hand_vec <- c(state$hand_vec, state$deck_vec[idx_vec])
  state$deck_vec <- state$deck_vec[-idx_vec]

  .log_event(state, paste0("draw ", num_cards))
}

#' Shuffle the deck
#'
#' Every shuffle in the simulator goes through here, because a shuffle is also
#' the event that invalidates the player's knowledge of deck ordering
#' (ADR 0003). The belief state is updated alongside by
#' \code{knowledge_after_shuffle()}; this function touches ground truth only.
#'
#' @param state a `"bronzong_state"`.
#' @param seed_number integer seed, or `NULL` to leave the RNG stream alone.
#'
#' @returns The updated state.
#' @export
shuffle_deck <- function(state, seed_number = NULL){
  stopifnot(inherits(state, "bronzong_state"))

  if(!is.null(seed_number)) set.seed(seed_number)

  # sample() on a length-1 vector permutes seq_len(x) rather than returning x,
  # so permute positions and index, never sample the values themselves.
  num_cards <- length(state$deck_vec)
  if(num_cards > 1){
    state$deck_vec <- state$deck_vec[sample(num_cards)]
  }

  .log_event(state, "shuffle deck")
}

#' Move cards between zones
#'
#' @param state a `"bronzong_state"`.
#' @param card_id_vec the card ids to move.
#' @param from,to zone names: `"hand"`, `"deck"`, `"discard"`, `"prize"`.
#'
#' @returns The updated state. Errors if a card is not present in `from`,
#'   because a silent no-op here would create or destroy cards.
#' @export
move_cards <- function(state, card_id_vec, from, to){
  stopifnot(inherits(state, "bronzong_state"),
            from %in% c("hand", "deck", "discard", "prize"),
            to %in% c("hand", "deck", "discard", "prize"))
  if(length(card_id_vec) == 0) return(state)

  zone_field_vec <- c(hand = "hand_vec", deck = "deck_vec",
                      discard = "discard_vec", prize = "prize_vec")
  from_field <- zone_field_vec[[from]]
  to_field <- zone_field_vec[[to]]

  card_id_vec <- canonical_card_id(card_id_vec)
  source_vec <- state[[from_field]]

  # Remove one instance per requested card, not every matching card: a hand can
  # legitimately hold two copies and only one may be moving.
  for(one_id in card_id_vec){
    hit_idx <- match(one_id, source_vec)
    if(is.na(hit_idx)) stop("card ", one_id, " is not in zone '", from, "'")
    source_vec <- source_vec[-hit_idx]
  }

  state[[from_field]] <- source_vec
  state[[to_field]] <- c(state[[to_field]], card_id_vec)

  .log_event(state, paste0("move ", length(card_id_vec), " ", from, "->", to))
}

#' Count copies of a card across zones
#'
#' Ground truth, so this is for the rules engine and for scoring a finished
#' replicate -- never for the policy.
#'
#' @param state a `"bronzong_state"`.
#' @param card_id_vec card ids to count.
#'
#' @returns A named integer vector of counts in play plus hand plus deck plus
#'   discard plus prizes.
#' @export
count_copies <- function(state, card_id_vec){
  stopifnot(inherits(state, "bronzong_state"))

  card_id_vec <- canonical_card_id(card_id_vec)
  in_play_vec <- unlist(lapply(all_in_play(state), function(x) x$stack_vec))
  energy_vec <- unlist(lapply(all_in_play(state), function(x) x$energy_vec))

  everywhere_vec <- c(state$deck_vec, state$hand_vec, state$discard_vec,
                      state$prize_vec, in_play_vec, energy_vec)

  stats::setNames(sapply(card_id_vec, function(one_id) sum(everywhere_vec == one_id)),
                  card_id_vec)
}

#' Append an event to the state's log
#'
#' The log is what makes a single replicate auditable when a result looks wrong.
#' It is cheap to append to and is never read by any rule.
#'
#' @param state a `"bronzong_state"`.
#' @param message_str a one-line description.
#'
#' @returns The updated state.
#' @noRd
.log_event <- function(state, message_str){
  state$event_log <- c(state$event_log,
                       paste0("T", state$turn_number, ": ", message_str))
  state
}

#' @export
print.bronzong_state <- function(x, ...){
  cat("<bronzong_state> turn", x$turn_number,
      if(x$bool_going_first) "(going first)" else "(going second)", "\n")
  cat("  scenario:", x$scenario, "| mulligans:", x$num_mulligans, "\n")
  active_str <- if(is.null(x$active)) "none" else top_card(x$active)
  cat("  active  :", active_str, "\n")
  if(length(x$bench_list) > 0){
    cat("  bench   :",
        paste0(sapply(x$bench_list, top_card), collapse = ", "), "\n")
  }
  cat("  hand    :", length(x$hand_vec), "| deck:", length(x$deck_vec),
      "| discard:", length(x$discard_vec), "\n")
  invisible(x)
}
