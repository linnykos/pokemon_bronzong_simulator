# Shared fixtures. testthat auto-sources files matching ^helper, and the local
# runner does the same, so these are available to every test file.
#
# Fixtures build positions BY HAND rather than by shuffling toward them: a test
# that has to draw its own setup is testing the RNG as much as the rule, and
# fails for the wrong reason.

.test_card_df <- function(){
  build_card_database()
}

#' A decklist read from a real file
#'
#' decklist2 is the default because it runs both Salvatore and Telepathic
#' Psychic Energy, so the turn-1 line is expressible in it.
#' @noRd
.test_decklist <- function(name_str = "decklist2"){
  read_decklist(file.path("decklists", paste0(name_str, ".txt")),
                .test_card_df())
}

#' A state with a fully controlled board, bypassing setup
#'
#' @param active_id card id for the Active, or NULL for none.
#' @param bench_id_vec card ids for the Bench.
#' @param hand_id_vec card ids to force into hand, drawn from the deck.
#' @param turn_number the player's own turn number.
#' @param bool_going_first passed through.
#' @param scenario passed through.
#' @param decklist_name which list in `decklists/` to build the deck from.
#'   decklist2 is the default and the right choice for almost everything.
#'   **decklist7 is the fixture for anything about a second printing** -- it is
#'   the only list running two Bronzor printings, two Latias ex, and a basic
#'   Darkness Energy, and several defects were invisible until a test could
#'   reach those.
#' @noRd
.make_pair <- function(active_id = "TEF-068",
                       bench_id_vec = character(0),
                       hand_id_vec = character(0),
                       turn_number = 1L,
                       bool_going_first = FALSE,
                       scenario = "clear",
                       decklist_name = "decklist2"){
  card_df <- .test_card_df()
  decklist <- .test_decklist(decklist_name)
  state <- new_game_state(decklist, card_df,
                          bool_going_first = bool_going_first,
                          scenario = scenario)

  ## Forced cards are taken off the deck, so the game's multiset is whatever
  ## .card_multiset() reports at that moment and conservation assertions stay
  ## meaningful. A card the chosen decklist does not run (Surfer, Poffin,
  ## Brock's Scouting -- all candidates not yet in any list) is pushed onto the
  ## deck first, so the fixture can exercise it without pretending the decklist
  ## contains it.
  for(one_id in hand_id_vec){
    state <- .force_into_hand(state, one_id)
  }

  if(!is.null(active_id)){
    state <- .force_into_hand(state, active_id)
    state <- move_cards(state, active_id, from = "hand", to = "discard")
    state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
    state$active <- new_in_play(active_id, turn_played = 0L)
  }
  for(one_id in bench_id_vec){
    state <- .force_into_hand(state, one_id)
    state <- move_cards(state, one_id, from = "hand", to = "discard")
    state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
    state$bench_list <- c(state$bench_list,
                          list(new_in_play(one_id, turn_played = 0L)))
  }

  state$turn_number <- as.integer(turn_number)
  ## Use the real constructor rather than a literal: a hand-written copy silently
  ## goes stale when a flag is added, and a missing flag reads as NULL, which
  ## most checks treat as permissive.
  state$turn_flag_list <- .new_turn_flags()

  list(state = state, knowledge = new_knowledge(decklist))
}

#' Put one card into the hand, adding it to the deck first if absent
#'
#' Lets a fixture exercise a candidate card that no shipped decklist runs
#' without having to invent a whole decklist for it.
#' @noRd
.force_into_hand <- function(state, card_id){
  card_id <- canonical_card_id(card_id)
  if(!card_id %in% state$deck_vec){
    state$deck_vec <- c(state$deck_vec, card_id)
  }

  move_cards(state, card_id, from = "deck", to = "hand")
}

#' Total cards across every zone
#'
#' The invariant every mutation must preserve. Counts in-play stacks and
#' attached Energy, which is where a bookkeeping slip most easily hides.
#' @noRd
.total_cards <- function(state){
  in_play_vec <- unlist(lapply(all_in_play(state), function(x) x$stack_vec))
  energy_vec <- unlist(lapply(all_in_play(state), function(x) x$energy_vec))

  length(state$deck_vec) + length(state$hand_vec) + length(state$prize_vec) +
    length(state$discard_vec) + length(in_play_vec) + length(energy_vec) +
    sum(!is.na(state$stadium))
}

#' The multiset of every card in the game, sorted
#'
#' Stronger than .total_cards(): catches a mutation that keeps the count right
#' while turning one card into another.
#' @noRd
.card_multiset <- function(state){
  in_play_vec <- unlist(lapply(all_in_play(state), function(x) x$stack_vec))
  energy_vec <- unlist(lapply(all_in_play(state), function(x) x$energy_vec))

  sort(c(state$deck_vec, state$hand_vec, state$prize_vec, state$discard_vec,
         in_play_vec, energy_vec, state$stadium[!is.na(state$stadium)]))
}

#' Run an effect only if its card is genuinely in the deck
#'
#' Returns `NULL` when the card is not available, so a sweep skips that cell
#' instead of manufacturing a position. Deliberately does NOT use
#' `.force_into_hand()`, which adds a copy to the deck when none is present:
#' that inflates the total above the decklist count and would corrupt any test
#' whose subject is the decklist arithmetic itself.
#' @noRd
.run_with <- function(card_id, pair, effect_fn){
  card_id <- canonical_card_id(card_id)
  if(!card_id %in% pair$state$deck_vec) return(NULL)

  pair$state <- move_cards(pair$state, card_id, from = "deck", to = "hand")

  effect_fn(pair)
}
