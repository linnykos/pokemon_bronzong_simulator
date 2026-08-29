# What each card does when played.
#
# One function per card that can advance a sub-goal, per docs/03a_card_playbook.md.
# Each takes and returns a `list(state, knowledge)` pair, because almost every
# effect touches both: playing a search card changes the board AND teaches the
# player what is in their deck.
#
# These functions answer "what happens", never "should I". Search TARGETS are
# passed in by the caller (the policy, part 5); the effects here only enforce
# what each card is legally allowed to fetch. That split is what lets the policy
# be rewritten without touching the rules.
#
# Cards that are inert for turns 1-2 -- Boss's Orders, Special Red Card, Night
# Stretcher, the Stadiums, Rare Candy -- have no function here on purpose. They
# are playable and change nothing that the metric reads.

# ---------------------------------------------------------------------------
# Primitives shared by many cards
# ---------------------------------------------------------------------------

#' Bench a Pokemon from hand
#'
#' Triggers Meowth ex's Last-Ditch Catch, which fires only on being played from
#' hand onto the Bench -- never from a setup placement and never as the Active.
#'
#' @param pair a `list(state, knowledge)`.
#' @param card_id the Basic Pokemon to bench.
#' @param supporter_target_id for a Meowth ex trigger, the Supporter to search
#'   for; `NULL` declines the Ability.
#'
#' @returns The updated pair.
#' @export
play_basic_to_bench <- function(pair, card_id, supporter_target_id = NULL){
  state <- pair$state
  stopifnot(is_basic_pokemon(state$card_df, card_id))
  if(!has_bench_space(state)) stop("bench is full")

  state <- move_cards(state, card_id, from = "hand", to = "discard")
  state$discard_vec <- state$discard_vec[-length(state$discard_vec)]

  state$bench_list <- c(state$bench_list,
                        list(new_in_play(card_id,
                                         turn_played = state$turn_number)))
  state <- .log_event(state, paste0("bench ", card_id))
  pair$state <- state

  if(canonical_card_id(card_id) == "POR-062" && !is.null(supporter_target_id)){
    pair <- .search_deck_to_hand(pair,
                                 target_id_vec = supporter_target_id,
                                 allowed_fn = .is_supporter,
                                 label = "Last-Ditch Catch")
  }

  pair
}

#' Attach an Energy card from hand
#'
#' Consumes the turn's single attachment. Fires Telepathic Psychic Energy's and
#' Enriching Energy's on-attach effects.
#'
#' @param pair a `list(state, knowledge)`.
#' @param card_id the Energy card.
#' @param target_is_active whether to attach to the Active rather than a Bench
#'   slot.
#' @param bench_idx which Bench slot, when `target_is_active` is `FALSE`.
#' @param search_id_vec for Telepathic Psychic Energy, up to 2 Basic `[P]`
#'   Pokemon to fetch to the Bench.
#'
#' @returns The updated pair.
#' @export
attach_energy <- function(pair,
                          card_id,
                          target_is_active = TRUE,
                          bench_idx = NA_integer_,
                          search_id_vec = character(0)){
  state <- pair$state
  if(!can_attach_energy(state)) stop("already attached an Energy this turn")

  energy_df <- lookup_card(state$card_df, card_id)
  stopifnot(energy_df$category == "energy")

  state <- move_cards(state, card_id, from = "hand", to = "discard")
  state$discard_vec <- state$discard_vec[-length(state$discard_vec)]

  card_id <- canonical_card_id(card_id)
  if(target_is_active){
    if(is.null(state$active)) stop("no Active Pokemon to attach to")
    state$active$energy_vec <- c(state$active$energy_vec, card_id)
    recipient_id <- top_card(state$active)
  } else {
    stopifnot(!is.na(bench_idx), bench_idx <= length(state$bench_list))
    state$bench_list[[bench_idx]]$energy_vec <-
      c(state$bench_list[[bench_idx]]$energy_vec, card_id)
    recipient_id <- top_card(state$bench_list[[bench_idx]])
  }

  state$turn_flag_list$bool_energy_attached <- TRUE
  state <- .log_event(state, paste0("attach ", card_id, " to ", recipient_id))
  pair$state <- state

  if(card_id == "POR-088"){
    pair <- .telepathic_psychic_trigger(pair, recipient_id, search_id_vec)
  }
  if(card_id == "SSP-191"){
    pair <- draw_to_hand(pair, num_cards = 4L)
  }

  pair
}

#' Draw cards, keeping the belief state in step
#'
#' Always use this rather than \code{draw_cards()} directly: drawing consumes
#' any known top-of-deck stack, and forgetting that is how a Ciphermaniac's
#' Codebreaking stack would wrongly appear to deliver both cards.
#'
#' @param pair a `list(state, knowledge)`.
#' @param num_cards how many to draw.
#'
#' @returns The updated pair.
#' @export
draw_to_hand <- function(pair, num_cards){
  pair$state <- draw_cards(pair$state, num_cards = num_cards)
  pair$knowledge <- knowledge_after_draw(pair$knowledge, num_cards = num_cards)

  pair
}

#' Evolve an in-play Pokemon from hand
#'
#' @param pair a `list(state, knowledge)`.
#' @param evolution_card_id the Evolution card in hand.
#' @param target_is_active whether the target is the Active.
#' @param bench_idx which Bench slot, when `target_is_active` is `FALSE`.
#'
#' @returns The updated pair.
#' @export
evolve_pokemon <- function(pair,
                           evolution_card_id,
                           target_is_active = TRUE,
                           bench_idx = NA_integer_){
  state <- pair$state
  target <- if(target_is_active) state$active else state$bench_list[[bench_idx]]

  if(!can_evolve(state, target, evolution_card_id)){
    stop("illegal evolution: ", evolution_card_id, " onto ", top_card(target))
  }

  state <- move_cards(state, evolution_card_id, from = "hand", to = "discard")
  state$discard_vec <- state$discard_vec[-length(state$discard_vec)]

  pair$state <- .apply_evolution(state, evolution_card_id, target_is_active,
                                 bench_idx)
  pair
}

# ---------------------------------------------------------------------------
# Search Items
# ---------------------------------------------------------------------------

#' Poke Pad: search for one Pokemon without a Rule Box
#'
#' Cannot find Latias ex, Meowth ex, or either Mega ex.
#'
#' @param pair a `list(state, knowledge)`.
#' @param target_id the card to fetch, or `NULL` to play it as a whiff.
#'
#' @returns The updated pair.
#' @export
play_poke_pad <- function(pair, target_id = NULL){
  pair <- .discard_from_hand(pair, "POR-081")

  .search_deck_to_hand(pair,
                       target_id_vec = target_id,
                       allowed_fn = function(card_df, card_id_vec){
                         row_df <- lookup_card(card_df, card_id_vec)
                         row_df$category == "pokemon" & !row_df$has_rule_box
                       },
                       label = "Poke Pad")
}

#' Ultra Ball: discard 2, then search for any Pokemon
#'
#' The discard is a real cost and the caller chooses what to pay it with; see
#' the discard priority in docs/03a_card_playbook.md. Ultra Ball is the only
#' Item that can find Latias ex.
#'
#' @param pair a `list(state, knowledge)`.
#' @param discard_id_vec exactly 2 card ids from hand, not counting Ultra Ball.
#' @param target_id the Pokemon to fetch, or `NULL` for a whiff.
#'
#' @returns The updated pair.
#' @export
play_ultra_ball <- function(pair, discard_id_vec, target_id = NULL){
  stopifnot(length(discard_id_vec) == 2)

  pair <- .discard_from_hand(pair, "MEG-131")
  pair$state <- move_cards(pair$state, discard_id_vec,
                           from = "hand", to = "discard")

  .search_deck_to_hand(pair,
                       target_id_vec = target_id,
                       allowed_fn = function(card_df, card_id_vec){
                         lookup_card(card_df, card_id_vec)$category == "pokemon"
                       },
                       label = "Ultra Ball")
}

#' Buddy-Buddy Poffin: up to 2 Basics with 70 HP or less, onto the Bench
#'
#' The HP cap is why Bronzor TEF 68 (80 HP) is unreachable and the Metal
#' printings (70 and 60) are candidates.
#'
#' @param pair a `list(state, knowledge)`.
#' @param target_id_vec up to 2 card ids to fetch.
#'
#' @returns The updated pair.
#' @export
play_buddy_buddy_poffin <- function(pair, target_id_vec = character(0)){
  stopifnot(length(target_id_vec) <= 2)

  pair <- .discard_from_hand(pair, "TEF-144")

  .search_deck_to_bench(pair,
                        target_id_vec = target_id_vec,
                        allowed_fn = function(card_df, card_id_vec){
                          row_df <- lookup_card(card_df, card_id_vec)
                          row_df$category == "pokemon" &
                            row_df$stage == "basic" &
                            !is.na(row_df$hp) & row_df$hp <= 70
                        },
                        label = "Buddy-Buddy Poffin")
}

#' Pokegear 3.0: look at the top 7, take one Supporter
#'
#' Not a tutor. It sees only 7 cards and can whiff, and it shuffles the rest
#' back -- which destroys any Ciphermaniac's stack, so the policy must not play
#' it while one is pending.
#'
#' @param pair a `list(state, knowledge)`.
#' @param preference_id_vec Supporters to prefer, best first. The first one
#'   present in the top 7 is taken.
#'
#' @returns The updated pair.
#' @export
play_pokegear <- function(pair, preference_id_vec = character(0)){
  pair <- .discard_from_hand(pair, "BLK-084")
  state <- pair$state

  num_look <- min(7L, length(state$deck_vec))
  look_vec <- state$deck_vec[seq_len(num_look)]
  is_supporter_vec <- .is_supporter(state$card_df, look_vec)

  taken_id <- NA_character_
  if(any(is_supporter_vec)){
    candidate_vec <- look_vec[is_supporter_vec]
    hit_idx <- match(preference_id_vec, candidate_vec)
    hit_idx <- hit_idx[!is.na(hit_idx)]
    taken_id <- if(length(hit_idx) > 0) candidate_vec[hit_idx[1]] else candidate_vec[1]

    state <- move_cards(state, taken_id, from = "deck", to = "hand")
  }

  # Pokegear shows the player only these 7 cards, not the whole deck, so it does
  # NOT set bool_deck_seen -- it teaches nothing about what is prized.
  state <- shuffle_deck(state)
  state <- .log_event(state, paste0("Pokegear 3.0 -> ",
                                    if(is.na(taken_id)) "whiff" else taken_id))

  pair$state <- state
  pair$knowledge <- knowledge_after_shuffle(pair$knowledge)
  pair$knowledge$seen_vec <- union(pair$knowledge$seen_vec, look_vec)

  pair
}

# ---------------------------------------------------------------------------
# Supporters
# ---------------------------------------------------------------------------

#' Hilda: one Evolution Pokemon and one Energy card, to hand
#'
#' The most efficient Supporter for this deck: it resolves sub-goals B and D
#' together.
#'
#' @param pair a `list(state, knowledge)`.
#' @param evolution_id the Evolution Pokemon to fetch.
#' @param energy_id the Energy card to fetch.
#'
#' @returns The updated pair.
#' @export
play_hilda <- function(pair, evolution_id = NULL, energy_id = NULL){
  pair <- .play_supporter_from_hand(pair, "WHT-084")

  pair <- .search_deck_to_hand(
    pair, target_id_vec = evolution_id,
    allowed_fn = function(card_df, card_id_vec){
      row_df <- lookup_card(card_df, card_id_vec)
      row_df$category == "pokemon" & !is.na(row_df$evolves_from)
    },
    label = "Hilda (evolution)", bool_shuffle = FALSE)

  .search_deck_to_hand(
    pair, target_id_vec = energy_id,
    allowed_fn = function(card_df, card_id_vec){
      lookup_card(card_df, card_id_vec)$category == "energy"
    },
    label = "Hilda (energy)")
}

#' Salvatore: fetch an Ability-less Evolution and put it straight onto its base
#'
#' The only route to a turn-1 evolution (ADR 0001). Legal targets in these
#' decklists are Bronzong and Mega Lopunny ex; Dusclops and Dusknoir have
#' Cursed Blast and are excluded.
#'
#' @param pair a `list(state, knowledge)`.
#' @param target_id the Evolution card to fetch.
#' @param target_is_active whether it evolves the Active.
#' @param bench_idx which Bench slot, when `target_is_active` is `FALSE`.
#'
#' @returns The updated pair. If the target is not in the deck the Supporter is
#'   still spent and the search whiffs -- which is information.
#' @export
play_salvatore <- function(pair,
                           target_id,
                           target_is_active = TRUE,
                           bench_idx = NA_integer_){
  state <- pair$state
  if(!is_salvatore_target(state, target_id)){
    stop("illegal Salvatore target: ", target_id)
  }

  target <- if(target_is_active) state$active else state$bench_list[[bench_idx]]
  if(!can_evolve(state, target, target_id, bool_via_salvatore = TRUE)){
    stop("Salvatore cannot evolve ", top_card(target), " into ", target_id)
  }

  pair <- .play_supporter_from_hand(pair, "TEF-160")
  state <- pair$state

  bool_found <- canonical_card_id(target_id) %in% state$deck_vec
  if(bool_found){
    state <- move_cards(state, target_id, from = "deck", to = "discard")
    state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
    state <- .apply_evolution(state, target_id, target_is_active, bench_idx)
  }

  state <- shuffle_deck(state)
  state <- .log_event(state, paste0("Salvatore -> ",
                                    if(bool_found) target_id else "whiff"))

  pair$state <- state
  pair$knowledge <- knowledge_after_search(pair$knowledge, state)
  pair$knowledge <- knowledge_after_shuffle(pair$knowledge)

  pair
}

#' Brock's Scouting: up to 2 Basics OR exactly 1 Evolution, to hand
#'
#' The two modes are exclusive. It is the only free way to find Latias ex.
#'
#' @param pair a `list(state, knowledge)`.
#' @param mode `"basics"` or `"evolution"`.
#' @param target_id_vec the cards to fetch; at most 2 in `"basics"` mode and at
#'   most 1 in `"evolution"` mode.
#'
#' @returns The updated pair.
#' @export
play_brocks_scouting <- function(pair, mode, target_id_vec){
  stopifnot(mode %in% c("basics", "evolution"))
  if(mode == "basics") stopifnot(length(target_id_vec) <= 2)
  if(mode == "evolution") stopifnot(length(target_id_vec) <= 1)

  pair <- .play_supporter_from_hand(pair, "JTG-146")

  allowed_fn <- if(mode == "basics"){
    function(card_df, card_id_vec){
      row_df <- lookup_card(card_df, card_id_vec)
      row_df$category == "pokemon" & row_df$stage == "basic"
    }
  } else {
    function(card_df, card_id_vec){
      row_df <- lookup_card(card_df, card_id_vec)
      row_df$category == "pokemon" & !is.na(row_df$evolves_from)
    }
  }

  .search_deck_to_hand(pair, target_id_vec = target_id_vec,
                       allowed_fn = allowed_fn,
                       label = paste0("Brock's Scouting (", mode, ")"))
}

#' Lillie's Determination: shuffle the hand away, then draw 6, or 8 on 6 prizes
#'
#' Draws 8 throughout the measured window, since no Prize has been taken. The
#' hand is shuffled in FIRST, so anything the player wanted to keep must have
#' been played before this.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @export
play_lillies_determination <- function(pair){
  pair <- .play_supporter_from_hand(pair, "MEG-119")
  state <- pair$state

  num_draw <- if(length(state$prize_vec) == 6L) 8L else 6L

  state <- move_cards(state, state$hand_vec, from = "hand", to = "deck")
  state <- shuffle_deck(state)
  pair$state <- state
  pair$knowledge <- knowledge_after_shuffle(pair$knowledge)

  pair <- draw_to_hand(pair, num_cards = num_draw)
  pair$state <- .log_event(pair$state,
                           paste0("Lillie's Determination, drew ", num_draw))

  pair
}

#' Surfer: switch, then draw up to a hand of 5
#'
#' The draw is `max(0, 5 - hand_size)` computed AFTER the switch and after
#' Surfer has left the hand, so on a full hand it draws nothing and is a worse
#' Switch. It also costs the Supporter slot, which is why it loses to Switch
#' whenever a Supporter is wanted for anything else.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bench_idx the Bench slot to promote.
#'
#' @returns The updated pair.
#' @export
play_surfer <- function(pair, bench_idx){
  pair <- .play_supporter_from_hand(pair, "SSP-187")
  state <- pair$state

  if(length(state$bench_list) == 0){
    # "If you do" -- with an empty Bench there is no switch and so no draw.
    pair$state <- .log_event(state, "Surfer with empty bench, no effect")
    return(pair)
  }

  pair$state <- .swap_active(state, bench_idx)
  num_draw <- max(0L, 5L - length(pair$state$hand_vec))

  pair <- draw_to_hand(pair, num_cards = num_draw)
  pair$state <- .log_event(pair$state, paste0("Surfer, drew ", num_draw))

  pair
}

#' Ciphermaniac's Codebreaking: search 2 cards onto the top of the deck
#'
#' Shuffles first, then places, so the stack survives only until the next
#' shuffle. The following turn's draw step takes exactly ONE of the two.
#'
#' @param pair a `list(state, knowledge)`.
#' @param target_id_vec up to 2 card ids, the first ending up on top.
#'
#' @returns The updated pair.
#' @export
play_ciphermaniacs_codebreaking <- function(pair, target_id_vec){
  stopifnot(length(target_id_vec) <= 2)

  pair <- .play_supporter_from_hand(pair, "TEF-145")
  state <- pair$state

  found_vec <- character(0)
  for(one_id in canonical_card_id(target_id_vec)){
    if(one_id %in% state$deck_vec){
      state <- move_cards(state, one_id, from = "deck", to = "discard")
      state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
      found_vec <- c(found_vec, one_id)
    }
  }

  state <- shuffle_deck(state)
  state$deck_vec <- c(found_vec, state$deck_vec)
  state <- .log_event(state, paste0("Codebreaking stacked ",
                                    paste0(found_vec, collapse = ", ")))

  pair$state <- state
  pair$knowledge <- knowledge_after_search(pair$knowledge, state)
  pair$knowledge <- knowledge_after_shuffle(pair$knowledge)
  pair$knowledge <- knowledge_after_stacking(pair$knowledge, found_vec)

  pair
}

# ---------------------------------------------------------------------------
# Positioning
# ---------------------------------------------------------------------------

#' Switch: swap the Active with a Benched Pokemon
#'
#' Costs no Energy, does not use the turn's retreat, and does not touch the
#' Supporter slot -- which is what makes it the preferred answer to getting
#' Bronzor Active.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bench_idx the Bench slot to promote.
#'
#' @returns The updated pair.
#' @export
play_switch <- function(pair, bench_idx){
  pair <- .discard_from_hand(pair, "MEG-130")
  pair$state <- .swap_active(pair$state, bench_idx)

  pair
}

#' Retreat the Active Pokemon
#'
#' Discards Energy equal to the retreat cost of the Pokemon LEAVING the Active
#' spot. Free for a Basic while Latias ex's Skyliner is in play.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bench_idx the Bench slot to promote.
#'
#' @returns The updated pair.
#' @export
retreat_active <- function(pair, bench_idx){
  state <- pair$state
  if(!can_retreat(state)) stop("cannot retreat right now")

  cost_val <- retreat_cost(state)
  if(cost_val > 0){
    paid_vec <- state$active$energy_vec[seq_len(cost_val)]
    state$active$energy_vec <- state$active$energy_vec[-seq_len(cost_val)]
    state$discard_vec <- c(state$discard_vec, paid_vec)
  }

  state$turn_flag_list$bool_retreated <- TRUE
  pair$state <- .swap_active(state, bench_idx)

  pair
}

#' Buneary's Run Around: switch, at the cost of the turn
#'
#' An attack, so it ends the turn and is unavailable to the player going first
#' on turn 1. Take it only when nothing else remains.
#'
#' Run Around costs `[C]`, which any single attached Energy pays. That cost is
#' easy to overlook because the attack deals no damage and reads like an
#' Ability, but without it this would be a free switch on every going-second
#' replicate -- and sub-goal C, the one the decision tree argues actually fails,
#' would look far cheaper than it is.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bench_idx the Bench slot to promote.
#'
#' @returns The updated pair.
#' @export
attack_run_around <- function(pair, bench_idx){
  state <- pair$state
  if(!can_attack(state)) stop("cannot attack right now")
  if(top_card(state$active) != "PFL-083") stop("Run Around needs Buneary Active")
  if(length(state$active$energy_vec) < 1){
    stop("Run Around costs [C]; Buneary has no Energy attached")
  }

  state$turn_flag_list$bool_attacked <- TRUE
  state$turn_flag_list$bool_turn_over <- TRUE
  state <- .swap_active(state, bench_idx)
  pair$state <- .log_event(state, "Run Around")

  pair
}

#' Budew's Itchy Pollen: lock the opponent's Items, at the cost of the turn
#'
#' Costs no Energy and deals 10. Because it is an attack it cannot be used by
#' the player going first on turn 1 -- which is why the `item_lock` scenario
#' only exists against an opponent who went second.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @export
attack_itchy_pollen <- function(pair){
  state <- pair$state
  if(!can_attack(state)) stop("cannot attack right now")
  if(top_card(state$active) != "ASC-016"){
    stop("Itchy Pollen needs Budew Active")
  }

  state$turn_flag_list$bool_attacked <- TRUE
  state$turn_flag_list$bool_turn_over <- TRUE
  pair$state <- .log_event(state, "Itchy Pollen")

  pair
}

#' Mega Kangaskhan ex's Run Errand: draw 2 while Active
#'
#' "Once during your turn ... You can't use more than 1 Run Errand Ability each
#' turn."
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @export
use_run_errand <- function(pair){
  state <- pair$state
  if(is.null(state$active) || top_card(state$active) != "MEG-104"){
    stop("Run Errand needs Mega Kangaskhan ex Active")
  }
  if(isTRUE(state$turn_flag_list$bool_run_errand_used)){
    stop("Run Errand may only be used once per turn")
  }
  if(!can_act(state)) stop("the turn is over")

  pair$state$turn_flag_list$bool_run_errand_used <- TRUE
  pair <- draw_to_hand(pair, num_cards = 2L)
  pair$state <- .log_event(pair$state, "Run Errand")

  pair
}

#' Play a Stadium
#'
#' Once per turn, and only if it does not share a name with the Stadium already
#' in play. None of the four Stadiums in these decklists affects the target
#' event, but playing one is a legal action the decision tree lists, so it must
#' be expressible.
#'
#' @param pair a `list(state, knowledge)`.
#' @param card_id the Stadium in hand.
#'
#' @returns The updated pair.
#' @export
play_stadium <- function(pair, card_id){
  state <- pair$state
  if(!can_act(state)) stop("the turn is over")
  if(state$turn_flag_list$bool_stadium_played){
    stop("already played a Stadium this turn")
  }

  stadium_df <- lookup_card(state$card_df, card_id)
  if(is.na(stadium_df$subtype) || stadium_df$subtype != "stadium"){
    stop(card_id, " is not a Stadium")
  }
  if(!is.na(state$stadium)){
    in_play_df <- lookup_card(state$card_df, state$stadium)
    if(in_play_df$name == stadium_df$name){
      stop("a Stadium with the same name is already in play")
    }
    state$discard_vec <- c(state$discard_vec, state$stadium)
  }

  state <- move_cards(state, card_id, from = "hand", to = "discard")
  state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
  state$stadium <- canonical_card_id(card_id)
  state$turn_flag_list$bool_stadium_played <- TRUE

  pair$state <- .log_event(state, paste0("play Stadium ", card_id))

  pair
}

#' Attack with Evolution Jammer
#'
#' The target event. Ends the turn.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @export
attack_evolution_jammer <- function(pair){
  state <- pair$state
  if(!can_use_evolution_jammer(state)) stop("Evolution Jammer is not available")

  state$turn_flag_list$bool_attacked <- TRUE
  state$turn_flag_list$bool_turn_over <- TRUE
  pair$state <- .log_event(state, "EVOLUTION JAMMER")

  pair
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

#' Is each card a Supporter?
#' @noRd
.is_supporter <- function(card_df, card_id_vec){
  row_df <- lookup_card(card_df, card_id_vec)

  row_df$category == "trainer" & !is.na(row_df$subtype) &
    row_df$subtype == "supporter"
}

#' Discard a Trainer from hand as the cost of playing it
#' @noRd
.discard_from_hand <- function(pair, card_id){
  if(!can_play_item(pair$state)){
    stop("Items are locked this turn (Itchy Pollen)")
  }
  pair$state <- move_cards(pair$state, card_id, from = "hand", to = "discard")

  pair
}

#' Spend the turn's Supporter and discard the card
#' @noRd
.play_supporter_from_hand <- function(pair, card_id){
  if(!can_play_supporter(pair$state)){
    stop("cannot play a Supporter right now (", card_id, ")")
  }
  pair$state <- move_cards(pair$state, card_id, from = "hand", to = "discard")
  pair$state$turn_flag_list$bool_supporter_played <- TRUE

  pair
}

#' Resolve a deck search that puts cards into the hand
#'
#' Enforces what the card may legally fetch, moves what is actually there, and
#' updates the belief state: seeing the deck teaches the player its contents,
#' and the subsequent shuffle destroys ordering knowledge.
#'
#' @noRd
.search_deck_to_hand <- function(pair,
                                 target_id_vec,
                                 allowed_fn,
                                 label,
                                 bool_shuffle = TRUE){
  state <- pair$state
  target_id_vec <- canonical_card_id(as.character(target_id_vec))

  found_vec <- character(0)
  if(length(target_id_vec) > 0){
    stopifnot(all(allowed_fn(state$card_df, target_id_vec)))
    for(one_id in target_id_vec){
      if(one_id %in% state$deck_vec){
        state <- move_cards(state, one_id, from = "deck", to = "hand")
        found_vec <- c(found_vec, one_id)
      }
    }
  }

  state <- .log_event(state, paste0(label, " -> ",
                                    if(length(found_vec) == 0) "whiff"
                                    else paste0(found_vec, collapse = ", ")))
  pair$state <- state
  pair$knowledge <- knowledge_after_search(pair$knowledge, state)

  if(bool_shuffle){
    pair$state <- shuffle_deck(pair$state)
    pair$knowledge <- knowledge_after_shuffle(pair$knowledge)
  }

  pair
}

#' Resolve a deck search that puts Pokemon directly onto the Bench
#' @noRd
.search_deck_to_bench <- function(pair, target_id_vec, allowed_fn, label){
  state <- pair$state
  target_id_vec <- canonical_card_id(as.character(target_id_vec))

  found_vec <- character(0)
  if(length(target_id_vec) > 0){
    stopifnot(all(allowed_fn(state$card_df, target_id_vec)))
    for(one_id in target_id_vec){
      if(one_id %in% state$deck_vec && has_bench_space(state)){
        state <- move_cards(state, one_id, from = "deck", to = "discard")
        state$discard_vec <- state$discard_vec[-length(state$discard_vec)]
        state$bench_list <- c(state$bench_list,
                              list(new_in_play(one_id,
                                               turn_played = state$turn_number)))
        found_vec <- c(found_vec, one_id)
      }
    }
  }

  state <- .log_event(state, paste0(label, " -> ",
                                    if(length(found_vec) == 0) "whiff"
                                    else paste0(found_vec, collapse = ", ")))
  pair$state <- shuffle_deck(state)
  pair$knowledge <- knowledge_after_search(pair$knowledge, pair$state)
  pair$knowledge <- knowledge_after_shuffle(pair$knowledge)

  pair
}

#' Telepathic Psychic Energy's attach trigger
#'
#' Fires only when the RECIPIENT is a `[P]` Pokemon, so attaching to a Metal
#' Bronzor pays the cost but searches nothing; attaching to the evolved
#' Bronzong does fire it.
#'
#' @noRd
.telepathic_psychic_trigger <- function(pair, recipient_id, search_id_vec){
  recipient_df <- lookup_card(pair$state$card_df, recipient_id)
  if(is.na(recipient_df$ptype) || recipient_df$ptype != "psychic"){
    pair$state <- .log_event(pair$state,
                             "Telepathic Psychic: recipient not [P], no search")
    return(pair)
  }
  stopifnot(length(search_id_vec) <= 2)

  .search_deck_to_bench(pair, target_id_vec = search_id_vec,
                        allowed_fn = function(card_df, card_id_vec){
                          row_df <- lookup_card(card_df, card_id_vec)
                          row_df$category == "pokemon" &
                            row_df$stage == "basic" &
                            !is.na(row_df$ptype) & row_df$ptype == "psychic"
                        },
                        label = "Telepathic Psychic Energy")
}

#' Put an Evolution card onto an in-play Pokemon
#'
#' Attached Energy and damage stay; Special Conditions would be removed, but
#' none are modelled in the measured window.
#'
#' @noRd
.apply_evolution <- function(state, evolution_card_id, target_is_active,
                             bench_idx){
  evolution_card_id <- canonical_card_id(evolution_card_id)

  if(target_is_active){
    state$active$stack_vec <- c(state$active$stack_vec, evolution_card_id)
    state$active$turn_evolved <- state$turn_number
  } else {
    state$bench_list[[bench_idx]]$stack_vec <-
      c(state$bench_list[[bench_idx]]$stack_vec, evolution_card_id)
    state$bench_list[[bench_idx]]$turn_evolved <- state$turn_number
  }

  .log_event(state, paste0("evolve into ", evolution_card_id))
}

#' Swap the Active with a Bench slot, preserving both records intact
#' @noRd
.swap_active <- function(state, bench_idx){
  stopifnot(bench_idx >= 1, bench_idx <= length(state$bench_list))

  promoted <- state$bench_list[[bench_idx]]
  state$bench_list[[bench_idx]] <- state$active
  state$active <- promoted

  .log_event(state, paste0("promote ", top_card(promoted)))
}
