# Legality rules.
#
# This file answers "may I?", never "should I?" -- the second question belongs
# to the policy (part 5). Every rule here traces to a numbered section of
# docs/01_rules_standard.md, cited in the roxygen.
#
# The rules that bite in the measured window, and are therefore the ones worth
# testing hardest:
#   - You may not evolve on your own first turn, or a Pokemon that entered play
#     this turn -- unless Salvatore is doing the evolving (ADR 0001).
#   - The player going first may play no Supporter and may not attack.
#   - Retreating costs the retreat cost of the Pokemon LEAVING the Active spot,
#     which Latias ex's Skyliner zeroes for Basics.

#' Maximum bench size
#' @export
BENCH_LIMIT <- 5L

#' Is the turn still open?
#'
#' Rules section 4: "Your turn ends immediately after you attack." Every other
#' legality check defers to this, so an attack really does forfeit the rest of
#' the turn rather than merely preventing a second attack. Without it, the cost
#' that makes Buneary's Run Around a last-resort play in
#' docs/03_decision_tree.md section 4.2 would not exist.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_act <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  !isTRUE(state$turn_flag_list$bool_turn_over)
}

#' May this player play a Supporter right now?
#'
#' Rules section 4 (one per turn) and section 6 (the player going first may play
#' none on their first turn).
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_play_supporter <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_act(state)) return(FALSE)
  if(state$turn_flag_list$bool_supporter_played) return(FALSE)
  if(state$bool_going_first && state$turn_number == 1L) return(FALSE)

  TRUE
}

#' May this player attack right now?
#'
#' Rules section 6: the player going first may not attack on their first turn.
#' Also enforces the once-per-turn limit and the presence of an Active Pokemon.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_attack <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_act(state)) return(FALSE)
  if(is.null(state$active)) return(FALSE)
  if(state$turn_flag_list$bool_attacked) return(FALSE)
  if(state$bool_going_first && state$turn_number == 1L) return(FALSE)

  TRUE
}

#' May this player attach an Energy from hand right now?
#'
#' Rules section 4: one attachment per turn.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_attach_energy <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_act(state)) return(FALSE)

  !state$turn_flag_list$bool_energy_attached
}

#' May this player play an Item right now?
#'
#' Items are unlimited per turn, so the only thing that stops them is an
#' opposing Itchy Pollen. In the `item_lock` scenario the opponent went second
#' and attacked on their turn 1, which locks our Items for our turn 2 -- see
#' docs/03a_card_playbook.md.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_play_item <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_act(state)) return(FALSE)
  if(state$scenario != "item_lock") return(TRUE)

  # Itchy Pollen is an attack, so the opponent can only have used it if they
  # went second -- i.e. if we went first. It then lands on our turn 2.
  !(state$bool_going_first && state$turn_number == 2L)
}

#' May there be room on the bench?
#'
#' @param state a `"bronzong_state"`.
#' @param num_cards how many Pokemon are about to be benched.
#'
#' @returns A single logical.
#' @export
has_bench_space <- function(state, num_cards = 1L){
  stopifnot(inherits(state, "bronzong_state"), num_cards >= 0)

  length(state$bench_list) + num_cards <= BENCH_LIMIT
}

#' May this in-play Pokemon evolve into this card?
#'
#' Rules section 5. The `bool_via_salvatore` argument is the whole reason this
#' function takes a flag rather than being a pure state query: Salvatore
#' overrides BOTH timing restrictions (ADR 0001), so it is the one route by
#' which a turn-1 evolution is legal.
#'
#' @param state a `"bronzong_state"`.
#' @param in_play the in-play record being evolved.
#' @param evolution_card_id the card id of the Evolution card.
#' @param bool_via_salvatore whether Salvatore is performing the evolution.
#'
#' @returns A single logical.
#' @export
can_evolve <- function(state,
                       in_play,
                       evolution_card_id,
                       bool_via_salvatore = FALSE){
  stopifnot(inherits(state, "bronzong_state"), is.list(in_play))

  evolution_df <- lookup_card(state$card_df, evolution_card_id)
  base_df <- lookup_card(state$card_df, top_card(in_play))

  # The evolution must name what it sits on. Matching is by NAME, which is why
  # any of the three Bronzor printings can become Bronzong TEF 69.
  if(is.na(evolution_df$evolves_from)) return(FALSE)
  if(evolution_df$evolves_from != base_df$name) return(FALSE)

  # A Pokemon may not evolve twice in one turn, and Salvatore does not exempt
  # this -- its text covers setup and this-turn placements only.
  if(!is.na(in_play$turn_evolved) && in_play$turn_evolved == state$turn_number){
    return(FALSE)
  }

  if(bool_via_salvatore) return(TRUE)

  # Not on your own first turn, and not on a Pokemon played this turn.
  if(state$turn_number <= 1L) return(FALSE)
  if(in_play$turn_played == state$turn_number) return(FALSE)

  TRUE
}

#' Is this card a legal Salvatore target?
#'
#' Salvatore fetches "a card that has no Abilities and evolves from 1 of your
#' Pokemon". In these decklists that admits Bronzong and Mega Lopunny ex, and
#' excludes Dusclops and Dusknoir, both of which have Cursed Blast.
#'
#' @param state a `"bronzong_state"`.
#' @param card_id_vec candidate card ids.
#'
#' @returns A logical vector.
#' @export
is_salvatore_target <- function(state, card_id_vec){
  stopifnot(inherits(state, "bronzong_state"))

  row_df <- lookup_card(state$card_df, card_id_vec)
  in_play_name_vec <- sapply(all_in_play(state), function(one_in_play){
    lookup_card(state$card_df, top_card(one_in_play))$name
  })

  is_evolution_vec <- row_df$category == "pokemon" & !is.na(row_df$evolves_from)

  # Per the published ruling (docs/cards/TEF-160-salvatore.md), Salvatore may
  # not be played unless a legal target actually exists, and the game checks
  # PUBLIC zones.
  #
  # A copy is fetchable only if it is in the deck or the prizes. Subtracting
  # just the discard was not enough: an in-play copy is public and unfetchable
  # for exactly the same reason a discarded one is, and a copy in hand is one
  # the player can see too. Counting deck + prizes directly covers all three,
  # and deliberately keeps a fully PRIZED target legal to declare -- prizes are
  # not public, so the declaration is legal and simply whiffs, which is how the
  # player learns it was prized (ADR 0003).
  #
  # unname(): sapply() over a character vector returns a NAMED result, and the
  # names propagate through `&` into the return value. A named logical is not
  # identical() to a bare one, which silently breaks callers comparing against
  # TRUE/FALSE. Every predicate in this file returns bare logicals.
  num_in_deck_or_prize_vec <- unname(sapply(row_df$card_id, function(one_id){
    sum(state$deck_vec == one_id) + sum(state$prize_vec == one_id)
  }))

  unname(is_evolution_vec & !row_df$has_ability &
           row_df$evolves_from %in% in_play_name_vec &
           num_in_deck_or_prize_vec > 0)
}

#' The cost to retreat the Active Pokemon
#'
#' Costs the retreat cost of the Pokemon LEAVING the Active spot, not the one
#' being promoted. Latias ex's Skyliner zeroes it for Basic Pokemon, and on
#' turn 1 the Active is almost always a Basic, which is what makes Skyliner the
#' cheapest answer to getting Bronzor Active.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns An integer number of Energy that must be discarded, or `NA` if there
#'   is no Active Pokemon.
#' @export
retreat_cost <- function(state){
  stopifnot(inherits(state, "bronzong_state"))
  if(is.null(state$active)) return(NA_integer_)

  active_df <- lookup_card(state$card_df, top_card(state$active))
  cost_val <- active_df$retreat

  if(active_df$stage == "basic" && has_skyliner(state)) return(0L)

  as.integer(cost_val)
}

#' Is Latias ex's Skyliner active?
#'
#' Passive, works from the Bench, live the moment Latias ex is in play.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
has_skyliner <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  top_vec <- sapply(all_in_play(state), top_card)

  "SSP-076" %in% top_vec
}

#' May this player retreat right now?
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_retreat <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_act(state)) return(FALSE)
  if(state$turn_flag_list$bool_retreated) return(FALSE)
  if(is.null(state$active) || length(state$bench_list) == 0) return(FALSE)

  cost_val <- retreat_cost(state)

  length(state$active$energy_vec) >= cost_val
}

#' Does this Pokemon have the Energy to use Evolution Jammer?
#'
#' Evolution Jammer costs `[P]`, so exactly one attached Energy providing
#' Psychic is required. Enriching Energy provides `[C]` and does not count.
#'
#' @param state a `"bronzong_state"`.
#' @param in_play the in-play record to test.
#'
#' @returns A single logical.
#' @export
has_evolution_jammer_cost <- function(state, in_play){
  stopifnot(inherits(state, "bronzong_state"), is.list(in_play))
  if(length(in_play$energy_vec) == 0) return(FALSE)

  any(is_psychic_source(state$card_df, in_play$energy_vec))
}

#' Has the target event been achieved?
#'
#' The single predicate the whole project measures (docs/01_rules_standard.md
#' section 5.1). All five conditions must hold at the attack step:
#' Bronzong TEF 69 is Active, sits on a Bronzor, carries a `[P]` source, and
#' the player is allowed to attack.
#'
#' Note this asks whether the attack CAN be made now, not whether it has been.
#' The replicate records the turn on which this first returned `TRUE`.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single logical.
#' @export
can_use_evolution_jammer <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  if(!can_attack(state)) return(FALSE)
  if(is.null(state$active)) return(FALSE)
  if(top_card(state$active) != "TEF-069") return(FALSE)

  has_evolution_jammer_cost(state, state$active)
}

#' Require a whole-number index or count
#'
#' R's `[[` truncates a double index, so `bench_idx = 1.9` silently targets slot
#' 1 and a policy computing an index arithmetically hits the wrong Pokemon with
#' no error. Range guards alone do not catch it, because 1.9 is genuinely
#' between 1 and the bench size.
#'
#' @param value_val the value to check.
#' @param name_str the argument name, for the error message.
#' @param min_val the smallest admissible value.
#' @param max_val the largest admissible value, or `NA` for unbounded.
#'
#' @returns `invisible(TRUE)`; errors if the value is not a whole number in
#'   range.
#' @export
check_whole_number <- function(value_val, name_str, min_val = 1L,
                               max_val = NA_integer_){
  if(length(value_val) != 1 || is.na(value_val) || !is.numeric(value_val)){
    stop("`", name_str, "` must be a single number")
  }
  if(value_val != as.integer(value_val)){
    stop("`", name_str, "` must be a whole number; got ", value_val)
  }
  if(value_val < min_val){
    stop("`", name_str, "` must be at least ", min_val, "; got ", value_val)
  }
  if(!is.na(max_val) && value_val > max_val){
    stop("`", name_str, "` must be at most ", max_val, "; got ", value_val)
  }

  invisible(TRUE)
}
