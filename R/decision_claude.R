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
# WHERE EACH SECTION LIVES. Kept current so that editing the document tells you
# what to change here, and so a divergence is findable rather than discovered:
#
#   section 3   the lead, and benching nothing   policy_placement()
#   section 4.1 the turn-1 Salvatore kill        .kill_line_is_live()
#                                                .policy_kill_line()
#   section 4.2 the turn-1 build, Run Around     .policy_build_turn()
#                                                .policy_run_around()
#   section 4.3 the positioning ladder           .policy_position()
#               rung 5, the Cursed Blast escape  .policy_cursed_blast_escape()
#   section 4.4 what to bench, and when          .policy_bench()
#   section 5   going first                      .policy_build_turn(), which
#                                                branches on can_play_supporter
#                                                rather than on the coin flip
#   section 6   the Supporter priority table     .choose_supporter()
#                                                .play_chosen_supporter()
#               priority 2, Salvatore on turn 2  .salvatore_beats_hilda()
#               priority 6, Ciphermaniac's gate  .missing_bcd_vec()
#               priority 8, the fallback         .fallback_supporter()
#   section 7   turn 2                           .policy_build_turn()
#   section 8   Cursed Blast escape              .policy_cursed_blast_escape()
#   03a         the want-list, per-card rules    .want_vec(), and the
#                                                .*_targets() helpers
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

#' Is a `[P]` source already secured for sub-goal D?
#'
#' Secured means in hand OR already attached to a Bronzor/Bronzong in play. The
#' distinction matters in three places that all read the same way once it is
#' named: section 4.2 step 6 declines the attachment, section 6 priority 2 ranks
#' Salvatore over Hilda, and the Ciphermaniac's gate counts D as met.
#' @noRd
.psychic_secured <- function(state){
  if(length(.psychic_in_hand(state)) > 0) return(TRUE)

  line_list <- c(if(.active_is(state, c("Bronzor", "Bronzong"))){
    list(state$active)
  },
  state$bench_list[.bench_idx_named(state, c("Bronzor", "Bronzong"))])

  any(sapply(line_list, function(one){
    .has_psychic_attached(state, one)
  }))
}

#' Does this in-play Pokemon already carry a `[P]` source?
#' @noRd
.has_psychic_attached <- function(state, in_play){
  if(is.null(in_play) || length(in_play$energy_vec) == 0) return(FALSE)

  any(in_play$energy_vec %in% c(POLICY_ID_LIST$telepathic,
                                POLICY_ID_LIST$psychic_energy))
}

#' Can sub-goal C be paid this turn without spending the Supporter slot?
#'
#' The section 4.3 ladder's free rungs only: the line is already Active, or a
#' free retreat or a Switch can move it. Surfer and Run Around are excluded
#' deliberately -- both cost a resource this predicate's callers are trying to
#' protect.
#' @noRd
.c_is_free <- function(state){
  if(.active_is(state, c("Bronzor", "Bronzong"))) return(TRUE)
  if(length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) == 0){
    return(FALSE)
  }

  (can_retreat(state) && retreat_cost(state) == 0) ||
    (POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))
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
  #
  # Buneary's case is Run Around, an ATTACK -- so going first, where we may not
  # attack on turn 1, section 3 says "the option does not exist at all". It
  # drops below the bodies that at least get out of the way cheaply.
  order_vec <- if(state$bool_going_first){
    c("Bronzor", "Mega Kangaskhan ex", "Duskull", "Budew", "Buneary",
      "Flutter Mane", "Latias ex")
  } else {
    c("Bronzor", "Mega Kangaskhan ex", "Buneary", "Duskull", "Budew",
      "Flutter Mane", "Latias ex")
  }
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

#' Could a Salvatore fetched right now actually be cashed this turn?
#'
#' docs/03a_card_playbook.md -> Meowth ex. Salvatore solves sub-goal B and
#' nothing else, so it converts only where C is already free and D is already
#' secured -- and only on `P2T1`, since its evolution-timing bypass is what it
#' is being fetched for.
#' @noRd
.salvatore_is_cashable <- function(pair){
  state <- pair$state
  if(state$bool_going_first || state$turn_number != 1L) return(FALSE)

  .psychic_secured(state) && .c_is_free(state)
}

#' Bench Meowth ex when a named Supporter is wanted and absent
#' @noRd
.policy_bench_meowth <- function(pair){
  state <- pair$state
  if(!POLICY_ID_LIST$meowth %in% state$hand_vec) return(pair)
  if(!has_bench_space(state)) return(pair)
  if(isTRUE(state$turn_flag_list$bool_last_ditch_used)) return(pair)

  # What the NEXT Supporter play wants. Salvatore fixes sub-goal B alone, so it
  # is worth fetching only where the turn can actually cash it: `P2T1`, with
  # sub-goal C already free and a [P] source already secured. Fetched into any
  # weaker hand it is a card the turn cannot use, which is the single most
  # common way a `P2T1` Meowth ex is wasted -- Hilda fixes B *and* D, and
  # Lillie's replaces the hand, so both convert far more often.
  want_vec <- if(.salvatore_is_cashable(pair)){
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

  # Rung 4 is Buneary's Run Around, which is NOT taken here: it ends the turn
  # and spends the Energy attachment, so section 4.2 puts it after every other
  # play and .policy_run_around() owns it.
  #
  # Rung 5: the Cursed Blast escape, the last door.
  .policy_cursed_blast_escape(pair, target_idx)
}

#' Rung 5 of the section 4.3 ladder: Knock our own Active out to promote
#'
#' Section 8. Cursed Blast reads "if you use this Ability, this Pokemon is
#' Knocked Out", and the player whose Pokemon was Knocked Out chooses the
#' replacement Active -- so it is a switching effect costing no Switch, no
#' Supporter slot, no retreat and no Energy. It costs the Pokemon, and a Prize
#' from the OPPONENT's pile, which is why Lillie's still draws 8 afterwards.
#'
#' Taken on either branch and whatever the score, because the alternative once
#' the ladder has got this far is a turn that cannot attack at all.
#'
#' Two routes, in cost order:
#' \itemize{
#'   \item a Dusclops or Dusknoir Active uses its own Ability -- no card spent;
#'   \item a Duskull Active needs **Rare Candy** to reach a Dusknoir first, since
#'     Rare Candy goes Basic to Stage 2 and Dusknoir evolves from Dusclops.
#' }
#'
#' @param pair a `list(state, knowledge)`.
#' @param target_idx the Bench slot to promote, from the caller's own choice.
#'
#' @returns The updated pair, unchanged when neither route is available.
#' @noRd
.policy_cursed_blast_escape <- function(pair, target_idx){
  state <- pair$state
  if(!can_act(state)) return(pair)
  # use_cursed_blast() refuses an empty Bench because rules section 8 loses the
  # game on the spot. Nothing should ever ask, so the guard is here too: with
  # one Bench Pokemon the promotion is the target itself and the Bench survives.
  if(length(state$bench_list) == 0) return(pair)

  if(.active_is(state, c("Dusclops", "Dusknoir"))){
    return(use_cursed_blast(pair, promote_idx = target_idx))
  }

  # The Duskull route. Rare Candy is an Item, so Itchy Pollen closes this door
  # on the turn it matters most.
  if(!.active_is(state, "Duskull")) return(pair)
  if(!can_play_item(state)) return(pair)
  if(!POLICY_ID_LIST$rare_candy %in% state$hand_vec) return(pair)
  if(!POLICY_ID_LIST$dusknoir %in% state$hand_vec) return(pair)
  if(!can_rare_candy(state, state$active, POLICY_ID_LIST$dusknoir)){
    return(pair)
  }

  pair <- play_rare_candy(pair, stage2_card_id = POLICY_ID_LIST$dusknoir,
                          target_is_active = TRUE)

  use_cursed_blast(pair, promote_idx = target_idx)
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
  # Section 7 step 1: free Items first, "but NOT anything that shuffles if a
  # Ciphermaniac's stack is pending and undrawn". Every search Item below
  # shuffles, so the whole step is skipped rather than filtered.
  if(.stack_is_pending(pair)) return(pair)

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

#' Is a Ciphermaniac's stack sitting on top of the deck, undrawn?
#'
#' Sections 5 and 7 forbid playing a shuffling card while one is, and
#' `docs/03a_card_playbook.md` states it as a flag every shuffling card must
#' check. The belief state already tracks it: `top_known_vec` is emptied by
#' \code{knowledge_after_shuffle()} and consumed one card at a time by
#' \code{knowledge_after_draw()}.
#'
#' **What the guard is actually worth, which is less than it looks.**
#' Ciphermaniac's is legal only on `P2T1` (section 6), it stacks two, and turn
#' 2's draw step takes the first. The second is reachable inside the measured
#' window only through a **draw effect** -- Run Errand, or Enriching Energy's
#' draw 4. Absent one of those it is a card the window can never see, and
#' protecting it costs a search. Worth knowing before section 7 is rewritten.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns A single logical.
#' @noRd
.stack_is_pending <- function(pair){
  length(pair$knowledge$top_known_vec) > 0
}

#' Up to two Basics for Buddy-Buddy Poffin, bench space permitting
#' @noRd
.poffin_targets <- function(pair){
  num_space <- max(0L, BENCH_LIMIT - length(pair$state$bench_list))
  if(num_space == 0) return(character(0))

  target_vec <- character(0)
  for(one_id in .want_vec(pair, bool_to_hand = FALSE)){
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
.want_vec <- function(pair, bool_to_hand = TRUE){
  state <- pair$state
  status_vec <- .subgoal_status(state)
  bronzor_vec <- .bronzor_ids(state$card_df)

  want_vec <- character(0)
  if(!status_vec[["a"]] && length(intersect(state$hand_vec, bronzor_vec)) == 0){
    want_vec <- c(want_vec, bronzor_vec)
  }
  # Item 2 reads "none in hand and none ATTACHED": once the line carries a [P]
  # source, sub-goal D is paid and a second Energy is a card the window cannot
  # spend.
  if(!.psychic_secured(state)){
    want_vec <- c(want_vec, POLICY_ID_LIST$telepathic,
                  POLICY_ID_LIST$psychic_energy)
  }
  if(!status_vec[["b"]] && !POLICY_ID_LIST$bronzong %in% state$hand_vec){
    want_vec <- c(want_vec, POLICY_ID_LIST$bronzong)
  }
  if(!status_vec[["c"]] && length(.bench_idx_named(state, "Latias ex")) == 0){
    want_vec <- c(want_vec, POLICY_ID_LIST$latias)
  }
  # Items 6-7 of the playbook's want-list. A SECOND Bronzor is deliberately
  # absent: it insures against a Knock Out this window cannot produce, and it
  # cost 1.4 points where it used to sit here.
  #
  # Meowth ex is conditioned on `bool_to_hand`, which Poffin and Telepathic pass
  # as FALSE. They put Basics on the BENCH, and Last-Ditch Catch fires only on
  # being played from hand -- so a Meowth ex fetched their way spends a Bench
  # slot and triggers nothing.
  if(bool_to_hand && !POLICY_ID_LIST$meowth %in% state$hand_vec &&
     length(.bench_idx_named(state, "Meowth ex")) == 0){
    want_vec <- c(want_vec, POLICY_ID_LIST$meowth)
  }
  want_vec <- c(want_vec, POLICY_ID_LIST$duskull)

  # When sub-goal C is what is actually blocking -- the line is in play, on the
  # Bench, and neither a free retreat nor a Switch can move it -- Latias ex
  # stops being a nice-to-have and becomes the missing piece, so it goes FIRST
  # (Kevin, 2026-08-29). Only Ultra Ball and Brock's Scouting can fetch it; Poke
  # Pad cannot, because Latias ex has a Rule Box, which is why Poke Pad ends up
  # being the card that finds Bronzong.
  if(.c_is_blocked(pair)) want_vec <- c(POLICY_ID_LIST$latias, want_vec)

  want_vec
}

#' Is sub-goal C the thing standing in the way, with no out in hand?
#'
#' The condition that promotes Latias ex up the want-list. About POSITIONING and
#' nothing else, and **prospective**: a Bronzor still in hand counts as the
#' line, because it will be benched this turn and by then every search that
#' could have found the mover is spent. Reading it as "already benched" is a
#' turn too late and is how a Bronzor ends up stranded with the Ultra Ball that
#' would have found Latias ex already gone.
#' @noRd
.c_is_blocked <- function(pair){
  state <- pair$state
  if(.subgoal_status(state)[["c"]]) return(FALSE)
  # An Active Bronzor is one evolution from C, so positioning is not what is
  # wrong even though sub-goal C -- a Bronzong Active -- is not yet met.
  if(.active_is(state, c("Bronzor", "Bronzong"))) return(FALSE)

  bool_line <- length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) > 0 ||
    length(intersect(state$hand_vec, .bronzor_ids(state$card_df))) > 0
  if(!bool_line) return(FALSE)

  if(length(.bench_idx_named(state, "Latias ex")) > 0) return(FALSE)
  if(can_retreat(state) && retreat_cost(state) == 0) return(FALSE)

  !(POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))
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
  # One entry per card in hand, so two copies are the two separate discards they
  # are -- matching on ids would collapse them and pad the pair with NA.
  candidate_idx <- which(state$hand_vec != POLICY_ID_LIST$ultra_ball)
  if(length(candidate_idx) < 2) return(NULL)

  keep_idx <- .ultra_ball_keep_idx(pair, candidate_idx)
  candidate_idx <- setdiff(candidate_idx, keep_idx)
  # "If fewer than 2 discardable cards remain by that rule, Ultra Ball is
  # unplayable" -- the playbook's words, so declining is correct rather than
  # reaching into the protected cards.
  if(length(candidate_idx) < 2) return(NULL)

  rank_vec <- match(state$hand_vec[candidate_idx], .ULTRA_BALL_ORDER_VEC)
  rank_vec[is.na(rank_vec)] <- length(.ULTRA_BALL_ORDER_VEC) + 1L

  state$hand_vec[candidate_idx[order(rank_vec)][1:2]]
}

#' The playbook's Ultra Ball discard order, first listed goes first
#'
#' Transcribed rather than improved on: `docs/03a_card_playbook.md` owns the
#' order and PB-05 is still open on whether it is right.
#'
#' Night Stretcher (ASC 196) and Ciphermaniac's (TEF 145) sit third and fourth,
#' ahead of Rare Candy, the Stadiums and Dusknoir: they are the cards this
#' window most reliably cannot convert. A Ciphermaniac's that IS this turn's
#' Supporter is protected by \code{.ultra_ball_keep_idx()} instead, so its rank
#' here only ever applies to a copy that will not be played.
#' @noRd
.ULTRA_BALL_ORDER_VEC <- c("CRI-082", "MEG-114", "ASC-196", "TEF-145",
                           "PRE-035", "PRE-036", "PRE-037", "MEG-125",
                           "ASC-197", "TWM-153", "TWM-149", "MEG-122",
                           "TEF-078", "TEF-069")

#' Hand positions Ultra Ball may not discard
#'
#' The playbook's never-discard list, which is about the LAST copy of each: a
#' surplus Bronzong is discardable, the only one is not. Counted positionally so
#' "the only" is checked rather than assumed.
#' @noRd
.ultra_ball_keep_idx <- function(pair, candidate_idx){
  state <- pair$state
  single_vec <- c(POLICY_ID_LIST$telepathic, POLICY_ID_LIST$psychic_energy,
                  .bronzor_ids(state$card_df), POLICY_ID_LIST$bronzong)
  # The only Switch, but only while it is the answer to sub-goal C.
  if(length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) > 0){
    single_vec <- c(single_vec, POLICY_ID_LIST$switch_item)
  }
  # Salvatore, on a turn where the kill is still live -- and, generally, THIS
  # turn's Supporter whichever card it is. A Supporter about to be played is not
  # spare: discarding it trades the whole Supporter slot for one search.
  if(.kill_line_is_live(pair)){
    single_vec <- c(single_vec, POLICY_ID_LIST$salvatore)
  }
  chosen_id <- .choose_supporter(pair)
  if(!is.null(chosen_id)) single_vec <- c(single_vec, chosen_id)

  keep_idx <- integer(0)
  for(one_id in unique(single_vec)){
    hit_idx <- candidate_idx[state$hand_vec[candidate_idx] == one_id]
    # One copy only: the rest are surplus and may be spent.
    if(length(hit_idx) > 0) keep_idx <- c(keep_idx, hit_idx[1])
  }

  unique(keep_idx)
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
.choose_supporter <- function(pair, bool_fallback = TRUE){
  state <- pair$state
  if(!can_play_supporter(state)) return(NULL)
  status_vec <- .subgoal_status(state)

  # Priority 2 -- Salvatore on turn 2, ranked against Hilda rather than confined
  # to turn 1. It fetches Bronzong AND puts it on the Bronzor in one card.
  if(.salvatore_beats_hilda(pair)) return(POLICY_ID_LIST$salvatore)

  # Priority 3 -- Hilda, but only when a search of hers advances something. A
  # fetch that duplicates a card already held spends the slot for no sub-goal,
  # so she yields to the next priority; the fallback below can still reach her.
  if(POLICY_ID_LIST$hilda %in% state$hand_vec &&
     .hilda_targets(pair)$bool_worth_slot){
    return(POLICY_ID_LIST$hilda)
  }

  # Priority 4 -- Brock's Scouting, in Basics mode for a Bronzor plus Latias ex.
  # Also when sub-goal C is blocked, even with A already met: Brock's is one of
  # only two cards that can fetch the Latias ex that unblocks it.
  if(POLICY_ID_LIST$brocks %in% state$hand_vec &&
     (!status_vec[["a"]] || .c_is_blocked(pair)) &&
     length(.brocks_targets(pair)) > 0){
    return(POLICY_ID_LIST$brocks)
  }
  # ...and in Evolution mode for Bronzong, but only once Hilda is gone, since
  # Hilda fetches the Bronzong AND an Energy for the same slot (section 6).
  if(POLICY_ID_LIST$brocks %in% state$hand_vec &&
     !is.null(.brocks_evolution_target(pair))){
    return(POLICY_ID_LIST$brocks)
  }

  # Priority 5 -- Surfer, which is also rung 3 of the section 4.3 ladder. Only
  # when the cheaper rungs are unavailable, or it spends the slot to do what the
  # retreat or a Switch would have done for less. Ahead of Lillie's because it
  # solves a sub-goal outright where Lillie's only replaces the hand.
  if(POLICY_ID_LIST$surfer %in% state$hand_vec && !status_vec[["c"]] &&
     length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) > 0 &&
     !(can_retreat(state) && retreat_cost(state) == 0) &&
     !(POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))){
    return(POLICY_ID_LIST$surfer)
  }

  # Priority 6 -- Ciphermaniac's, legal and useful in exactly one cell: going
  # second, on our own first turn (section 6). On turn 2 the draw step has
  # passed and the stacked cards are never reached.
  #
  # And gated on what it can SOLVE rather than on the cell alone: turn 2 draws
  # exactly one of the two stacked cards, so it is worth the slot only when one
  # card finishes the job -- sub-goal A met and exactly one of B, C and D still
  # missing. Missing three, Lillie's replaces the whole hand and is the better
  # card.
  if(POLICY_ID_LIST$ciphermaniacs %in% state$hand_vec &&
     !state$bool_going_first && state$turn_number == 1L &&
     status_vec[["a"]] && length(.missing_bcd_vec(pair)) == 1L &&
     length(.codebreaking_stack(pair)) > 0){
    return(POLICY_ID_LIST$ciphermaniacs)
  }

  # Priority 7 -- Lillie's Determination, on a hand that is not worth keeping.
  if(POLICY_ID_LIST$lillies %in% state$hand_vec && length(state$hand_vec) <= 4){
    return(POLICY_ID_LIST$lillies)
  }

  # Priority 8 -- the fallback. One Supporter may be played per turn and an
  # unplayed one carries no credit into the next, so a slot left idle is a
  # resource destroyed rather than saved.
  #
  # `bool_fallback = FALSE` is what .policy_build_turn() passes for the
  # MID-turn Supporter play. The fallback runs at the end of the turn instead,
  # because none of its cards is fetching a piece the turn still needs and
  # Lillie's would otherwise shuffle the hand away underneath the evolution and
  # the attachment.
  if(!bool_fallback) return(NULL)

  .fallback_supporter(pair)
}

#' Which of sub-goals B, C and D this turn cannot currently pay
#'
#' The Ciphermaniac's gate (section 6 priority 6). C counts as met when the
#' section 4.3 ladder's free rungs can reach it, since a Switch already in hand
#' is not something the stack needs to supply.
#' @noRd
.missing_bcd_vec <- function(pair){
  state <- pair$state
  status_vec <- .subgoal_status(state)

  miss_vec <- character(0)
  if(!status_vec[["b"]] && !POLICY_ID_LIST$bronzong %in% state$hand_vec){
    miss_vec <- c(miss_vec, "b")
  }
  if(!.c_is_free(state)) miss_vec <- c(miss_vec, "c")
  if(!.psychic_secured(state)) miss_vec <- c(miss_vec, "d")

  miss_vec
}

#' Does Salvatore beat Hilda for this turn's Supporter slot?
#'
#' Section 6 priority 2. Salvatore solves sub-goal B and Hilda solves B and D,
#' so Hilda wins by default -- but Salvatore is ahead in two positions:
#'
#' - the `[P]` source is already secured, so Hilda's second search adds nothing;
#' - the only Bronzor reached play THIS turn, where a Bronzong in hand cannot
#'   legally be used and Salvatore's timing bypass (ADR 0001) is the only route
#'   to B at all.
#' @noRd
.salvatore_beats_hilda <- function(pair){
  state <- pair$state
  if(state$turn_number != 2L) return(FALSE)
  if(!POLICY_ID_LIST$salvatore %in% state$hand_vec) return(FALSE)
  if(.subgoal_status(state)[["b"]]) return(FALSE)
  if(is.null(.salvatore_spot(pair))) return(FALSE)

  .psychic_secured(state) || .bronzong_cannot_evolve(state)
}

#' Where Salvatore would put the Bronzong, or `NULL` if nowhere
#'
#' A Bronzor must be in play to receive it, and the Bronzong must still be
#' believed findable -- the ADR 0003 gate, since `is_salvatore_target()`
#' deliberately answers on public information and would let a fully prized
#' Bronzong look declarable.
#' @noRd
.salvatore_spot <- function(pair){
  state <- pair$state
  if(!believes_findable(pair$knowledge, state, POLICY_ID_LIST$bronzong)){
    return(NULL)
  }
  if(!is_salvatore_target(state, POLICY_ID_LIST$bronzong)) return(NULL)

  if(.active_is(state, "Bronzor") &&
     can_evolve(state, state$active, POLICY_ID_LIST$bronzong,
                bool_via_salvatore = TRUE)){
    return(list(bool_active = TRUE, bench_idx = NA_integer_))
  }

  for(one_idx in .bench_idx_named(state, "Bronzor")){
    if(can_evolve(state, state$bench_list[[one_idx]], POLICY_ID_LIST$bronzong,
                  bool_via_salvatore = TRUE)){
      return(list(bool_active = FALSE, bench_idx = one_idx))
    }
  }

  NULL
}

#' Is every Bronzor in play barred from evolving from hand this turn?
#'
#' The case only Salvatore can answer: an ordinary evolution needs the base to
#' have been in play since before this turn, and Salvatore does not.
#' @noRd
.bronzong_cannot_evolve <- function(state){
  in_play_list <- c(if(.active_is(state, "Bronzor")) list(state$active),
                    state$bench_list[.bench_idx_named(state, "Bronzor")])
  if(length(in_play_list) == 0) return(FALSE)

  !any(sapply(in_play_list, function(one){
    can_evolve(state, one, POLICY_ID_LIST$bronzong)
  }))
}

#' The Supporter to play rather than leave the slot unspent
#'
#' Section 6 priority 8. Nothing above fired, so no card here is solving a named
#' sub-goal -- the question is only which of them changes the position most, and
#' the order is Lillie's (replaces the hand), then a Hilda who can still fetch
#' one of her two targets, then Brock's, then Salvatore, then Ciphermaniac's.
#'
#' It never plays a card that cannot legally resolve, and \code{
#' .policy_build_turn()} calls it after every other play of the turn has run, so
#' Lillie's cannot shuffle away a card the turn still meant to use.
#' @noRd
.fallback_supporter <- function(pair){
  state <- pair$state

  if(POLICY_ID_LIST$lillies %in% state$hand_vec){
    return(POLICY_ID_LIST$lillies)
  }
  if(POLICY_ID_LIST$hilda %in% state$hand_vec &&
     .hilda_targets(pair)$bool_any){
    return(POLICY_ID_LIST$hilda)
  }
  if(POLICY_ID_LIST$brocks %in% state$hand_vec &&
     (length(.brocks_targets(pair)) > 0 ||
      !is.null(.first_findable(pair, POLICY_ID_LIST$bronzong,
                               ALLOWED_TARGET_LIST$evolution)))){
    return(POLICY_ID_LIST$brocks)
  }
  if(POLICY_ID_LIST$salvatore %in% state$hand_vec &&
     !is.null(.salvatore_spot(pair))){
    return(POLICY_ID_LIST$salvatore)
  }
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

  # Both searches are taken whatever the hand already holds. They are
  # independent, and declining one saves no card and avoids no shuffle -- the
  # slot is spent either way, so a redundant second Bronzong is strictly better
  # than nothing. The Energy search is NOT restricted to [P]: Hilda's text takes
  # any Energy card, so Enriching Energy is a legal last resort and a whiff here
  # means every Energy in the list is prized or discarded.
  evo_id <- .first_findable(pair, POLICY_ID_LIST$bronzong,
                            ALLOWED_TARGET_LIST$evolution)
  energy_id <- .first_findable(pair, c(POLICY_ID_LIST$telepathic,
                                       POLICY_ID_LIST$psychic_energy,
                                       POLICY_ID_LIST$enriching),
                               ALLOWED_TARGET_LIST$energy)

  # Whether she is worth the SLOT is a different question, and section 6
  # priority 3 asks this one: a fetch that duplicates a card already held
  # advances no sub-goal, so it does not on its own justify the Supporter.
  bool_evo_new <- !is.null(evo_id) && !status_vec[["b"]] &&
    !POLICY_ID_LIST$bronzong %in% state$hand_vec
  bool_energy_new <- !is.null(energy_id) && !.psychic_secured(state)

  list(evo_id = evo_id, energy_id = energy_id,
       bool_any = !is.null(evo_id) || !is.null(energy_id),
       bool_worth_slot = bool_evo_new || bool_energy_new)
}

#' What Brock's Scouting would fetch in Basics mode
#'
#' Up to two Basics, taken in want-list order, which is what puts **Latias ex**
#' first when sub-goal C is blocked: Brock's and Ultra Ball are the only two
#' cards in the deck that can fetch it (Poke Pad cannot -- Rule Box).
#' @noRd
.brocks_targets <- function(pair){
  target_vec <- character(0)
  for(one_id in .want_vec(pair)){
    if(length(target_vec) >= 2L) break
    found_id <- .first_findable(pair, one_id,
                                ALLOWED_TARGET_LIST$basic_pokemon)
    if(!is.null(found_id)) target_vec <- c(target_vec, found_id)
  }

  target_vec
}

#' Brock's Scouting in Evolution mode, which is the fallback for Bronzong
#'
#' Section 6 priority 3: "use Evolution mode for Bronzong only if Hilda is
#' gone." Hilda fetches the Bronzong *and* an Energy for the same Supporter
#' slot, so spending the slot on Brock's while Hilda is still reachable trades
#' down.
#' @noRd
.brocks_evolution_target <- function(pair){
  state <- pair$state
  if(.subgoal_status(state)[["b"]]) return(NULL)
  if(POLICY_ID_LIST$bronzong %in% state$hand_vec) return(NULL)

  bool_hilda_gone <- !POLICY_ID_LIST$hilda %in% state$hand_vec &&
    !believes_findable(pair$knowledge, state, POLICY_ID_LIST$hilda)
  if(!bool_hilda_gone) return(NULL)

  .first_findable(pair, POLICY_ID_LIST$bronzong, ALLOWED_TARGET_LIST$evolution)
}

#' What Ciphermaniac's would stack on top of the deck
#'
#' Turn 2 draws exactly one of the two, so the missing piece goes first. Where
#' the gap is sub-goal C that means a **Switch**: Ciphermaniac's searches
#' Trainers, which nothing else in the deck does, so it is the only card that
#' can turn the want-list's Switch entry into the card itself.
#' @noRd
.codebreaking_stack <- function(pair){
  energy_want_vec <- c(POLICY_ID_LIST$telepathic,
                       POLICY_ID_LIST$psychic_energy)
  miss_vec <- .missing_bcd_vec(pair)

  want_list <- list(b = POLICY_ID_LIST$bronzong,
                    c = POLICY_ID_LIST$switch_item,
                    d = energy_want_vec)
  # The gaps first, in b / c / d order, then the other two as the second card.
  order_list <- c(want_list[miss_vec], want_list[setdiff(names(want_list),
                                                         miss_vec)])

  found_vec <- unlist(Filter(Negate(is.null),
                             lapply(order_list, function(one_vec){
                               .first_findable(pair, one_vec)
                             })))

  unname(found_vec[seq_len(min(2L, length(found_vec)))])
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
    # Mode follows section 6 priority 3's own condition, not merely "are there
    # targets": Basics mode is for the case it names -- a missing Bronzor, or a
    # blocked sub-goal C wanting Latias ex. Choosing on targets alone made
    # Basics mode win always, because the want-list's "a second Bronzor as
    # insurance" is nearly always findable, and Evolution mode never fired.
    target_vec <- .brocks_targets(pair)
    bool_wanted <- !.subgoal_status(pair$state)[["a"]] || .c_is_blocked(pair)
    bool_basics <- bool_wanted && length(target_vec) > 0
    if(bool_basics){
      return(play_brocks_scouting(pair, mode = "basics",
                                  target_id_vec = target_vec))
    }

    evolution_id <- .brocks_evolution_target(pair)
    if(!is.null(evolution_id)){
      return(play_brocks_scouting(pair, mode = "evolution",
                                  target_id_vec = evolution_id))
    }
    if(length(target_vec) > 0){
      return(play_brocks_scouting(pair, mode = "basics",
                                  target_id_vec = target_vec))
    }

    return(pair)
  }
  if(supporter_id == POLICY_ID_LIST$salvatore){
    # Section 6 priority 2, and the priority 8 fallback. The section 4.1 kill
    # line plays its own Salvatore; this is the turn-2 use, where the card is
    # worth the slot for the evolution alone.
    spot_list <- .salvatore_spot(pair)
    if(is.null(spot_list)) return(pair)

    return(play_salvatore(pair, target_id = POLICY_ID_LIST$bronzong,
                          target_is_active = spot_list$bool_active,
                          bench_idx = spot_list$bench_idx))
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

  # Section 4.2 step 6: attach only while sub-goal D is unmet. Positioning has
  # already run by the time this is called, so the recipient IS the Pokemon that
  # will attack -- and one [P] source is the whole cost of Evolution Jammer. A
  # second Energy would buy nothing but Telepathic's search, whose two fetches
  # land in the Bench slots section 4.4 is holding for Latias ex.
  if(.has_psychic_attached(state, recipient)) return(pair)

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
    search_vec <- .telepathic_search_targets(pair)
  }

  attach_energy(pair, energy_id,
                target_is_active = bool_active,
                bench_idx = if(bool_active) NA_integer_ else bench_idx_vec[1],
                search_id_vec = search_vec)
}

#' Two Basic `[P]` Pokemon for Telepathic Psychic Energy to fetch
#'
#' **Always takes two when it can, even when the second is not wanted for its
#' own sake** (Kevin, 2026-08-29). The wanted targets come first, but every card
#' pulled out of the deck also *thins* it, and a thinner deck is a better chance
#' that the next draw is the Bronzong the turn is missing. Declining the second
#' target leaves that for nothing.
#'
#' Capped by Bench space rather than by the card, which allows up to 2.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns Up to two card ids, possibly empty.
#' @noRd
.telepathic_search_targets <- function(pair){
  num_space <- max(0L, BENCH_LIMIT - length(pair$state$bench_list))
  num_want <- min(2L, num_space)
  if(num_want == 0) return(character(0))

  target_vec <- character(0)
  # The sub-goal want-list first: these are fetched because we need them.
  for(one_id in .want_vec(pair, bool_to_hand = FALSE)){
    if(length(target_vec) >= num_want) break
    found_id <- .first_findable(pair, one_id, ALLOWED_TARGET_LIST$telepathic)
    if(!is.null(found_id)) target_vec <- c(target_vec, found_id)
  }
  if(length(target_vec) >= num_want) return(target_vec)

  # Then anything else the card may legally take, purely to thin the deck.
  filler_vec <- pair$state$card_df$card_id[
    ALLOWED_TARGET_LIST$telepathic(pair$state$card_df,
                                   pair$state$card_df$card_id)]
  for(one_id in setdiff(filler_vec, target_vec)){
    if(length(target_vec) >= num_want) break
    found_id <- .first_findable(pair, one_id, ALLOWED_TARGET_LIST$telepathic)
    if(!is.null(found_id)) target_vec <- c(target_vec, found_id)
  }

  target_vec
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

  search_vec <- .telepathic_search_targets(pair)
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
  supporter_id <- .choose_supporter(pair, bool_fallback = FALSE)

  pair <- .policy_bench(pair,
                        bool_before_lillies = identical(supporter_id,
                                                        POLICY_ID_LIST$lillies))
  pair <- .policy_search_items(pair)
  pair <- .policy_position(pair, bool_allow_surfer = FALSE)
  # Re-asked, because the searches may have changed the hand.
  pair <- .play_chosen_supporter(pair,
                                 .choose_supporter(pair,
                                                   bool_fallback = FALSE))

  # The Supporter may have fetched the pieces, so bench and evolve afterwards --
  # and position AFTER evolving, not before. The other order left a Bronzong
  # that .policy_evolve() had just made on the Bench stranded there with a
  # Switch still in hand, which the trace then reported as a decision defect.
  pair <- .policy_assemble(pair)

  # Section 6 priority 8, here rather than above because the fallback's cards
  # are not fetching a piece the turn still needs -- and Lillie's, which is
  # first among them, would shuffle the hand away underneath the evolution and
  # the attachment if it fired any earlier.
  pair <- .policy_fallback_supporter(pair)
  # ...and then the same steps AGAIN, over whatever it drew or fetched. A
  # Supporter played at the very end of a turn, whose cards can never be used,
  # does not "increase my chances to get set up" at all, which is the whole
  # reason section 6 priority 8 exists. The second pass is worth 5.0 points
  # going second and 6.7 going first; without it the fallback is worth nothing
  # on turn 2, where the window closes before the cards can be played.
  pair <- .policy_assemble(pair)
  # Section 4.2 step 6 and section 5 step 6, both of which come after everything
  # that matters: neither advances a sub-goal, and Pokegear shuffles.
  pair <- .policy_stadium(pair)
  pair <- .policy_pokegear(pair)

  if(can_use_evolution_jammer(pair$state)){
    return(attack_evolution_jammer(pair))
  }

  # Section 4.2: Run Around only as a last resort, after every other play, and
  # only when it does not cost the [P] source sub-goal D needs.
  .policy_run_around(pair)
}

#' Put the pieces together: bench, evolve, position, attach
#'
#' The four steps that convert cards in hand into the board the attack needs,
#' factored out because \code{.policy_build_turn()} runs them twice -- once on
#' the hand as it stands, and once more on whatever the section 6 priority 8
#' fallback drew or fetched.
#'
#' Order matters and is section 7's: evolve BEFORE positioning, so a Bronzong
#' made on the Bench is promoted in the same pass rather than stranded there
#' with a Switch still in hand.
#' @noRd
.policy_assemble <- function(pair){
  pair <- .policy_bench(pair)
  pair <- .policy_evolve(pair)
  pair <- .policy_position(pair, bool_allow_surfer = TRUE)

  .policy_energy(pair)
}

#' Spend the Supporter slot rather than end the turn with it unspent
#'
#' Section 6 priority 8, run at the end of the turn. The slot is a per-turn
#' resource that carries no credit forward, so leaving it idle destroys it.
#'
#' Lillie's shuffles the hand into the deck, so the Pokemon worth keeping go to
#' the Bench first (section 4.4) exactly as they do for a priority-7 Lillie's.
#' @noRd
.policy_fallback_supporter <- function(pair){
  if(!can_play_supporter(pair$state)) return(pair)

  supporter_id <- .fallback_supporter(pair)
  if(is.null(supporter_id)) return(pair)

  if(identical(supporter_id, POLICY_ID_LIST$lillies)){
    pair <- .policy_bench(pair, bool_before_lillies = TRUE)
    # Benching may have emptied the hand enough to change the answer.
    supporter_id <- .fallback_supporter(pair)
  }

  .play_chosen_supporter(pair, supporter_id)
}

#' Play a Stadium, if one is held and it does not hurt us
#'
#' Section 4.2 step 6. None of the four Stadiums advances a sub-goal, so this
#' changes no rate -- but a Stadium in play is part of the end-of-turn-2 board
#' state that ADR 0007 records in full, so the snapshot is wrong without it.
#'
#' **Mystery Garden is excluded**: `docs/03a_card_playbook.md` reads its effect
#' as costing a `[P]` source to draw, which is the one Stadium that could work
#' against sub-goal D. It is also flagged in `CLAUDE_kevin.md` as modelled inert
#' while its text says otherwise, so declining it is the conservative reading.
#' @noRd
.policy_stadium <- function(pair){
  state <- pair$state
  if(isTRUE(state$turn_flag_list$bool_stadium_played)) return(pair)
  if(!can_act(state)) return(pair)

  hand_df <- lookup_card(state$card_df, state$hand_vec)
  stadium_vec <- state$hand_vec[!is.na(hand_df$subtype) &
                                  hand_df$subtype == "stadium"]
  stadium_vec <- setdiff(stadium_vec, "MEG-122")
  if(length(stadium_vec) == 0) return(pair)
  # A Stadium may not replace one of the same name already in play.
  if(!is.na(state$stadium)){
    in_play_name <- lookup_card(state$card_df, state$stadium)$name
    keep_vec <- lookup_card(state$card_df, stadium_vec)$name != in_play_name
    stadium_vec <- stadium_vec[keep_vec]
    if(length(stadium_vec) == 0) return(pair)
  }

  play_stadium(pair, stadium_vec[1])
}

#' Pokegear 3.0, the only Item that digs for a Supporter
#'
#' Section 5 step 6: played **last**, and never while a Ciphermaniac's stack is
#' pending, because it shuffles. No decklist runs it, so this exists to match
#' the document rather than to be exercised.
#' @noRd
.policy_pokegear <- function(pair){
  state <- pair$state
  if(!POLICY_ID_LIST$pokegear %in% state$hand_vec) return(pair)
  if(!can_play_item(state)) return(pair)
  if(.stack_is_pending(pair)) return(pair)

  # Only worth it while a Supporter can still be played -- this turn or next.
  want_vec <- c(POLICY_ID_LIST$hilda, POLICY_ID_LIST$salvatore,
                POLICY_ID_LIST$brocks, POLICY_ID_LIST$lillies)
  want_vec <- setdiff(want_vec, state$hand_vec)
  if(length(want_vec) == 0) return(pair)

  play_pokegear(pair, preference_id_vec = want_vec)
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

  # Before anything else, because it changes the hand every later step reads.
  pair <- .policy_run_errand(pair)

  if(.kill_line_is_live(pair)) return(.policy_kill_line(pair))

  .policy_build_turn(pair)
}

#' Mega Kangaskhan ex's Run Errand, whenever it is available
#'
#' Draw 2, once per turn, only while Kangaskhan is Active. It costs nothing and
#' there is no state in this window where two more cards are unwanted, so it is
#' taken unconditionally and taken FIRST -- every later decision reads the hand.
#'
#' It also has to happen before positioning: the section 4.3 ladder is about to
#' retreat or Switch Kangaskhan out of the Active spot, which is the only place
#' the Ability works.
#'
#' The policy skipping this is why Kangaskhan looked like a poor lead in the
#' first demo run -- it was judged with its whole upside switched off, at 40.9%
#' against the 55.8% it reaches once the Ability is used.
#' @noRd
.policy_run_errand <- function(pair){
  state <- pair$state
  if(!.active_is(state, "Mega Kangaskhan ex")) return(pair)
  if(isTRUE(state$turn_flag_list$bool_run_errand_used)) return(pair)
  if(!can_act(state)) return(pair)

  use_run_errand(pair)
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
