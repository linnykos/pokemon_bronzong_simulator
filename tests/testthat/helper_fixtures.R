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
#' @noRd
.make_pair <- function(active_id = "TEF-068",
                       bench_id_vec = character(0),
                       hand_id_vec = character(0),
                       turn_number = 1L,
                       bool_going_first = FALSE,
                       scenario = "clear"){
  card_df <- .test_card_df()
  decklist <- .test_decklist()
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
  state$turn_flag_list <- list(bool_energy_attached = FALSE,
                               bool_supporter_played = FALSE,
                               bool_stadium_played = FALSE,
                               bool_retreated = FALSE,
                               bool_attacked = FALSE)

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
    length(state$discard_vec) + length(in_play_vec) + length(energy_vec)
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
         in_play_vec, energy_vec))
}
