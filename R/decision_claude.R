# The policy: what the player actually does (part 5).
#
# A direct translation of docs/03_decision_tree.md. Every function names the
# section it implements, so the two can be read side by side and the tree
# corrected where it is wrong -- which it will be. This is a FIRST DRAFT written
# to be reacted to, not a tuned player.
#
# The split this file must never break, from R/card_effects_claude.R's header:
# the effects answer "what happens", the rules answer "may I", and this file
# answers "should I". Nothing here re-implements a legality check; it asks.
#
# ADR 0003 governs the whole file. The policy may read the hand, the board, the
# discard, and the belief state -- never `state$deck_vec` and never
# `state$prize_vec`. Every search target is filtered through
# believes_findable(), so a search that whiffs because the card was prized is
# information the player earns rather than an outcome the policy dodged. There
# is exactly one deliberate exception, marked where it occurs.

# ---------------------------------------------------------------------------
# Card ids the tree refers to by name
# ---------------------------------------------------------------------------

#' The cards the decision tree names, by role
#'
#' Spelled out once so a policy step reads as the tree reads. Bronzor is
#' deliberately absent: three printings share the name and which ones a decklist
#' runs varies, so Bronzor is resolved by NAME at run time via
#' \code{.bronzor_ids()}.
#'
#' @export
POLICY_ID_LIST <- list(bronzong = "TEF-069",
                       salvatore = "TEF-160",
                       hilda = "WHT-084",
                       lillies = "MEG-119",
                       brocks = "JTG-146",
                       ciphermaniacs = "TEF-145",
                       surfer = "SSP-187",
                       switch_item = "MEG-130",
                       poke_pad = "POR-081",
                       poffin = "TEF-144",
                       ultra_ball = "MEG-131",
                       pokegear = "BLK-084",
                       rare_candy = "MEG-125",
                       dusknoir = "PRE-037",
                       duskull = "PRE-035",
                       latias = "SSP-076",
                       meowth = "POR-062",
                       kangaskhan = "MEG-104",
                       buneary = "PFL-083",
                       budew = "ASC-016",
                       flutter_mane = "TEF-078",
                       psychic_energy = "SVE-005",
                       telepathic = "POR-088",
                       enriching = "SSP-191")

#' Every Bronzor printing in the card database
#' @noRd
.bronzor_ids <- function(card_df){
  card_df$card_id[card_df$name == "Bronzor"]
}

#' Card ids in hand whose name matches
#' @noRd
.hand_named <- function(state, name_str){
  if(length(state$hand_vec) == 0) return(character(0))

  name_vec <- lookup_card(state$card_df, state$hand_vec)$name
  unique(state$hand_vec[name_vec %in% name_str])
}

#' Bench slots whose top card matches one of these names
#' @noRd
.bench_idx_named <- function(state, name_str){
  if(length(state$bench_list) == 0) return(integer(0))

  name_vec <- sapply(state$bench_list, function(one){
    lookup_card(state$card_df, top_card(one))$name
  })

  which(name_vec %in% name_str)
}

#' Is the Active this named Pokemon?
#' @noRd
.active_is <- function(state, name_str){
  if(is.null(state$active)) return(FALSE)

  lookup_card(state$card_df, top_card(state$active))$name %in% name_str
}

#' `[P]` sources in hand, Telepathic Psychic Energy first
#'
#' Section 4.2 step 5 prefers Telepathic when the recipient is `[P]`, because
#' the attachment then also searches two Basics. Ordering here rather than at
#' each call site keeps that preference in one place.
#' @noRd
.psychic_in_hand <- function(state){
  held_vec <- intersect(state$hand_vec, c(POLICY_ID_LIST$telepathic,
                                          POLICY_ID_LIST$psychic_energy))
  held_vec[order(match(held_vec, c(POLICY_ID_LIST$telepathic,
                                   POLICY_ID_LIST$psychic_energy)))]
}

#' The first target this card could plausibly still find
#'
#' The ADR 0003 gate every search in this file passes through. Walks an ordered
#' want-list and returns the first entry the player has reason to believe is
#' still in the deck, or `NULL` to decline -- which the trace records as
#' `DECLINED (no target named)` rather than as a whiff, since the two are
#' different defects.
#'
#' @param pair a `list(state, knowledge)`.
#' @param want_id_vec candidate targets, most wanted first.
#' @param allowed_fn what the searching card may legally fetch, from
#'   \code{ALLOWED_TARGET_LIST}. Not optional in spirit: the effects assert
#'   legality with `stopifnot()`, so naming an illegal target does not misplay,
#'   it kills the replicate. The first draft asked Poke Pad for Latias ex -- a
#'   rule-box Pokemon -- and lost a third of the seeds to it.
#'
#' @returns A single card id, or `NULL`.
#' @noRd
.first_findable <- function(pair, want_id_vec, allowed_fn = NULL){
  bool_known_vec <- want_id_vec %in% pair$state$card_df$card_id
  want_id_vec <- unique(want_id_vec[bool_known_vec])
  if(length(want_id_vec) == 0) return(NULL)

  if(!is.null(allowed_fn)){
    want_id_vec <- want_id_vec[allowed_fn(pair$state$card_df, want_id_vec)]
    if(length(want_id_vec) == 0) return(NULL)
  }

  bool_vec <- believes_findable(pair$knowledge, pair$state, want_id_vec)
  if(!any(bool_vec)) return(NULL)

  want_id_vec[which(bool_vec)[1]]
}

# ---------------------------------------------------------------------------
# Sub-goal state, as the PLAYER sees it
# ---------------------------------------------------------------------------

#' Which of the four sub-goals are already met
#'
#' Deliberately separate from \code{unmet_subgoals()} in R/trace_claude.R, which
#' is the analyst's after-the-fact diagnosis. This one is the player's view
#' during the turn, and the two would drift if one were made to serve both.
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A named logical vector `a`, `b`, `c`, `d`.
#' @noRd
.subgoal_status <- function(state){
  in_play_list <- all_in_play(state)
  bronzor_vec <- .bronzor_ids(state$card_df)

  bool_a <- any(sapply(in_play_list, function(one){
    top_card(one) %in% c(bronzor_vec, POLICY_ID_LIST$bronzong)
  }))
  bool_b <- any(sapply(in_play_list, function(one){
    top_card(one) == POLICY_ID_LIST$bronzong
  }))
  bool_c <- !is.null(state$active) &&
    top_card(state$active) == POLICY_ID_LIST$bronzong
  bool_d <- !is.null(state$active) && bool_c &&
    has_evolution_jammer_cost(state, state$active)

  c(a = isTRUE(bool_a), b = isTRUE(bool_b),
    c = isTRUE(bool_c), d = isTRUE(bool_d))
}

# ---------------------------------------------------------------------------
# Section 3 -- setup
# ---------------------------------------------------------------------------

#' Choose the opening Active, and bench nothing
#'
#' docs/03_decision_tree.md section 3. Lead a Bronzor whenever one is in hand --
#' it satisfies sub-goal C outright and costs nothing. Otherwise fall down the
#' section 3 order, which Kevin has flagged as an untested default to be settled
#' from the logs, so it is one ordered vector and nothing else.
#'
#' **Benches nothing** (Kevin, 2026-08-29). Every other Basic stays in hand,
#' where benching it later is a decision taken with information rather than a
#' placement made blind. Safe only because nothing in either scenario can Knock
#' Out our Active inside the window; see section 3.
#'
#' Signature is fixed by \code{setup_game()}'s `placement_fn` hook.
#'
#' @param state a `"bronzong_state"` holding the opening hand.
#'
#' @returns A list with `active_card_id` and an empty `bench_card_id_vec`.
#' @export
policy_placement <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  basic_vec <- state$hand_vec[is_basic_pokemon(state$card_df, state$hand_vec)]
  if(length(basic_vec) == 0) stop("no Basic Pokemon to lead")

  name_vec <- lookup_card(state$card_df, basic_vec)$name
  # Meowth ex is absent on purpose: leading it wastes Last-Ditch Catch outright,
  # so it is chosen only when it is the only Basic in hand, by the fallback.
  order_vec <- c("Bronzor", "Mega Kangaskhan ex", "Buneary", "Duskull", "Budew",
                 "Flutter Mane", "Latias ex")
  rank_vec <- match(name_vec, order_vec)
  rank_vec[is.na(rank_vec)] <- length(order_vec) + 1L

  list(active_card_id = basic_vec[which.min(rank_vec)],
       bench_card_id_vec = character(0))
}

# ---------------------------------------------------------------------------
# Section 4.4 -- what to bench
# ---------------------------------------------------------------------------

#' Bench the Pokemon that do work, and no others
#'
#' Section 4.4. The Bench is a scarce resource: five slots, one effectively
#' reserved for Latias ex, and a benched Basic can never be un-benched. So this
#' benches only the bodies that advance something.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bool_before_lillies whether Lillie's Determination will be played this
#'   turn. It shuffles the hand into the deck, so this is the one case where
#'   emptying the hand onto the Bench is right.
#'
#' @returns The updated pair.
#' @noRd
.policy_bench <- function(pair, bool_before_lillies = FALSE){
  state <- pair$state

  # Latias ex first: Skyliner is passive, and it makes the cheapest rung of the
  # section 4.3 ladder free for the rest of the game.
  if(POLICY_ID_LIST$latias %in% state$hand_vec && has_bench_space(state)){
    pair <- play_basic_to_bench(pair, POLICY_ID_LIST$latias)
  }

  # A Bronzor, when none is in play: sub-goal A's cheapest out.
  status_vec <- .subgoal_status(pair$state)
  bronzor_hand_vec <- intersect(pair$state$hand_vec,
                                .bronzor_ids(pair$state$card_df))
  if(!status_vec[["a"]] && length(bronzor_hand_vec) > 0 &&
     has_bench_space(pair$state)){
    pair <- play_basic_to_bench(pair, bronzor_hand_vec[1])
  }

  # Meowth ex only for a Supporter we want and do not hold. With Hilda already
  # in hand it would spend a slot to fetch nothing worth having.
  pair <- .policy_bench_meowth(pair)

  if(!bool_before_lillies) return(pair)

  # Ahead of Lillie's, everything else goes down rather than into the deck.
  basic_vec <- pair$state$hand_vec[is_basic_pokemon(pair$state$card_df,
                                                    pair$state$hand_vec)]
  for(one_id in basic_vec){
    if(!has_bench_space(pair$state)) break
    pair <- play_basic_to_bench(pair, one_id)
  }

  pair
}

#' Bench Meowth ex when a named Supporter is wanted and absent
#' @noRd
.policy_bench_meowth <- function(pair){
  state <- pair$state
  if(!POLICY_ID_LIST$meowth %in% state$hand_vec) return(pair)
  if(!has_bench_space(state)) return(pair)
  if(isTRUE(state$turn_flag_list$bool_last_ditch_used)) return(pair)

  # What the NEXT Supporter play wants, in section 6 order. Salvatore only while
  # a turn-1 kill could still happen; Hilda otherwise.
  want_vec <- if(!state$bool_going_first && state$turn_number == 1L){
    c(POLICY_ID_LIST$salvatore, POLICY_ID_LIST$hilda)
  } else {
    c(POLICY_ID_LIST$hilda, POLICY_ID_LIST$lillies)
  }
  want_vec <- setdiff(want_vec, state$hand_vec)
  target_id <- .first_findable(pair, want_vec)
  # No Supporter worth fetching: benching Meowth ex would spend one of five
  # Bench slots for nothing, which is what this function's own rule forbids.
  if(is.null(target_id)) return(pair)

  play_basic_to_bench(pair, POLICY_ID_LIST$meowth,
                      supporter_target_id = target_id)
}

# ---------------------------------------------------------------------------
# Section 4.3 -- getting Bronzor Active
# ---------------------------------------------------------------------------

#' Move a Bronzor or Bronzong into the Active spot
#'
#' Section 4.3's ladder, in order: free retreat under Latias ex, Switch, Surfer,
#' Buneary's Run Around, Cursed Blast. Each rung is tried only if the ones above
#' it are unavailable.
#'
#' Run Around and Cursed Blast are **not** taken here. Run Around ends the turn
#' and spends the Energy attachment (section 4.2), so it belongs last in the
#' turn; Cursed Blast needs a Dusclops or Dusknoir Active, which inside this
#' window only arises from a line the policy does not yet play. Both are marked
#' rather than silently omitted.
#'
#' @param pair a `list(state, knowledge)`.
#' @param bool_allow_surfer whether the Supporter slot may be spent on Surfer.
#'
#' @returns The updated pair.
#' @noRd
.policy_position <- function(pair, bool_allow_surfer = TRUE){
  state <- pair$state
  # Sub-goal C is a BRONZONG Active, so an Active Bronzor is not done yet: with
  # an evolved Bronzong on the Bench, promoting it is still the right move.
  # Returning on either was wrong whenever the Active Bronzor had been played
  # this turn and so could not be evolved.
  if(.active_is(state, "Bronzong")) return(pair)

  bench_idx_vec <- .bench_idx_named(state, c("Bronzor", "Bronzong"))
  if(length(bench_idx_vec) == 0) return(pair)

  top_vec <- sapply(state$bench_list[bench_idx_vec], top_card)
  bool_bronzong_vec <- top_vec == POLICY_ID_LIST$bronzong
  # An Active Bronzor is only worth replacing by a benched BRONZONG.
  if(.active_is(state, "Bronzor") && !any(bool_bronzong_vec)) return(pair)

  # Prefer an already-evolved Bronzong: promoting it meets sub-goal C outright.
  target_idx <- bench_idx_vec[order(!bool_bronzong_vec)][1]

  # Rung 1: the retreat, when Skyliner or a 0 cost makes it free. Spending a
  # Switch here would throw away a card for what the retreat does for nothing.
  if(can_retreat(state) && retreat_cost(state) == 0){
    return(retreat_active(pair, bench_idx = target_idx))
  }

  # Rung 2: Switch, an Item, so it costs no Supporter slot.
  if(POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state)){
    return(play_switch(pair, bench_idx = target_idx))
  }

  # Rung 3: Surfer, which also refills the hand. Costs the Supporter slot, so
  # the caller decides whether that slot is already spoken for.
  if(bool_allow_surfer && POLICY_ID_LIST$surfer %in% state$hand_vec &&
     can_play_supporter(state)){
    return(play_surfer(pair, bench_idx = target_idx))
  }

  pair
}

# ---------------------------------------------------------------------------
# Free Items
# ---------------------------------------------------------------------------

#' Play the free search Items, cheapest first
#'
#' Section 4.2 step 2 and section 5 steps 2-3: Poke Pad first because it costs
#' nothing, then Buddy-Buddy Poffin, then Ultra Ball only when its two-card
#' discard is affordable.
#'
#' The want-list is the sub-goal order from docs/03a_card_playbook.md, filtered
#' by what each card may legally fetch and by \code{believes_findable()}.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @noRd
.policy_search_items <- function(pair){
  if(!can_play_item(pair$state)) return(pair)

  # Both of these DISCARD themselves before searching, so playing one with no
  # target throws the card away for nothing. The first draft played them
  # unconditionally, which is where most of the demo's "a search resolved with
  # no target named" count came from -- a motif that is supposed to accuse the
  # decision tree, and was accusing this line.
  if(POLICY_ID_LIST$poke_pad %in% pair$state$hand_vec){
    # Poke Pad cannot fetch a rule-box Pokemon, so Latias ex is filtered out
    # here rather than declined later.
    target_id <- .first_findable(pair, .want_vec(pair),
                                 ALLOWED_TARGET_LIST$poke_pad)
    if(!is.null(target_id)) pair <- play_poke_pad(pair, target_id = target_id)
  }

  if(POLICY_ID_LIST$poffin %in% pair$state$hand_vec &&
     has_bench_space(pair$state)){
    # Poffin fetches up to TWO Basics of 70 HP or less, and naming only one
    # threw away half the card. It caps at 70 HP, so it can only reach the small
    # Bronzor printings.
    target_vec <- .poffin_targets(pair)
    if(length(target_vec) > 0){
      pair <- play_buddy_buddy_poffin(pair, target_id_vec = target_vec)
    }
  }

  if(POLICY_ID_LIST$ultra_ball %in% pair$state$hand_vec &&
     length(pair$state$hand_vec) >= 3){
    want_vec <- c(.want_vec(pair), POLICY_ID_LIST$latias)
    target_id <- .first_findable(pair, want_vec,
                                 ALLOWED_TARGET_LIST$ultra_ball)
    discard_vec <- .ultra_ball_discards(pair)
    if(!is.null(target_id) && !is.null(discard_vec)){
      pair <- play_ultra_ball(pair, discard_id_vec = discard_vec,
                              target_id = target_id)
    }
  }

  pair
}

#' Up to two Basics for Buddy-Buddy Poffin, bench space permitting
#' @noRd
.poffin_targets <- function(pair){
  num_space <- max(0L, BENCH_LIMIT - length(pair$state$bench_list))
  if(num_space == 0) return(character(0))

  target_vec <- character(0)
  for(one_id in .want_vec(pair)){
    if(length(target_vec) >= min(2L, num_space)) break
    found_id <- .first_findable(pair, one_id, ALLOWED_TARGET_LIST$poffin)
    if(!is.null(found_id)) target_vec <- c(target_vec, found_id)
  }

  target_vec
}

#' What a search should be looking for right now
#'
#' The ordered want-list from docs/03a_card_playbook.md, cut down to what is
#' actually missing. Sub-goal order, not card order, so the same list serves
#' every search card.
#' @noRd
.want_vec <- function(pair){
  state <- pair$state
  status_vec <- .subgoal_status(state)
  bronzor_vec <- .bronzor_ids(state$card_df)

  want_vec <- character(0)
  if(!status_vec[["a"]] && length(intersect(state$hand_vec, bronzor_vec)) == 0){
    want_vec <- c(want_vec, bronzor_vec)
  }
  if(length(.psychic_in_hand(state)) == 0){
    want_vec <- c(want_vec, POLICY_ID_LIST$telepathic,
                  POLICY_ID_LIST$psychic_energy)
  }
  if(!status_vec[["b"]] && !POLICY_ID_LIST$bronzong %in% state$hand_vec){
    want_vec <- c(want_vec, POLICY_ID_LIST$bronzong)
  }
  if(!status_vec[["c"]] && length(.bench_idx_named(state, "Latias ex")) == 0){
    want_vec <- c(want_vec, POLICY_ID_LIST$latias)
  }

  c(want_vec, POLICY_ID_LIST$duskull)
}

#' Two cards to pay Ultra Ball with, or `NULL` if there are not two to spare
#'
#' Discards the cards that advance nothing, and reaches into the useful ones
#' only when it must. Ultra Ball itself is excluded because it is being played.
#'
#' Works in **hand positions, not card ids**. The first version used
#' `setdiff()`, which silently de-duplicates: a hand holding two Bronzong
#' offered one discard where two were available, and
#' `c(spare_vec, pad_vec)[1:2]` then returned `NA`, which
#' `move_cards()` rejected with "card NA is not in zone 'hand'" a hundred
#' replicates into a run.
#' @noRd
.ultra_ball_discards <- function(pair){
  state <- pair$state
  keep_vec <- c(.bronzor_ids(state$card_df), POLICY_ID_LIST$bronzong,
                POLICY_ID_LIST$telepathic, POLICY_ID_LIST$psychic_energy,
                POLICY_ID_LIST$salvatore, POLICY_ID_LIST$hilda,
                POLICY_ID_LIST$switch_item, POLICY_ID_LIST$latias)

  # One entry per card in hand, so duplicates are counted as the two separate
  # discards they are.
  candidate_idx <- which(state$hand_vec != POLICY_ID_LIST$ultra_ball)
  if(length(candidate_idx) < 2) return(NULL)

  bool_spare_vec <- !state$hand_vec[candidate_idx] %in% keep_vec
  ordered_idx <- c(candidate_idx[bool_spare_vec],
                   candidate_idx[!bool_spare_vec])

  state$hand_vec[ordered_idx[1:2]]
}

# ---------------------------------------------------------------------------
# Section 6 -- the Supporter
# ---------------------------------------------------------------------------

#' Which Supporter to play this turn, or `NULL` for none
#'
#' The section 6 priority table, as a **decision** with no side effects. Split
#' from the play so that the answer can be asked before benching -- Lillie's
#' changes what benching should do -- and so that a card that turns out to
#' accomplish nothing can be skipped in favour of the next priority. Both were
#' bugs in the first draft: the Surfer branch returned unconditionally, dropping
#' the Supporter slot whenever Surfer had no benched target, and Ciphermaniac's
#' below it was then never reached.
#'
#' Salvatore is absent: the section 4.1 kill line owns it.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns A card id, or `NULL`.
#' @noRd
.choose_supporter <- function(pair){
  state <- pair$state
  if(!can_play_supporter(state)) return(NULL)
  status_vec <- .subgoal_status(state)

  # Priority 2 -- Hilda, but only when it can actually fetch something. With
  # Bronzong and a [P] source already in hand both of its searches resolve to
  # NULL, and playing it then spends the Supporter slot on nothing at all.
  if(POLICY_ID_LIST$hilda %in% state$hand_vec &&
     .hilda_targets(pair)$bool_any){
    return(POLICY_ID_LIST$hilda)
  }

  # Priority 3 -- Brock's Scouting, in Basics mode for a Bronzor plus Latias ex.
  if(POLICY_ID_LIST$brocks %in% state$hand_vec && !status_vec[["a"]] &&
     length(.brocks_targets(pair)) > 0){
    return(POLICY_ID_LIST$brocks)
  }

  # Priority 4 -- Lillie's Determination, on a hand that is not worth keeping.
  if(POLICY_ID_LIST$lillies %in% state$hand_vec && length(state$hand_vec) <= 4){
    return(POLICY_ID_LIST$lillies)
  }

  # Priority 5 -- Surfer, which is also rung 3 of the section 4.3 ladder. Only
  # when the cheaper rungs are unavailable, or it spends the slot to do what the
  # retreat or a Switch would have done for less.
  if(POLICY_ID_LIST$surfer %in% state$hand_vec && !status_vec[["c"]] &&
     length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) > 0 &&
     !(can_retreat(state) && retreat_cost(state) == 0) &&
     !(POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))){
    return(POLICY_ID_LIST$surfer)
  }

  # Priority 6 -- Ciphermaniac's, legal and useful in exactly one cell: going
  # second, on our own first turn (section 6). On turn 2 the draw step has
  # passed and the stacked cards are never reached.
  if(POLICY_ID_LIST$ciphermaniacs %in% state$hand_vec &&
     !state$bool_going_first && state$turn_number == 1L &&
     length(.codebreaking_stack(pair)) > 0){
    return(POLICY_ID_LIST$ciphermaniacs)
  }

  NULL
}

#' What Hilda would fetch, and whether that is anything at all
#' @noRd
.hilda_targets <- function(pair){
  state <- pair$state
  status_vec <- .subgoal_status(state)

  evo_id <- if(status_vec[["b"]] ||
               POLICY_ID_LIST$bronzong %in% state$hand_vec) NULL else
                 .first_findable(pair, POLICY_ID_LIST$bronzong,
                                 ALLOWED_TARGET_LIST$evolution)
  energy_id <- if(length(.psychic_in_hand(state)) > 0) NULL else
    .first_findable(pair, c(POLICY_ID_LIST$telepathic,
                            POLICY_ID_LIST$psychic_energy),
                    ALLOWED_TARGET_LIST$energy)

  list(evo_id = evo_id, energy_id = energy_id,
       bool_any = !is.null(evo_id) || !is.null(energy_id))
}

#' What Brock's Scouting would fetch in Basics mode
#' @noRd
.brocks_targets <- function(pair){
  c(.first_findable(pair, .bronzor_ids(pair$state$card_df),
                    ALLOWED_TARGET_LIST$basic_pokemon),
    .first_findable(pair, POLICY_ID_LIST$latias,
                    ALLOWED_TARGET_LIST$basic_pokemon))
}

#' What Ciphermaniac's would stack on top of the deck
#' @noRd
.codebreaking_stack <- function(pair){
  energy_want_vec <- c(POLICY_ID_LIST$telepathic,
                       POLICY_ID_LIST$psychic_energy)

  unlist(Filter(Negate(is.null),
                list(.first_findable(pair, POLICY_ID_LIST$bronzong),
                     .first_findable(pair, energy_want_vec))))
}

#' Play the Supporter that \code{.choose_supporter()} named
#' @noRd
.play_chosen_supporter <- function(pair, supporter_id){
  if(is.null(supporter_id)) return(pair)
  if(!can_play_supporter(pair$state)) return(pair)

  if(supporter_id == POLICY_ID_LIST$hilda){
    target_list <- .hilda_targets(pair)
    if(!target_list$bool_any) return(pair)

    return(play_hilda(pair, evolution_id = target_list$evo_id,
                      energy_id = target_list$energy_id))
  }
  if(supporter_id == POLICY_ID_LIST$brocks){
    target_vec <- .brocks_targets(pair)
    if(length(target_vec) == 0) return(pair)

    return(play_brocks_scouting(pair, mode = "basics",
                                target_id_vec = target_vec))
  }
  if(supporter_id == POLICY_ID_LIST$lillies){
    return(play_lillies_determination(pair))
  }
  if(supporter_id == POLICY_ID_LIST$surfer){
    return(.policy_position(pair, bool_allow_surfer = TRUE))
  }
  if(supporter_id == POLICY_ID_LIST$ciphermaniacs){
    stack_vec <- .codebreaking_stack(pair)
    if(length(stack_vec) == 0) return(pair)

    return(play_ciphermaniacs_codebreaking(pair, target_id_vec = stack_vec))
  }

  pair
}

# ---------------------------------------------------------------------------
# The Energy attachment
# ---------------------------------------------------------------------------

#' Attach the turn's one Energy
#'
#' Section 4.2 step 5: onto the Bronzor, so turn 2's attachment is free, and
#' preferring Telepathic Psychic Energy when the recipient is `[P]` so the
#' attachment also searches two Basics. Enriching Energy is never attached in
#' place of a `[P]` source -- it cannot pay for Evolution Jammer.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @noRd
.policy_energy <- function(pair){
  state <- pair$state
  if(!can_attach_energy(state)) return(pair)

  energy_vec <- .psychic_in_hand(state)
  if(length(energy_vec) == 0) return(pair)

  # Onto the line, wherever it is: the Energy carries through evolution.
  bool_active <- .active_is(state, c("Bronzor", "Bronzong"))
  bench_idx_vec <- .bench_idx_named(state, c("Bronzor", "Bronzong"))

  if(!bool_active && length(bench_idx_vec) == 0){
    # No Bronzor anywhere. The attachment still has a job when Telepathic
    # Psychic Energy is in hand and any [P] body is in play: its search fetches
    # two Basic [P] Pokemon onto the Bench, which is sub-goal A's out and the
    # reason the playbook lists it under A at all. Without this the policy sat
    # on a hand of two Telepathics doing nothing at all, which is what the
    # demo's first narrated turn showed.
    if(!POLICY_ID_LIST$telepathic %in% energy_vec) return(pair)
    return(.policy_telepathic_search(pair))
  }

  recipient <- if(bool_active) state$active else
    state$bench_list[[bench_idx_vec[1]]]
  energy_id <- energy_vec[1]

  # Telepathic's search fires only on a [P] recipient. On a Metal Bronzor it
  # pays sub-goal D and searches nothing, which is still worth doing -- but if a
  # plain Psychic Energy is also in hand, spend that one and keep Telepathic for
  # a body that can fire it.
  recipient_df <- lookup_card(state$card_df, top_card(recipient))
  if(energy_id == POLICY_ID_LIST$telepathic &&
     (is.na(recipient_df$ptype) || recipient_df$ptype != "psychic") &&
     POLICY_ID_LIST$psychic_energy %in% energy_vec){
    energy_id <- POLICY_ID_LIST$psychic_energy
  }

  search_vec <- character(0)
  if(energy_id == POLICY_ID_LIST$telepathic &&
     !is.na(recipient_df$ptype) && recipient_df$ptype == "psychic"){
    want_vec <- .want_vec(pair)
    num_space <- max(0L, BENCH_LIMIT - length(state$bench_list))
    for(one_id in want_vec){
      if(length(search_vec) >= min(2L, num_space)) break
      found_id <- .first_findable(pair, one_id, ALLOWED_TARGET_LIST$telepathic)
      if(!is.null(found_id)) search_vec <- c(search_vec, found_id)
    }
  }

  attach_energy(pair, energy_id,
                target_is_active = bool_active,
                bench_idx = if(bool_active) NA_integer_ else bench_idx_vec[1],
                search_id_vec = search_vec)
}

#' Spend the attachment on Telepathic's search when there is no Bronzor
#'
#' Attaches to whichever `[P]` body is in play, purely to fire the search. The
#' Energy is stranded on a body that will not attack, which is a real cost --
#' but a turn with no Bronzor in play has nothing better to spend the attachment
#' on, and the search is the cheapest route to sub-goal A.
#' @noRd
.policy_telepathic_search <- function(pair){
  state <- pair$state
  in_play_list <- all_in_play(state)
  if(length(in_play_list) == 0) return(pair)

  ptype_vec <- sapply(in_play_list, function(one){
    lookup_card(state$card_df, top_card(one))$ptype
  })
  psychic_idx <- which(!is.na(ptype_vec) & ptype_vec == "psychic")
  if(length(psychic_idx) == 0) return(pair)

  num_space <- max(0L, BENCH_LIMIT - length(state$bench_list))
  if(num_space == 0) return(pair)

  search_vec <- character(0)
  for(one_id in .want_vec(pair)){
    if(length(search_vec) >= min(2L, num_space)) break
    found_id <- .first_findable(pair, one_id, ALLOWED_TARGET_LIST$telepathic)
    if(!is.null(found_id)) search_vec <- c(search_vec, found_id)
  }
  if(length(search_vec) == 0) return(pair)

  # all_in_play() puts the Active first when there is one, so index 1 is the
  # Active and the rest map onto bench slots in order.
  bool_active <- !is.null(state$active) && psychic_idx[1] == 1L
  bench_idx <- if(bool_active) NA_integer_ else
    psychic_idx[1] - as.integer(!is.null(state$active))

  attach_energy(pair, POLICY_ID_LIST$telepathic,
                target_is_active = bool_active,
                bench_idx = bench_idx,
                search_id_vec = search_vec)
}

# ---------------------------------------------------------------------------
# Section 4.1 -- the turn-1 kill
# ---------------------------------------------------------------------------

#' Is the turn-1 Salvatore kill live?
#'
#' Section 4.1. Live when, after drawing: we went second and it is our turn 1,
#' Salvatore is in hand, a Bronzor is Active or can be made Active for free, a
#' `[P]` source is in hand, and Bronzong is not believed to be fully prized.
#'
#' The last clause is the ADR 0003 one: `is_salvatore_target()` deliberately
#' answers on public information, so a fully prized Bronzong stays
#' declarable and whiffs. The policy asks \code{believes_findable()} instead,
#' which is what the player actually knows.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns A single logical.
#' @noRd
.kill_line_is_live <- function(pair){
  state <- pair$state
  if(state$bool_going_first || state$turn_number != 1L) return(FALSE)
  if(!POLICY_ID_LIST$salvatore %in% state$hand_vec) return(FALSE)
  if(!can_play_supporter(state)) return(FALSE)
  if(length(.psychic_in_hand(state)) == 0) return(FALSE)

  # Salvatore searches the DECK. A Bronzong in hand does not help it -- and on
  # our own first turn it cannot be played from hand either, so it helps nothing
  # at all. Accepting it made the kill line "live" in precisely the case where
  # Salvatore would find nothing, and the turn then fell through to the ordinary
  # build with Items already spent in the kill ordering.
  if(!believes_findable(pair$knowledge, state, POLICY_ID_LIST$bronzong)){
    return(FALSE)
  }

  # A Bronzor must be Active, or reachable for free: Skyliner, a 0 retreat, or a
  # Switch. Surfer does not count -- it would take the slot Salvatore needs.
  if(.active_is(state, "Bronzor")) return(TRUE)
  if(length(.bench_idx_named(state, "Bronzor")) == 0) return(FALSE)

  (can_retreat(state) && retreat_cost(state) == 0) ||
    (POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))
}

#' Take the turn-1 kill
#'
#' Section 4.1, in order: free Items, position the Bronzor, Salvatore, attach,
#' attack. The Items-before-Salvatore ordering does not matter (Kevin,
#' 2026-08-29) and is kept only because the hand is more useful before Salvatore
#' has been spent.
#' @noRd
.policy_kill_line <- function(pair){
  pair <- .policy_search_items(pair)
  pair <- .policy_position(pair, bool_allow_surfer = FALSE)

  # The Items may have changed what is available; re-check rather than assume.
  if(!.active_is(pair$state, "Bronzor")) return(.policy_build_turn(pair))

  target_id <- POLICY_ID_LIST$bronzong
  if(!is_salvatore_target(pair$state, target_id)){
    return(.policy_build_turn(pair))
  }

  pair <- play_salvatore(pair, target_id = target_id, target_is_active = TRUE)
  if(!.active_is(pair$state, "Bronzong")) return(.policy_build_turn(pair))

  pair <- .policy_energy(pair)
  if(can_use_evolution_jammer(pair$state)) pair <- attack_evolution_jammer(pair)

  pair
}

# ---------------------------------------------------------------------------
# The ordinary turn
# ---------------------------------------------------------------------------

#' Build toward turn 2, or finish on turn 2
#'
#' Sections 4.2, 5 and 7, which differ less than the document's layout suggests:
#' bench, search, position, Supporter, evolve, attach, attack. Going first the
#' Supporter step is skipped by \code{can_play_supporter()} rather than by a
#' branch here.
#' @noRd
.policy_build_turn <- function(pair){
  # Asked BEFORE benching, because the answer changes what benching should do:
  # Lillie's shuffles the hand into the deck, and only then is emptying the hand
  # onto the Bench right. Asking "is Lillie's in hand?" instead filled the Bench
  # for a Lillie's that priority 4 never played, and the full Bench then
  # blocked Poffin and Telepathic's search for the rest of the window.
  supporter_id <- .choose_supporter(pair)

  pair <- .policy_bench(pair,
                        bool_before_lillies = identical(supporter_id,
                                                        POLICY_ID_LIST$lillies))
  pair <- .policy_search_items(pair)
  pair <- .policy_position(pair, bool_allow_surfer = FALSE)
  # Re-asked, because the searches may have changed the hand.
  pair <- .play_chosen_supporter(pair, .choose_supporter(pair))

  # The Supporter may have fetched the pieces, so bench and evolve afterwards --
  # and position AFTER evolving, not before. The other order left a Bronzong
  # that .policy_evolve() had just made on the Bench stranded there with a
  # Switch still in hand, which the trace then reported as a decision defect.
  pair <- .policy_bench(pair)
  pair <- .policy_evolve(pair)
  pair <- .policy_position(pair, bool_allow_surfer = TRUE)
  pair <- .policy_energy(pair)

  if(can_use_evolution_jammer(pair$state)){
    return(attack_evolution_jammer(pair))
  }

  # Section 4.2: Run Around only as a last resort, after every other play, and
  # only when it does not cost the [P] source sub-goal D needs.
  .policy_run_around(pair)
}

#' Evolve Bronzor into Bronzong
#' @noRd
.policy_evolve <- function(pair){
  state <- pair$state
  if(!POLICY_ID_LIST$bronzong %in% state$hand_vec) return(pair)

  if(.active_is(state, "Bronzor") &&
     can_evolve(state, state$active, POLICY_ID_LIST$bronzong)){
    return(evolve_pokemon(pair, POLICY_ID_LIST$bronzong,
                          target_is_active = TRUE))
  }

  # A benched Bronzor is still worth evolving: sub-goal C can be solved after.
  for(one_idx in .bench_idx_named(state, "Bronzor")){
    if(can_evolve(state, state$bench_list[[one_idx]], POLICY_ID_LIST$bronzong)){
      return(evolve_pokemon(pair, POLICY_ID_LIST$bronzong,
                            target_is_active = FALSE, bench_idx = one_idx))
    }
  }

  pair
}

#' Buneary's Run Around, as the last resort section 4.2 describes
#'
#' Costs `[C]`, i.e. the turn's Energy attachment, and the Energy then rides
#' Buneary to the Bench where it can never pay for Evolution Jammer. So: only
#' with a non-`[P]` Energy, or a spare second `[P]` source; only when sub-goal C
#' has no other out; and never on turn 2, where ending the turn ends the window.
#' @noRd
.policy_run_around <- function(pair){
  state <- pair$state
  if(state$turn_number != 1L || state$bool_going_first) return(pair)
  if(!.active_is(state, "Buneary")) return(pair)
  if(length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) == 0){
    return(pair)
  }
  if(!can_attack(state) || !can_attach_energy(state)) return(pair)

  # `.psychic_in_hand()` sorts Telepathic FIRST, which is right when attaching
  # to the line and exactly wrong here: Buneary is Colorless, so Telepathic's
  # search would not fire and the card would be stranded on the Bench for
  # nothing -- the `telepathic_on_colorless` motif, produced by the policy that
  # the motif exists to warn about. Spend the plain [P] source instead.
  psychic_vec <- rev(.psychic_in_hand(state))
  pay_id <- if(POLICY_ID_LIST$enriching %in% state$hand_vec){
    POLICY_ID_LIST$enriching
  } else if(length(psychic_vec) >= 2){
    psychic_vec[1]
  } else NULL
  if(is.null(pay_id)) return(pair)

  pair <- attach_energy(pair, pay_id, target_is_active = TRUE)
  bench_idx_vec <- .bench_idx_named(pair$state, c("Bronzor", "Bronzong"))

  attack_run_around(pair, bench_idx = bench_idx_vec[1])
}

# ---------------------------------------------------------------------------
# The public entry points
# ---------------------------------------------------------------------------

#' Play one whole turn
#'
#' The policy's top level. Chooses between the section 4.1 kill line and the
#' ordinary build, and does nothing at all once the turn is over -- which it may
#' be, since attacking ends it.
#'
#' @param pair a `list(state, knowledge)` at the start of the turn, after the
#'   draw step.
#'
#' @returns The updated pair.
#' @export
policy_turn <- function(pair){
  stopifnot(is.list(pair), inherits(pair$state, "bronzong_state"))
  if(!can_act(pair$state)) return(pair)

  if(.kill_line_is_live(pair)) return(.policy_kill_line(pair))

  .policy_build_turn(pair)
}

#' Play one replicate from setup through the end of turn 2
#'
#' The measured window (ADR 0007): setup, then two turns of draw and play, and
#' nothing after. This is the function part 6 will loop over.
#'
#' @param decklist a `"bronzong_decklist"`.
#' @param card_df the card database.
#' @param bool_going_first whether this player takes the first turn.
#' @param scenario the opponent model; `"clear"` or `"item_lock"`.
#' @param seed_number integer seed, or `NULL` to leave the RNG stream alone.
#'
#' @returns The finished `list(state, knowledge)` pair, ready for
#'   \code{summarise_replicate()}.
#' @export
play_replicate <- function(decklist,
                           card_df,
                           bool_going_first,
                           scenario = "clear",
                           seed_number = NULL){
  pair <- setup_game(decklist, card_df,
                     bool_going_first = bool_going_first,
                     placement_fn = policy_placement,
                     scenario = scenario,
                     seed_number = seed_number)

  for(one_turn in 1:2){
    # A game already lost is not played on. `begin_turn()` clears the per-turn
    # flags, so `can_act()` cannot see either loss condition -- without this a
    # decked-out or wiped-out replicate would keep playing turn 2 and could
    # still record a hit, which is a metric-level lie rather than a bad play.
    if(isTRUE(pair$state$bool_no_pokemon) ||
       isTRUE(pair$state$bool_decked_out)) break

    pair$state <- begin_turn(pair$state)
    pair <- draw_to_hand(pair, num_cards = 1L)
    pair$state <- log_hand_snapshot(pair$state, "hand")
    pair <- policy_turn(pair)
  }

  pair
}
