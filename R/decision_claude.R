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
# what to change here, and so a divergence is findable rather than discovered.
# EVERY section of docs/03_decision_tree.md has a row, including the two that
# describe rather than instruct -- an absent row reads as "not implemented" and
# is the shape a divergence hides in.
#
#   section 1   the four sub-goals, as the        .subgoal_status()
#               PLAYER sees them                  (unmet_subgoals() in
#                                                 R/trace_claude.R is the
#                                                 analyst's separate view)
#   section 2   the four scarce resources -- no single function. The Supporter
#               slot is can_play_supporter(); the attachment is
#               can_attach_energy(); the Active spot is .policy_position(); the
#               Bench is has_bench_space() and .policy_bench(). All four live in
#               R/rules_claude.R except the two policy calls.
#   section 3   the lead, and benching nothing    policy_placement()
#               the order, as a parameter         LEAD_ORDER_LIST
#                                                 make_policy_placement()
#   section 4.1 the turn-1 Salvatore kill         .kill_line_is_live()
#                                                 .policy_kill_line()
#   section 4.2 the turn-1 build, Run Around      .policy_build_turn()
#                                                 .policy_run_around()
#        step 3 the free search Items             .policy_search_items()
#                                                 .poffin_targets()
#        step 6 which body takes the attachment   .policy_energy()
#                                                 .energy_recipient()
#                                                 .telepathic_search_targets()
#                                                 .policy_telepathic_search()
#        step 6 the Enriching exception           .policy_enriching()
#        step 7 the Stadium                       .policy_stadium()
#   section 4.3 the positioning ladder            .policy_position()
#               rung 5, the Cursed Blast escape   .policy_cursed_blast_escape()
#   section 4.4 what to bench, and when           .policy_bench()
#               the Meowth ex clause              .policy_bench_meowth()
#                                                 .salvatore_is_cashable()
#               "in play" -- Active OR Bench      .in_play_named()
#   section 4.5 free Abilities, taken first       .policy_run_errand()
#   section 5   going first                       .policy_build_turn(), which
#                                                 branches on can_play_supporter
#                                                 rather than on the coin flip
#        step 6 Pokegear 3.0                      .policy_pokegear()
#   section 6   the Supporter priority table      .choose_supporter()
#                                                 .play_chosen_supporter()
#               priority 2, Salvatore on turn 2   .salvatore_beats_hilda()
#                                                 .salvatore_spot()
#                                                 .bronzong_cannot_evolve()
#               priority 3, Hilda                 .hilda_targets()
#               priority 4, Brock's Scouting      .brocks_targets()
#                                                 .brocks_evolution_target()
#               priority 6, Ciphermaniac's gate   .missing_bcd_vec()
#                                                 .codebreaking_stack()
#                                                 .stack_is_pending()
#               priority 7, the draw Supporters   .draw_supporter()
#               priority 8, the fallback          .fallback_supporter()
#                                                 .policy_fallback_supporter()
#   section 7   turn 2                            .policy_build_turn()
#        step 3 evolve                            .policy_evolve()
#        step 6 the second pass                   .policy_assemble()
#   section 8   Cursed Blast escape               .policy_cursed_blast_escape()
#               Dusknoir on the want-list         .escape_is_only_route()
#               Rare Candy once B is settled      .policy_leftover_rare_candy()
#                                                 .bronzong_is_settled()
#   section 9   the open-question register -- prose, no code by construction.
#   03a         the want-list, per-card rules     .want_vec(), .c_is_blocked(),
#                                                 .bronzor_is_missing(), and the
#                                                 .*_targets() helpers
#               "no second Bronzor", across       .walk_want_list(), shared by
#               printings                         all three multi-target cards
#               the Ultra Ball discard rules      .ultra_ball_discards()
#                                                 .ultra_ball_keep_idx()
#                                                 .ULTRA_BALL_ORDER_VEC
#               the line, protected by name       .line_keep_idx()
#               "surplus ... beyond 1"            .surplus_keep_idx()
#               Gwynn's discards                  .gwynn_discards()
#   03a         "specified and not implemented" -- Dunsparce's Trading Places,
#               Dudunsparce's Run Away Draw, and Darkness Energy as Run Around's
#               payment have NO function here, deliberately. Do not add one
#               without moving the entry out of that section.
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
                       gwynn = "PBL-078",
                       risky_ruins = "MEG-127",
                       brocks = "JTG-146",
                       ciphermaniacs = "TEF-145",
                       surfer = "SSP-187",
                       switch_item = "MEG-130",
                       poke_pad = "POR-081",
                       poffin = "TEF-144",
                       ultra_ball = "MEG-131",
                       pokegear = "BLK-084",
                       rare_candy = "MEG-125",
                       night_stretcher = "ASC-196",
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

#' Bench slots whose top card matches one of these names
#' @noRd
.bench_idx_named <- function(state, name_str){
  if(length(state$bench_list) == 0) return(integer(0))

  name_vec <- sapply(state$bench_list, function(one){
    lookup_card(state$card_df, top_card(one))$name
  })

  which(name_vec %in% name_str)
}

#' Is a Pokemon of this name IN PLAY -- Active or Bench?
#'
#' The documents say "in play" and mean it: `docs/03a_card_playbook.md`
#' want-list item 4 reads "Latias ex -- if **not in play**", and section 4.3
#' rung 1 and section 8 both say "Latias ex in play". Three predicates used to
#' ask \code{.bench_idx_named()} instead, which never inspects `state$active`.
#'
#' That was survivable while section 3 ranked Latias ex **last**. ADR 0008 moved
#' it to **first going second**, so an Active Latias ex became the most common
#' opening on the strong branch -- and decklist7 and decklist8 run two copies,
#' so the searches then chased a redundant second one with a real Ultra Ball.
#' @noRd
.in_play_named <- function(state, name_str){
  .active_is(state, name_str) ||
    length(.bench_idx_named(state, name_str)) > 0
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
  # Section 1 calls these "four INDEPENDENT sub-goals", and D is "a [P] source
  # is attached". Defining D as `bool_c && ...` made it a conjunction of C and
  # D, so a Bronzong on the Bench carrying a [P] source reported D unmet. No
  # caller read the field -- every D question routes through .psychic_secured()
  # -- so this changed no play; it made the function disagree with the section
  # the header map points at it.
  bool_d <- any(sapply(in_play_list, function(one){
    top_card(one) == POLICY_ID_LIST$bronzong &&
      has_evolution_jammer_cost(state, one)
  }))

  c(a = isTRUE(bool_a), b = isTRUE(bool_b),
    c = isTRUE(bool_c), d = isTRUE(bool_d))
}

# ---------------------------------------------------------------------------
# Section 3 -- setup
# ---------------------------------------------------------------------------

#' The section 3 lead order, as a policy PARAMETER rather than a constant
#'
#' docs/03_decision_tree.md section 3 requires this: "the lead order is a policy
#' parameter that part 6 varies across runs, not a constant compiled into the
#' policy". \code{scripts/tune_lead_order_claude.R} is what varies it, and the
#' vectors below are the order that search settled on.
#'
#' Meowth ex is absent from both on purpose: leading it wastes Last-Ditch Catch
#' outright, so it is chosen only when it is the only Basic in hand, by the
#' unranked fallback. Bronzor is pinned at rank 1 for the same kind of reason --
#' it satisfies sub-goal C outright at no cost.
#'
#' **The two vectors differ only because the evidence differs, not because the
#' branches do.** Going second the search moved two names and the change
#' confirms out of sample twice (+1.3 points on one disjoint block, +0.68 with a
#' standard error of 0.20 on another). Going first every candidate order lands
#' within 0.22 points of the incumbent, which is nothing, so the incumbent
#' stands unchanged rather than being replaced by the maximum of twenty noisy
#' numbers.
#'
#' @export
LEAD_ORDER_LIST <- list(
  going_first = c("Bronzor", "Mega Kangaskhan ex", "Duskull", "Budew",
                  "Buneary", "Flutter Mane", "Latias ex"),
  going_second = c("Bronzor", "Latias ex", "Mega Kangaskhan ex", "Duskull",
                   "Budew", "Flutter Mane", "Buneary"))

#' Choose the opening Active, and bench nothing
#'
#' docs/03_decision_tree.md section 3. Lead a Bronzor whenever one is in hand --
#' it satisfies sub-goal C outright and costs nothing. Otherwise fall down the
#' section 3 order, which is \code{LEAD_ORDER_LIST} and is varied across runs
#' rather than compiled in.
#'
#' **Benches nothing.** Every other Basic stays in hand, where benching it later
#' is a decision taken with information rather than a placement made blind. Safe
#' only because nothing in either scenario can Knock Out our Active inside the
#' window; see section 3.
#'
#' Signature is fixed by \code{setup_game()}'s `placement_fn` hook, which calls
#' it as `placement_fn(state)`; \code{make_policy_placement()} is how a run
#' supplies a different order through that hook.
#'
#' @param state a `"bronzong_state"` holding the opening hand.
#' @param lead_order_list a list with `going_first` and `going_second`, each an
#'   ordered vector of Pokemon NAMES, best lead first. Names not listed rank
#'   last, in hand order.
#'
#' @returns A list with `active_card_id` and an empty `bench_card_id_vec`.
#' @export
policy_placement <- function(state, lead_order_list = LEAD_ORDER_LIST){
  stopifnot(inherits(state, "bronzong_state"))
  stopifnot(is.list(lead_order_list),
            all(c("going_first", "going_second") %in% names(lead_order_list)))

  basic_vec <- state$hand_vec[is_basic_pokemon(state$card_df, state$hand_vec)]
  if(length(basic_vec) == 0) stop("no Basic Pokemon to lead")

  name_vec <- lookup_card(state$card_df, basic_vec)$name
  order_vec <- if(state$bool_going_first){
    lead_order_list$going_first
  } else {
    lead_order_list$going_second
  }
  rank_vec <- match(name_vec, order_vec)
  rank_vec[is.na(rank_vec)] <- length(order_vec) + 1L

  list(active_card_id = basic_vec[which.min(rank_vec)],
       bench_card_id_vec = character(0))
}

#' A `placement_fn` that leads by a supplied order
#'
#' \code{setup_game()} calls its hook as `placement_fn(state)` and passes
#' nothing else, so varying the section 3 order across runs means closing over
#' it here rather than threading an argument through the hook.
#'
#' @param lead_order_list as in \code{policy_placement()}.
#'
#' @returns A function of `(state)` suitable for `setup_game()`'s
#'   `placement_fn`.
#' @export
make_policy_placement <- function(lead_order_list){
  stopifnot(is.list(lead_order_list),
            all(c("going_first", "going_second") %in% names(lead_order_list)))

  function(state) policy_placement(state, lead_order_list = lead_order_list)
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
  #
  # ONE of it, though. Section 4.4 justifies the bench on Latias ex being "the
  # one Basic whose PRESENCE alone advances a sub-goal", and presence is
  # satisfied by the first copy -- a second adds nothing and spends the slot
  # section 2 calls the fourth scarce resource. decklist7 and decklist8 run two.
  if(POLICY_ID_LIST$latias %in% state$hand_vec && has_bench_space(state) &&
     !.in_play_named(state, "Latias ex")){
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
  # Section 4.4 benches it "when a specific Supporter is WANTED", and a Supporter
  # that can never be played is not wanted. On turn 1 the fetch is for turn 2 and
  # is always cashable -- including going first, where no Supporter is legal
  # today but one is tomorrow. On turn 2 the window ends here, so a spent slot
  # makes the whole play a Bench slot traded for a card nobody can play. S-27
  # is that position: Gwynn took the slot, and the Hilda Meowth ex then fetched
  # sat in hand while the turn missed.
  if(state$turn_number == 2L && !can_play_supporter(state)) return(pair)

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
  # EVERY copy, not just the first: it costs nothing, so a Poke Pad held back is
  # a free search thrown away and the window has no later turn to spend it on.
  # The want-list is re-read between copies, so the second chases whatever the
  # first left open. Bounded by the copies actually in hand, since play_poke_pad
  # discards the card and an unbounded `while` on a hand predicate is one silent
  # effects bug away from spinning forever.
  num_pad <- sum(pair$state$hand_vec == POLICY_ID_LIST$poke_pad)
  for(one_pad in seq_len(num_pad)){
    if(!POLICY_ID_LIST$poke_pad %in% pair$state$hand_vec) break
    if(!can_play_item(pair$state)) break
    # Poke Pad cannot fetch a rule-box Pokemon, so Latias ex is filtered out
    # here rather than declined later.
    target_id <- .first_findable(pair, .want_vec(pair),
                                 ALLOWED_TARGET_LIST$poke_pad)
    if(is.null(target_id)) break
    pair <- play_poke_pad(pair, target_id = target_id)
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

  .walk_want_list(pair, .want_vec(pair, bool_to_hand = FALSE),
                  ALLOWED_TARGET_LIST$poffin, min(2L, num_space))
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
  # Item 4, both clauses as the playbook writes them: "if NOT IN PLAY and
  # BRONZOR is not Active". In play means Active or Bench; and the second clause
  # is about a Bronzor, not about sub-goal C -- an Active Bronzor is one
  # evolution from C and needs no mover, so wanting Latias ex there spends a
  # search on a card the turn cannot use.
  if(!.active_is(state, c("Bronzor", "Bronzong")) &&
     !.in_play_named(state, "Latias ex")){
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
  # Item 6's FIRST clause -- "if a Supporter is still wanted" -- was missing
  # here, though .policy_bench_meowth() carries it. So on turn 2 with the slot
  # already spent, an Ultra Ball would still pay two discards for a Meowth ex
  # whose Ability the window can never cash. On turn 1 the fetch is for turn 2
  # and always cashes, going first included.
  bool_supporter_wanted <- state$turn_number == 1L || can_play_supporter(state)
  if(bool_to_hand && bool_supporter_wanted &&
     !POLICY_ID_LIST$meowth %in% state$hand_vec &&
     !.in_play_named(state, "Meowth ex")){
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

  # And an item "0" above all of it when the Cursed Blast escape is the only
  # route to C (section 8). Dusknoir is then the single card that opens the
  # turn's only door, so it outranks even the Bronzor -- the same promotion
  # Latias ex gets above, for the same reason and one rung further down the
  # section 4.3 ladder.
  if(.escape_is_only_route(pair)){
    want_vec <- c(POLICY_ID_LIST$dusknoir, want_vec)
  }

  want_vec
}

#' Is a Bronzor missing, as the want-list defines missing?
#'
#' `docs/03a_card_playbook.md` want-list item 1 is "**Bronzor** -- if none in
#' play **and none in hand**", and section 6 priority 4 fires Brock's Basics
#' mode "when a **Bronzor is missing**". Two call sites read that as
#' `!.subgoal_status()[["a"]]` -- none in PLAY -- so a Bronzor sitting in hand
#' still counted as missing, and the Supporter slot went to Brock's at priority
#' 4 ahead of priorities 5 to 7. Worse, `.want_vec()` had already dropped
#' Bronzor for exactly the right reason, so `.brocks_targets()` then returned
#' filler and the slot bought a Duskull.
#' @noRd
.bronzor_is_missing <- function(pair){
  state <- pair$state

  !.subgoal_status(state)[["a"]] &&
    length(intersect(state$hand_vec, .bronzor_ids(state$card_df))) == 0
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

  if(.in_play_named(state, "Latias ex")) return(FALSE)
  if(can_retreat(state) && retreat_cost(state) == 0) return(FALSE)

  !(POLICY_ID_LIST$switch_item %in% state$hand_vec && can_play_item(state))
}

#' Is the Cursed Blast escape the only door left to sub-goal C?
#'
#' docs/03_decision_tree.md section 8, and the condition that puts **Dusknoir**
#' at the front of the want-list. Narrow on purpose -- every clause below is
#' load-bearing, and with any one of them false the promotion does not apply and
#' the want-list reads as it always does.
#'
#' The **B-secured** clause is the one worth naming. With both B and C open, one
#' search cannot close both, and B has no other route this turn either -- so the
#' Bronzong keeps the search and this returns `FALSE`. The promotion is for the
#' position where the Bronzong is already held and the Active is what is wrong.
#'
#' Rare Candy in hand is required because it is the only way from a **Duskull**
#' Active to a Dusknoir in one turn, and Items must be playable, which
#' `item_lock` takes away on exactly the turn this matters.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns A single logical.
#' @noRd
.escape_is_only_route <- function(pair){
  state <- pair$state
  status_vec <- .subgoal_status(state)
  if(status_vec[["c"]]) return(FALSE)

  # B secured: in play, or in hand and legally usable this turn.
  if(!status_vec[["b"]] && !POLICY_ID_LIST$bronzong %in% state$hand_vec){
    return(FALSE)
  }
  # A Dusclops or Dusknoir Active needs no search -- it is already the escape.
  if(!.active_is(state, "Duskull")) return(FALSE)
  if(POLICY_ID_LIST$dusknoir %in% state$hand_vec) return(FALSE)
  if(!POLICY_ID_LIST$rare_candy %in% state$hand_vec) return(FALSE)
  if(!can_play_item(state)) return(FALSE)
  # Something to promote once the Active knocks itself out.
  if(length(.bench_idx_named(state, c("Bronzor", "Bronzong"))) == 0){
    return(FALSE)
  }

  # The cheaper rungs of the section 4.3 ladder, which all beat this one.
  if(.in_play_named(state, "Latias ex")) return(FALSE)
  if(can_retreat(state) && retreat_cost(state) == 0) return(FALSE)

  !(POLICY_ID_LIST$switch_item %in% state$hand_vec)
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
.ULTRA_BALL_ORDER_VEC <- c(
  # Blissey ex first of all: it evolves from Chansey and no decklist runs one,
  # so in every list that holds it the card cannot be put into play at all.
  "TWM-134",
  "CRI-082", "MEG-114", "ASC-196", "TEF-145",
  # Risky Ruins is a Stadium section 4.2 step 7 declines as disruptive to us, so
  # it is a card the window can never convert; Darkness Energy cannot pay
  # sub-goal D and its only job is an Ability that is inert here.
  "MEG-127", "MEE-007",
  "PRE-035", "PRE-036", "SFA-019", "PRE-037", "MEG-125",
  "ASC-197", "TWM-153", "TWM-149", "MEG-122",
  "TEF-078", "TWM-095", "JTG-120", "TEF-129",
  "TEF-069")

#' Hand positions Ultra Ball may not discard
#'
#' The playbook's never-discard list, in three pieces:
#'
#' \describe{
#'   \item{this function}{the LAST copy of each per-turn resource -- the `[P]`
#'     source, the Switch that answers sub-goal C, Salvatore on a live kill,
#'     and this turn's chosen Supporter.}
#'   \item{\code{.line_keep_idx()}}{the Bronzor and Bronzong line, protected by
#'     NAME rather than by count.}
#'   \item{\code{.surplus_keep_idx()}}{the "surplus ... beyond 1" clauses -- one
#'     Duskull and one Rare Candy, which are the two halves of the section 4.3
#'     rung-5 escape.}
#' }
#'
#' The last two are split out because **Gwynn discards from hand too** and the
#' two cards must agree about what is spare; two lists answering that question
#' will disagree, and the disagreement will be silent. They are also the two
#' pieces that ask nothing about this turn's Supporter, which is what lets Gwynn
#' use them without \code{.choose_supporter()} recursing into itself.
#'
#' Counted positionally, in hand positions rather than ids, so "the only" is
#' checked rather than assumed.
#' @noRd
.ultra_ball_keep_idx <- function(pair, candidate_idx){
  state <- pair$state
  single_vec <- character(0)

  # "the only `[P]` source" -- singular, and about the SOURCE rather than about
  # each printing. Seeding single_vec with both ids kept one copy of EACH, so a
  # hand holding a Telepathic and a basic Psychic protected both; with two
  # sources in hand neither is "the only" one, and over-protecting can push the
  # discardable count below 2 and make Ultra Ball unplayable outright -- the
  # exact failure the playbook's "fewer than 2 remain" clause describes.
  #
  # The Telepathic is the copy kept, because it also searches.
  psychic_vec <- .psychic_in_hand(state)
  if(length(psychic_vec) > 0){
    hit_idx <- candidate_idx[state$hand_vec[candidate_idx] == psychic_vec[1]]
    if(length(hit_idx) > 0) single_vec <- c(single_vec, psychic_vec[1])
  }

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

  keep_idx <- c(.line_keep_idx(pair, candidate_idx),
                .surplus_keep_idx(pair, candidate_idx))

  for(one_id in unique(single_vec)){
    hit_idx <- candidate_idx[state$hand_vec[candidate_idx] == one_id]
    # One copy only: the rest are surplus and may be spent.
    if(length(hit_idx) > 0) keep_idx <- c(keep_idx, hit_idx[1])
  }

  unique(keep_idx)
}

#' Hand positions the Bronzor/Bronzong line occupies and will not give up
#'
#' The half of the never-discard list that is about the LINE rather than about
#' this turn's resources, split out because **two** cards now discard from hand
#' -- Ultra Ball and Gwynn -- and they must agree about what is spare.
#'
#' Split rather than shared wholesale for a second reason: the rest of
#' \code{.ultra_ball_keep_idx()} asks \code{.choose_supporter()} which Supporter
#' this turn wants, and Gwynn's own branch inside `.choose_supporter()` would
#' then recurse into itself. Nothing here asks that question.
#'
#' Every copy is protected, surplus included, and each is released only by the
#' card that undoes the discard: a Night Stretcher in hand for the Bronzong (and
#' one Night Stretcher then becomes protected too, since spending both is the
#' ordering the rule forbids), a Salvatore in hand for the Bronzor.
#' @noRd
.line_keep_idx <- function(pair, candidate_idx){
  state <- pair$state
  single_vec <- character(0)
  every_vec <- character(0)

  bronzor_vec <- .bronzor_ids(state$card_df)
  if(POLICY_ID_LIST$salvatore %in% state$hand_vec){
    single_vec <- c(single_vec, bronzor_vec)
  } else {
    every_vec <- c(every_vec, bronzor_vec)
  }
  if(POLICY_ID_LIST$night_stretcher %in% state$hand_vec){
    single_vec <- c(single_vec, POLICY_ID_LIST$bronzong,
                    POLICY_ID_LIST$night_stretcher)
  } else {
    every_vec <- c(every_vec, POLICY_ID_LIST$bronzong)
  }

  keep_idx <- integer(0)
  for(one_id in unique(single_vec)){
    hit_idx <- candidate_idx[state$hand_vec[candidate_idx] == one_id]
    if(length(hit_idx) > 0) keep_idx <- c(keep_idx, hit_idx[1])
  }
  for(one_id in unique(every_vec)){
    keep_idx <- c(keep_idx,
                  candidate_idx[state$hand_vec[candidate_idx] == one_id])
  }

  unique(keep_idx)
}

#' Hand positions covered by the discard order's "surplus ... beyond 1" clauses
#'
#' `docs/03a_card_playbook.md` writes two entries of its discard order as
#' **surplus** rather than as the card outright -- "surplus Duskull beyond 1"
#' and "surplus Rare Candy" -- which is a keep rule wearing an order's clothing.
#' Neither was implemented: both sat on `.ULTRA_BALL_ORDER_VEC` with no
#' protection, so the LAST copy of each was spendable.
#'
#' Both are the section 4.3 rung-5 escape's two halves. A **Duskull** is the
#' body the escape starts from and a **Rare Candy** is the only route from it to
#' a Dusknoir -- and decklist7 and decklist8 run **one** Rare Candy, so a single
#' Ultra Ball could close that door for the whole game.
#'
#' Shared by Ultra Ball and Gwynn, which must agree about what is spare. Gwynn
#' cannot discard a Rare Candy anyway -- it is a Trainer -- so that entry is
#' inert on its path rather than wrong.
#' @noRd
.surplus_keep_idx <- function(pair, candidate_idx){
  state <- pair$state

  keep_idx <- integer(0)
  for(one_id in c(POLICY_ID_LIST$duskull, POLICY_ID_LIST$rare_candy)){
    hit_idx <- candidate_idx[state$hand_vec[candidate_idx] == one_id]
    if(length(hit_idx) > 0) keep_idx <- c(keep_idx, hit_idx[1])
  }

  keep_idx
}

#' Up to two spare Pokemon for Gwynn to discard
#'
#' docs/03a_card_playbook.md -> Gwynn. Three cards each; "up to 2" is literal,
#' and discarding nothing draws nothing, so the caller must treat an empty
#' return as "Gwynn is not worth the slot" rather than as "play it for free".
#'
#' Legality is two conditions -- a Pokemon, and no Rule Box -- and the choice
#' among the legal ones reuses the Ultra Ball discard order rather than
#' inventing a second one. The line is protected by \code{.line_keep_idx()}, the
#' same rule and the same code.
#' @noRd
.gwynn_discards <- function(pair){
  state <- pair$state
  if(length(state$hand_vec) == 0) return(character(0))

  hand_df <- lookup_card(state$card_df, state$hand_vec)
  candidate_idx <- which(hand_df$category == "pokemon" & !hand_df$has_rule_box)
  candidate_idx <- setdiff(candidate_idx,
                           c(.line_keep_idx(pair, candidate_idx),
                             .surplus_keep_idx(pair, candidate_idx)))
  if(length(candidate_idx) == 0) return(character(0))

  rank_vec <- match(state$hand_vec[candidate_idx], .ULTRA_BALL_ORDER_VEC)
  rank_vec[is.na(rank_vec)] <- length(.ULTRA_BALL_ORDER_VEC) + 1L
  take_idx <- candidate_idx[order(rank_vec)]

  state$hand_vec[take_idx[seq_len(min(2L, length(take_idx)))]]
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
     (.bronzor_is_missing(pair) || .c_is_blocked(pair)) &&
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

  # Priority 7 -- the two draw Supporters. Behind Ciphermaniac's, and that
  # ordering is measured rather than assumed: putting them ahead of it, as
  # section 6's table numbering once did, costs 1.92 points with a standard
  # error of 0.22 (4,000 paired replicates, decklist2, going second). The
  # mechanism is that Ciphermaniac's is a TUTOR for the one missing piece while
  # Lillie's is eight random cards out of forty, and a tutor beats a lottery
  # when the target is one named card.
  draw_id <- .draw_supporter(pair)
  if(!is.null(draw_id)) return(draw_id)

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

#' The draw Supporter to play, or `NULL` for neither
#'
#' Section 6 priority 5. Two cards do the same job by opposite means, and which
#' is right turns on **whether the hand is holding a piece the turn still
#' needs**:
#'
#' \itemize{
#'   \item **Lillie's Determination** shuffles the hand into the deck and draws
#'     8. Strictly more cards, and it buries whatever was in hand.
#'   \item **Gwynn** keeps the hand and draws 3 for each of up to 2 spare
#'     Pokemon discarded. Fewer cards, and nothing is buried.
#' }
#'
#' So Gwynn goes first when Lillie's would bury a Bronzong, a `[P]` source, or
#' the Switch that answers an open sub-goal C -- and only when a spare Pokemon
#' exists to pay with, since "up to 2" is literal and discarding nothing draws
#' nothing. Otherwise Lillie's, on its own four-card gate.
#'
#' **This is a default rather than a ruling** (DT-27): no decklist ran a Gwynn
#' before decklist7, and the discriminator has not been put to Kevin as a
#' position.
#' @noRd
.draw_supporter <- function(pair){
  state <- pair$state
  bool_gwynn <- POLICY_ID_LIST$gwynn %in% state$hand_vec &&
    length(.gwynn_discards(pair)) > 0
  bool_lillies <- POLICY_ID_LIST$lillies %in% state$hand_vec &&
    length(state$hand_vec) <= 4

  # What Lillie's would destroy by shuffling the hand away. The Switch counts
  # only while sub-goal C is actually open, matching the Ultra Ball rule.
  keep_vec <- c(POLICY_ID_LIST$bronzong, .psychic_in_hand(state))
  if(!.subgoal_status(state)[["c"]]){
    keep_vec <- c(keep_vec, POLICY_ID_LIST$switch_item)
  }
  bool_would_bury <- any(keep_vec %in% state$hand_vec)

  if(bool_gwynn && (bool_would_bury || !bool_lillies)){
    return(POLICY_ID_LIST$gwynn)
  }
  if(bool_lillies) return(POLICY_ID_LIST$lillies)

  NULL
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

  # The two draw Supporters keep their priority-5 ordering here: at the end of
  # the turn nothing is left to bury, so Lillie's larger draw wins unless the
  # hand still holds a piece -- which .draw_supporter() is the one place that
  # decides.
  draw_id <- .draw_supporter(pair)
  if(!is.null(draw_id)) return(draw_id)
  if(POLICY_ID_LIST$lillies %in% state$hand_vec){
    return(POLICY_ID_LIST$lillies)
  }
  if(POLICY_ID_LIST$gwynn %in% state$hand_vec &&
     length(.gwynn_discards(pair)) > 0){
    return(POLICY_ID_LIST$gwynn)
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
  # Her evolution search is aimed at a DUSKNOIR when the Cursed Blast escape is
  # the only route to sub-goal C (section 8): she is the only Supporter that
  # reaches the piece that escape needs, and the condition already requires B to
  # be secured, so the Bronzong is not what the search is for.
  bool_escape <- .escape_is_only_route(pair)
  evo_want_vec <- if(bool_escape){
    c(POLICY_ID_LIST$dusknoir, POLICY_ID_LIST$bronzong)
  } else {
    POLICY_ID_LIST$bronzong
  }
  evo_id <- .first_findable(pair, evo_want_vec, ALLOWED_TARGET_LIST$evolution)
  # "the Energy search takes ANY Energy card when no [P] source is findable,
  # since her text is not restricted to [P]" -- so the preferred three are a
  # ranking, not the whole list, and every remaining Energy in the database
  # follows them. The literal three left **basic Darkness Energy** invisible,
  # and decklist7 and decklist8 run it and no basic Psychic at all: Hilda could
  # log DECLINED with Energy still in the deck, which is precisely the sharp
  # inference the playbook says a whiff licenses.
  energy_want_vec <- c(POLICY_ID_LIST$telepathic, POLICY_ID_LIST$psychic_energy,
                       POLICY_ID_LIST$enriching)
  energy_want_vec <- c(energy_want_vec,
                       setdiff(state$card_df$card_id[
                         state$card_df$category == "energy"], energy_want_vec))
  energy_id <- .first_findable(pair, energy_want_vec,
                               ALLOWED_TARGET_LIST$energy)

  # Whether she is worth the SLOT is a different question, and section 6
  # priority 3 asks this one: a fetch that duplicates a card already held
  # advances no sub-goal, so it does not on its own justify the Supporter.
  # A Dusknoir for the escape is never a duplicate -- it is sub-goal C.
  bool_evo_new <- !is.null(evo_id) &&
    (identical(evo_id, POLICY_ID_LIST$dusknoir) ||
       (!status_vec[["b"]] && !POLICY_ID_LIST$bronzong %in% state$hand_vec))
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
  .walk_want_list(pair, .want_vec(pair), ALLOWED_TARGET_LIST$basic_pokemon, 2L)
}

#' Take up to `num_want` targets by walking a want-list once
#'
#' The shape three multi-target cards share -- Brock's, Buddy-Buddy Poffin and
#' Telepathic Psychic Energy -- factored out because they must agree about one
#' thing that is easy to get wrong in three places independently.
#'
#' **A second Bronzor is never taken.** `docs/03a_card_playbook.md` is explicit
#' that the want-list does not chase one, and that it cost 1.4 points where it
#' used to sit there. But `.want_vec()` emits every Bronzor PRINTING as its own
#' entry, and a loop walking those entries one at a time will happily take one
#' of each: in decklist7, which runs PBL 63 alongside two TEF 68, a single
#' Brock's or Poffin fetched two Bronzor. Invisible on the six single-printing
#' lists, which is why it survived every earlier audit.
#'
#' Only Bronzor is collapsed this way. A second **Duskull** is deliberately fine
#' -- section 4.2 step 6's "take both targets, even when only one is wanted",
#' because a card out of the deck also thins it -- so a blanket name-dedupe
#' would break a rule rather than enforce one.
#' @noRd
.walk_want_list <- function(pair, want_vec, allowed_fn, num_want){
  if(num_want <= 0) return(character(0))
  bronzor_vec <- .bronzor_ids(pair$state$card_df)

  target_vec <- character(0)
  for(one_id in want_vec){
    if(length(target_vec) >= num_want) break
    if(one_id %in% bronzor_vec && any(target_vec %in% bronzor_vec)) next

    found_id <- .first_findable(pair, one_id, allowed_fn)
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

  # Section 8: with the Cursed Blast escape the only route to sub-goal C, the
  # one Evolution worth fetching is the Dusknoir that opens it. Checked before
  # the B guards below, because the escape condition already requires B secured
  # and those guards would otherwise decline the search outright.
  if(.escape_is_only_route(pair)){
    return(.first_findable(pair, POLICY_ID_LIST$dusknoir,
                           ALLOWED_TARGET_LIST$evolution))
  }

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
    bool_wanted <- .bronzor_is_missing(pair) || .c_is_blocked(pair)
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
  if(supporter_id == POLICY_ID_LIST$gwynn){
    # "Up to 2" is literal and an empty discard draws nothing, so a Gwynn with
    # nothing spare to pay with is declined rather than played for zero cards.
    discard_vec <- .gwynn_discards(pair)
    if(length(discard_vec) == 0) return(pair)

    return(play_gwynn(pair, discard_id_vec = discard_vec))
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

  # Section 4.2 step 6: attach only while sub-goal D is unmet, plus its one
  # exception. Positioning has already run by the time this is called, so the
  # primary recipient IS the Pokemon that will attack.
  spot_list <- .energy_recipient(state, bool_active, bench_idx_vec)
  if(is.null(spot_list)) return(pair)

  bool_active <- spot_list$bool_active
  bench_idx <- spot_list$bench_idx
  recipient <- if(bool_active) state$active else state$bench_list[[bench_idx]]

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
                bench_idx = bench_idx,
                search_id_vec = search_vec)
}

#' Which Pokemon the turn's `[P]` source goes onto, or `NULL` for none
#'
#' Section 4.2 step 6 and its one exception, split out of
#' \code{.policy_energy()} so the rule reads as a rule rather than as two early
#' returns inside an attachment.
#'
#' The **primary** recipient is the line itself -- the Active Bronzor or
#' Bronzong when there is one, else the first benched -- and it takes the Energy
#' only while it carries none. One `[P]` source is the whole cost of Evolution
#' Jammer, so a second onto the same body buys nothing but Telepathic's search,
#' whose two fetches land in the Bench slots section 4.4 is holding.
#'
#' The **exception** is a *second Bronzong* carrying nothing: the spare goes
#' there, and the turn ends with two Bronzong each able to attack. A second
#' **Bronzor** is deliberately not a home for it -- an Energy on a Bronzor is
#' not an attacker, and the Bench slots the search would fill are worth more.
#'
#' @param state a `"bronzong_state"`.
#' @param bool_active whether the Active is a Bronzor or Bronzong.
#' @param bench_idx_vec Bench slots holding a Bronzor or Bronzong.
#'
#' @returns A list with `bool_active` and `bench_idx`, or `NULL`.
#' @noRd
.energy_recipient <- function(state, bool_active, bench_idx_vec){
  # Among several benched members of the line, prefer a `[P]` one: the playbook
  # says "with both a Metal and a `[P]` Bronzor available, put it on the `[P]`
  # one so the search fires". Taking bench_idx_vec[1] -- board order -- let a
  # Metal Bronzor in the first slot swallow the attachment and fire nothing.
  # Only reachable since decklist7 paired PBL 63 (Metal, 80 HP) with TEF 68.
  if(length(bench_idx_vec) > 1){
    ptype_vec <- sapply(state$bench_list[bench_idx_vec], function(one){
      lookup_card(state$card_df, top_card(one))$ptype
    })
    bool_psychic_vec <- !is.na(ptype_vec) & ptype_vec == "psychic"
    bench_idx_vec <- bench_idx_vec[order(!bool_psychic_vec)]
  }

  primary <- if(bool_active) state$active else
    state$bench_list[[bench_idx_vec[1]]]

  if(!.has_psychic_attached(state, primary)){
    return(list(bool_active = bool_active,
                bench_idx = if(bool_active) NA_integer_ else bench_idx_vec[1]))
  }

  # `bool_active` already says the Active is the line, so an Active Bronzong is
  # the primary and cannot also be the second one; only the Bench is left.
  for(one_idx in .bench_idx_named(state, "Bronzong")){
    if(!.has_psychic_attached(state, state$bench_list[[one_idx]])){
      return(list(bool_active = FALSE, bench_idx = one_idx))
    }
  }

  NULL
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

  # The sub-goal want-list first: these are fetched because we need them.
  target_vec <- .walk_want_list(pair, .want_vec(pair, bool_to_hand = FALSE),
                                ALLOWED_TARGET_LIST$telepathic, num_want)
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

  # The Items may have changed what is available; re-check rather than assume,
  # and re-check BOTH halves rather than only the Bronzor.
  #
  # The second guard is not theoretical. Ultra Ball protects Salvatore only
  # while the kill line is live, and liveness reads believes_findable() -- so a
  # search that takes the last Bronzong out of the DECK (into hand, where
  # Salvatore cannot reach it and turn 1 cannot evolve it) makes the line dead
  # mid-turn and releases the Salvatore onto the discard order. Meanwhile
  # is_salvatore_target() answers on PUBLIC information and keeps a prized
  # Bronzong declarable, so it stays TRUE and is no substitute for holding the
  # card: the pair crashed play_salvatore() with "card TEF-160 is not in zone
  # 'hand'" the first time a lead order made that sequence common.
  if(!.active_is(pair$state, "Bronzor")) return(.policy_build_turn(pair))
  if(!POLICY_ID_LIST$salvatore %in% pair$state$hand_vec ||
     !can_play_supporter(pair$state)){
    return(.policy_build_turn(pair))
  }

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

  # Section 4.2 step 7 and section 8, both AHEAD of the fallback -- because
  # section 6 priority 8 says the fallback fires "after every other play of the
  # turn has resolved, so Lillie's never shuffles away a card the turn still
  # meant to use", and both of these used to run after it.
  #
  # The Rare Candy is the one that actually lost a card. Section 4.4's
  # bench-before-Lillie's rule saves BASICS, and the Dusknoir section 8 needs is
  # a Stage 2, so a fallback Lillie's shuffled it into the deck and the
  # evolution never happened at all. The Stadium is the same shape, one card
  # cheaper. Both are board-record plays, so neither wants what the fallback
  # draws and neither loses anything by going first.
  pair <- .policy_stadium(pair)
  pair <- .policy_leftover_rare_candy(pair)

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
  # Both again, over whatever the fallback drew: a Stadium or a Rare Candy in
  # those eight cards is as playable as one that was already in hand, and each
  # call is idempotent -- the Stadium checks its once-per-turn flag and the Rare
  # Candy needs both its cards still in hand.
  pair <- .policy_stadium(pair)
  pair <- .policy_leftover_rare_candy(pair)
  # Section 5 step 6: Pokegear last of all, and it shuffles.
  pair <- .policy_pokegear(pair)

  # Section 4.2: Run Around only as a last resort, after every other play, and
  # only when it does not cost the [P] source sub-goal D needs. Asked BEFORE the
  # Enriching, because section 4.2 pays Run Around with the Enriching by
  # preference -- spending it first would strand rung 4 of the ladder for a
  # draw.
  pair <- .policy_run_around(pair)
  # Section 4.2 step 6, second exception: the attachment of last resort.
  pair <- .policy_enriching(pair)

  if(can_use_evolution_jammer(pair$state)){
    return(attack_evolution_jammer(pair))
  }

  pair
}

#' Enriching Energy, for an attachment nothing else can use
#'
#' Section 4.2 step 6's second exception. Enriching provides `[C]`, so it never
#' pays sub-goal D and never displaces a `[P]` source -- but the attachment is a
#' per-turn resource that carries no credit forward, exactly like the Supporter
#' slot, and at this point in the turn nothing else is going to claim it.
#' Attaching draws **4**.
#'
#' Called last on purpose: after every `[P]` source has had its claim
#' (\code{.policy_energy()}, twice, inside \code{.policy_assemble()}), after the
#' Supporter whose fetch could still have turned one up, and after Run Around,
#' which section 4.2 pays with this very card by preference.
#'
#' **The recipient is chosen so the card is not merely parked.** Latias ex
#' first, then any body that is not the line, and the Bronzor or Bronzong only
#' if there is nothing else: `[C]` on the attacker buys nothing Evolution Jammer
#' can spend, whereas `[C]` on a Latias ex is an attack cost some turn past the
#' window could pay.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @noRd
.policy_enriching <- function(pair){
  state <- pair$state
  if(!can_act(state)) return(pair)
  if(!can_attach_energy(state)) return(pair)
  if(!POLICY_ID_LIST$enriching %in% state$hand_vec) return(pair)

  in_play_list <- all_in_play(state)
  if(length(in_play_list) == 0) return(pair)

  name_vec <- sapply(in_play_list, function(one){
    lookup_card(state$card_df, top_card(one))$name
  })
  # Three tiers plus the line, as section 4.2 step 6 and the playbook both write
  # it: "Latias ex first, then another `[C]` attacker, and only then anything
  # else" -- and never the attacker. A two-tier version tied a Duskull with a
  # Mega Kangaskhan ex and let `which.min()` settle it by Bench order.
  ptype_vec <- sapply(in_play_list, function(one){
    lookup_card(state$card_df, top_card(one))$ptype
  })
  rank_vec <- ifelse(name_vec == "Latias ex", 1L,
                     ifelse(name_vec %in% c("Bronzor", "Bronzong"), 4L,
                            ifelse(!is.na(ptype_vec) &
                                     ptype_vec == "colorless", 2L, 3L)))
  target_idx <- which.min(rank_vec)

  # all_in_play() puts the Active first when there is one, so index 1 is the
  # Active and the rest map onto Bench slots in order.
  bool_active <- !is.null(state$active) && target_idx == 1L
  bench_idx <- if(bool_active) NA_integer_ else
    target_idx - as.integer(!is.null(state$active))

  attach_energy(pair, POLICY_ID_LIST$enriching,
                target_is_active = bool_active,
                bench_idx = bench_idx)
}

#' Rare Candy a benched Duskull once Bronzong is settled either way
#'
#' Section 8. The non-goal is about *order*, not about the card: Bronzong first,
#' always; Dusknoir with what is left over. Once B has been resolved -- the
#' evolution has happened, or the turn has established that it cannot -- the
#' Rare Candy and the Dusknoir have nothing to compete with, and the
#' end-of-turn-2 board (ADR 0007) is worth more with a Dusknoir on it than with
#' two cards in hand. The metric does not move either way.
#'
#' **Turn 2 only.** On turn 1 both cards still have jobs: the rung-5 escape
#' (section 4.3) needs exactly this pair, and spending them a turn early is how
#' a turn-2 Duskull Active ends up with no door.
#'
#' **Never the Active**, whose only job on turn 2 is to be the Bronzong.
#'
#' @param pair a `list(state, knowledge)`.
#'
#' @returns The updated pair.
#' @noRd
.policy_leftover_rare_candy <- function(pair){
  state <- pair$state
  if(state$turn_number != 2L) return(pair)
  if(!can_act(state)) return(pair)
  if(!can_play_item(state)) return(pair)
  if(!POLICY_ID_LIST$rare_candy %in% state$hand_vec) return(pair)
  if(!POLICY_ID_LIST$dusknoir %in% state$hand_vec) return(pair)
  if(!.bronzong_is_settled(pair)) return(pair)

  for(one_idx in .bench_idx_named(state, "Duskull")){
    if(can_rare_candy(state, state$bench_list[[one_idx]],
                      POLICY_ID_LIST$dusknoir)){
      return(play_rare_candy(pair, stage2_card_id = POLICY_ID_LIST$dusknoir,
                             target_is_active = FALSE, bench_idx = one_idx))
    }
  }

  pair
}

#' Has this turn finished with sub-goal B, one way or the other?
#'
#' Section 8's "settled either way". Three states count as settled: a Bronzong
#' is in play; no Bronzong is in hand to play; or one is in hand and no Bronzor
#' in play can legally take it this turn -- a Bronzor played this turn cannot be
#' evolved from hand (ADR 0001), and with no Bronzor at all the card is simply
#' dead until the window closes.
#'
#' Distinct from \code{.bronzong_cannot_evolve()}, which answers the narrower
#' question section 6 priority 2 asks and returns `FALSE` when no Bronzor is in
#' play at all -- the opposite of what "settled" means here.
#' @noRd
.bronzong_is_settled <- function(pair){
  state <- pair$state
  if(.subgoal_status(state)[["b"]]) return(TRUE)
  if(!POLICY_ID_LIST$bronzong %in% state$hand_vec) return(TRUE)

  in_play_list <- c(if(.active_is(state, "Bronzor")) list(state$active),
                    state$bench_list[.bench_idx_named(state, "Bronzor")])
  if(length(in_play_list) == 0) return(TRUE)

  !any(sapply(in_play_list, function(one){
    can_evolve(state, one, POLICY_ID_LIST$bronzong)
  }))
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
  # Section 4.2 step 7 plays a Stadium only when it is NOT disruptive to us.
  # Two are: Mystery Garden would cost a [P] source to draw, and Risky Ruins
  # puts 2 damage counters on every Basic non-[D] Pokemon ANY player benches --
  # which, with no opposing board modelled, means only ours.
  stadium_vec <- setdiff(stadium_vec, c("MEG-122",
                                        POLICY_ID_LIST$risky_ruins))
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
#' @param lead_order_list the section 3 lead order, as in
#'   \code{policy_placement()}. A run varies this; a replicate does not.
#' @param scenario the opponent model; `"clear"` or `"item_lock"`.
#' @param seed_number integer seed, or `NULL` to leave the RNG stream alone.
#'
#' @returns The finished `list(state, knowledge)` pair, ready for
#'   \code{summarise_replicate()}.
#' @export
play_replicate <- function(decklist,
                           card_df,
                           bool_going_first,
                           lead_order_list = LEAD_ORDER_LIST,
                           scenario = "clear",
                           seed_number = NULL){
  pair <- setup_game(decklist, card_df,
                     bool_going_first = bool_going_first,
                     placement_fn = make_policy_placement(lead_order_list),
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
