# Game setup: shuffle, mulligans, opening placement, prizes.
#
# Follows docs/01_rules_standard.md section 3 in order. The ordering there is
# not cosmetic: prizes are set aside AFTER the opening hand is drawn and the
# Basics are placed, so the prized cards are drawn from what is left. Setting
# prizes first would change which cards can be prized and quietly bias every
# result.

#' Deal an opening hand, mulliganing until it holds a Basic
#'
#' Rules section 3, steps 3 and 4. A hand with no Basic Pokemon is revealed,
#' shuffled back, and redrawn. The opponent's entitlement to a bonus card per
#' mulligan is recorded but not modelled -- only one player is simulated.
#'
#' @param state a `"bronzong_state"`.
#' @param max_mulligans a safety valve. A legal deck with at least one Basic
#'   terminates with probability 1, so hitting this bound means a bug, not bad
#'   luck, and it is treated as an error.
#' @param seed_number integer seed, or `NULL` to leave the RNG stream alone.
#' @param verbose numeric verbosity; 0 is silent.
#'
#' @returns The updated state, with `hand_vec` of length 7 and `num_mulligans`
#'   set.
#' @export
deal_opening_hand <- function(state,
                              max_mulligans = 100L,
                              seed_number = NULL,
                              verbose = 0){
  stopifnot(inherits(state, "bronzong_state"), max_mulligans >= 1)

  if(!is.null(seed_number)) set.seed(seed_number)

  num_mulligans <- 0L
  repeat {
    # Everything returns to the deck before each redraw, so the shuffle is over
    # the full 60 every time.
    state$deck_vec <- c(state$deck_vec, state$hand_vec)
    state$hand_vec <- character(0)
    state <- shuffle_deck(state, seed_number = NULL)
    state <- draw_cards(state, num_cards = 7L)

    if(any(is_basic_pokemon(state$card_df, state$hand_vec))) break

    num_mulligans <- num_mulligans + 1L
    if(num_mulligans >= max_mulligans){
      stop("exceeded ", max_mulligans, " mulligans; the deck almost certainly ",
           "contains no Basic Pokemon, which validate_decklist() should have ",
           "caught")
    }
  }

  state$num_mulligans <- num_mulligans
  if(verbose > 0 && num_mulligans > 0){
    print(paste0("Mulliganed ", num_mulligans, " time(s)"))
  }

  .log_event(state, paste0("opening hand after ", num_mulligans, " mulligan(s)"))
}

#' Place the Active and Bench from the opening hand
#'
#' Rules section 3, steps 5 and 6. Only Basic Pokemon may be placed, at most one
#' Active and five Benched.
#'
#' The choice of which Basic leads is a POLICY decision, not a rule, so it is
#' passed in rather than decided here -- see docs/03_decision_tree.md section 3.
#' This function only enforces legality.
#'
#' @param state a `"bronzong_state"`.
#' @param active_card_id the Basic to place as the Active.
#' @param bench_card_id_vec Basics to place on the Bench; may be empty.
#'
#' @returns The updated state.
#' @export
place_opening_pokemon <- function(state,
                                  active_card_id,
                                  bench_card_id_vec = character(0)){
  stopifnot(inherits(state, "bronzong_state"),
            is.character(active_card_id), length(active_card_id) == 1,
            is.character(bench_card_id_vec))

  place_vec <- c(active_card_id, bench_card_id_vec)
  if(!all(is_basic_pokemon(state$card_df, place_vec))){
    stop("only Basic Pokemon may be placed during setup; got ",
         paste0(place_vec[!is_basic_pokemon(state$card_df, place_vec)],
                collapse = ", "))
  }
  if(length(bench_card_id_vec) > BENCH_LIMIT){
    stop("cannot bench ", length(bench_card_id_vec), " Pokemon; the limit is ",
         BENCH_LIMIT)
  }

  state <- move_cards(state, place_vec, from = "hand", to = "discard")
  # move_cards() is the only way to leave the hand, so the placement round-trips
  # through the discard and is immediately undone here. Doing it this way keeps
  # a single code path for "leaves the hand" and so a single place to get the
  # multiset bookkeeping wrong.
  state$discard_vec <- state$discard_vec[
    -seq(to = length(state$discard_vec), length.out = length(place_vec))]

  state$active <- new_in_play(active_card_id, turn_played = 0L)
  state$bench_list <- lapply(bench_card_id_vec, function(one_id){
    new_in_play(one_id, turn_played = 0L)
  })

  .log_event(state, paste0("place ", active_card_id, " active, ",
                           length(bench_card_id_vec), " benched"))
}

#' Set aside the six Prize cards
#'
#' Rules section 3, step 7. Taken off the top of what remains after the opening
#' hand and placements, without being looked at.
#'
#' This is where a simulator most easily cheats. The prizes are stored in the
#' ground-truth state and are never exposed to the policy; the only legitimate
#' route to prize knowledge is the deduction in
#' \code{knowledge_after_search()}.
#'
#' @param state a `"bronzong_state"`.
#' @param num_prizes how many prizes to set aside.
#'
#' @returns The updated state.
#' @export
set_prizes <- function(state, num_prizes = 6L){
  stopifnot(inherits(state, "bronzong_state"), num_prizes >= 0)

  if(length(state$deck_vec) < num_prizes){
    stop("deck holds ", length(state$deck_vec), " cards; cannot set aside ",
         num_prizes, " prizes")
  }

  # `deck_vec[-integer(0)]` returns an EMPTY vector, not the deck, so a request
  # for zero prizes would silently destroy the whole deck. Return early rather
  # than relying on the negative index to be a no-op.
  if(num_prizes == 0) return(state)

  idx_vec <- seq_len(num_prizes)
  state$prize_vec <- state$deck_vec[idx_vec]
  state$deck_vec <- state$deck_vec[-idx_vec]

  .log_event(state, paste0("set ", num_prizes, " prizes"))
}

#' Run a full game setup
#'
#' Convenience wrapper performing rules section 3 end to end, given a callback
#' that makes the opening placement decision.
#'
#' @param decklist a `"bronzong_decklist"`.
#' @param card_df the card database.
#' @param bool_going_first whether this player takes the first turn.
#' @param placement_fn a function of `(state)` returning a list with elements
#'   `active_card_id` and `bench_card_id_vec`. Part 5 supplies the real policy;
#'   the default here is deliberately naive and exists so the engine can be
#'   exercised before the policy is written.
#' @param scenario the opponent model; `"clear"` or `"item_lock"`.
#' @param seed_number integer seed, or `NULL` to leave the RNG stream alone.
#' @param verbose numeric verbosity; 0 is silent.
#'
#' @returns A list with `state` (a `"bronzong_state"`) and `knowledge` (a
#'   `"bronzong_knowledge"`), ready for turn 1.
#' @export
setup_game <- function(decklist,
                       card_df,
                       bool_going_first,
                       placement_fn = .default_placement,
                       scenario = "clear",
                       seed_number = NULL,
                       verbose = 0){
  stopifnot(inherits(decklist, "bronzong_decklist"), is.function(placement_fn))

  state <- new_game_state(decklist = decklist,
                          card_df = card_df,
                          bool_going_first = bool_going_first,
                          scenario = scenario)

  state <- deal_opening_hand(state, seed_number = seed_number,
                             verbose = verbose - 1)

  placement_list <- placement_fn(state)
  stopifnot(is.list(placement_list),
            all(c("active_card_id", "bench_card_id_vec") %in%
                  names(placement_list)))

  state <- place_opening_pokemon(
    state,
    active_card_id = placement_list$active_card_id,
    bench_card_id_vec = placement_list$bench_card_id_vec)

  state <- set_prizes(state)

  # The belief state starts knowing only the decklist. It does NOT know the
  # prizes just set aside, which is the point of ADR 0003.
  knowledge <- new_knowledge(decklist)

  if(verbose > 0){
    print(paste0("Setup complete: ", length(state$hand_vec), " in hand, ",
                 length(state$deck_vec), " in deck"))
  }

  list(state = state, knowledge = knowledge)
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

#' A deliberately naive opening placement
#'
#' Leads a Bronzor when one is in hand -- which docs/03_decision_tree.md section
#' 3 argues is usually right -- and otherwise leads the first Basic available,
#' benching the rest. This is a placeholder so the engine is runnable before
#' part 5 exists; it is NOT the policy and makes no claim to be good.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A list with `active_card_id` and `bench_card_id_vec`.
#' @noRd
.default_placement <- function(state){
  basic_vec <- state$hand_vec[is_basic_pokemon(state$card_df, state$hand_vec)]
  stopifnot(length(basic_vec) > 0)

  name_vec <- lookup_card(state$card_df, basic_vec)$name
  bronzor_idx <- which(name_vec == "Bronzor")
  active_idx <- if(length(bronzor_idx) > 0) bronzor_idx[1] else 1L

  bench_vec <- basic_vec[-active_idx]
  if(length(bench_vec) > BENCH_LIMIT) bench_vec <- bench_vec[seq_len(BENCH_LIMIT)]

  list(active_card_id = basic_vec[active_idx],
       bench_card_id_vec = bench_vec)
}
