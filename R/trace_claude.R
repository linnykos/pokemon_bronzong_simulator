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
# MISS is nearly useless; one that says "MISS, C unmet, and a playable Switch was
# in hand" identifies a policy bug in one line. That is what `unmet_vec`,
# `motif_vec` and `unused_out_vec` are for.
#
# Two lessons from auditing this file are worth keeping in view:
#   - Reporting only the FIRST unmet sub-goal hid the very hypothesis the
#     project set out to test. Report the set.
#   - A residue check ("was it left in hand?") cannot see a card that was played
#     WRONGLY, and its firing rate tracks hand size. Motifs cover that gap.

# ---------------------------------------------------------------------------
# Diagnosis
# ---------------------------------------------------------------------------

#' The four sub-goals of the target event
#'
#' From docs/03_decision_tree.md section 1. The letters are ordered for
#' readability only: the diagnosis reports the SET of unmet sub-goals, because
#' reporting just the first made C -- the goal the decision tree names as the one
#' that actually fails -- look as though it never failed at all.
#'
#' @export
SUBGOAL_VEC <- c(A = "bronzor_in_play",
                 B = "bronzong_on_it",
                 C = "bronzong_active",
                 D = "psychic_attached")

#' Which sub-goals were unmet when the window closed?
#'
#' Returns the SET, not just the first. Reporting only the first unmet sub-goal
#' looked tidier and was actively misleading: because the order is A, B, C, D,
#' sub-goal C could only ever be reported when A and B both held, so a run in
#' which 106 of 322 misses had a Bronzor or Bronzong in play and not Active
#' reported `C: 1`. An agent reading that concluded the decision tree's central
#' hypothesis -- "C is the sub-goal that actually fails" -- was refuted, when in
#' fact it was masked by the reporting rule.
#'
#' Each predicate is therefore defined so it is meaningful on its own, without
#' assuming the earlier ones hold:
#'
#' - **A** some Bronzor or Bronzong is in play
#' - **B** some Bronzong is in play
#' - **C** a Bronzong is in the **Active** spot
#' - **D** some Bronzong in play carries a `[P]` source
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#'
#' @returns A character vector of unmet sub-goal letters, in A-D order; empty
#'   when all four are met (in which case the miss was a failure to declare the
#'   attack, not a missing piece -- exactly the case ADR 0004 exists to expose).
#' @export
unmet_subgoals <- function(state){
  stopifnot(inherits(state, "bronzong_state"))

  in_play_list <- all_in_play(state)
  name_vec <- if(length(in_play_list) == 0) character(0) else
    sapply(in_play_list, function(one){
      lookup_card(state$card_df, top_card(one))$name
    })
  top_vec <- if(length(in_play_list) == 0) character(0) else
    sapply(in_play_list, top_card)

  # A Bronzong satisfies A implicitly: it can only have got there on a Bronzor.
  bool_a <- any(name_vec %in% c("Bronzor", "Bronzong"))
  bool_b <- any(top_vec == "TEF-069")
  bool_c <- !is.null(state$active) && top_card(state$active) == "TEF-069"
  bool_d <- bool_b && any(sapply(in_play_list, function(one){
    top_card(one) == "TEF-069" && has_evolution_jammer_cost(state, one)
  }))

  met_vec <- c(A = bool_a, B = bool_b, C = bool_c, D = bool_d)

  names(met_vec)[!met_vec]
}

#' The first unmet sub-goal
#'
#' A convenience rollup of \code{unmet_subgoals()}. Kept because a single label
#' is useful for sorting, but it is named `first_unmet` everywhere it is
#' reported so nobody reads it as "the cause".
#'
#' @param state a `"bronzong_state"`.
#'
#' @returns A single letter, or `NA` when all four sub-goals were met.
#' @export
blocking_subgoal <- function(state){
  unmet_vec <- unmet_subgoals(state)
  if(length(unmet_vec) == 0) return(NA_character_)

  unmet_vec[1]
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
unused_outs <- function(state, subgoal_vec){
  stopifnot(inherits(state, "bronzong_state"))
  subgoal_vec <- subgoal_vec[!is.na(subgoal_vec)]
  if(length(subgoal_vec) == 0) return(character(0))

  # Cards that advance each sub-goal, per docs/03_decision_tree.md section 1.
  #
  # Corrections the audit forced, all of which pointed the reader at the wrong
  # thing:
  #  - Hilda was listed under A. Hilda fetches "an Evolution Pokemon and an
  #    Energy card"; Bronzor is a Basic, so Hilda can NEVER fix A. Removed.
  #  - Buddy-Buddy Poffin was listed under A unconditionally. It caps at 70 HP
  #    and every shipped decklist runs the 80 HP Bronzor, so it is only an out
  #    when a <=70 HP Bronzor is in the list -- checked at run time below.
  #  - A Bronzor IN HAND was missing from A entirely, which is the cheapest out
  #    there is: bench it, free. The flag was reporting the card that could not
  #    help while staying silent about the one that could.
  #  - Latias ex was missing from C. Skyliner zeroes a Basic Active's retreat,
  #    which section 1 lists as an out for C.
  #  - The three Bronzor printings under A were a hand-maintained LITERAL, and
  #    Bronzor PBL 63 arrived with decklist7 and decklist8 as a fourth. It was
  #    invisible to the diagnosis, so a trace could report "no unused out" with
  #    a Bronzor sitting in hand -- which reads as a DECK problem when it is a
  #    DECISION problem. Under-reporting is the worst variant of the
  #    confidently-wrong-diagnostic failure, because it raises nothing at all.
  #    Resolved by NAME at run time now, the way .bronzor_ids() already does in
  #    the policy, so a fifth printing cannot reintroduce it.
  bronzor_vec <- state$card_df$card_id[state$card_df$name == "Bronzor"]
  out_list <- list(
    A = c(bronzor_vec, "POR-081", "MEG-131", "TEF-144", "JTG-146", "POR-088"),
    B = c("TEF-069", "TEF-160", "WHT-084", "JTG-146", "POR-081", "MEG-131"),
    # MEG-125 (Rare Candy) is an out for C only through the Cursed Blast escape
    # -- Duskull Active, Rare Candy to Dusknoir, self-Knock Out, promote a
    # benched Bronzor (docs/03_decision_tree.md section 8). Every condition of
    # that line is checked in .out_can_serve(); without the entry the escape is
    # invisible to the traces, and without the conditions it would be the
    # loosest false accusation in the file.
    C = c("MEG-130", "SSP-187", "SSP-076", "MEG-125"),
    D = c("SVE-005", "POR-088", "WHT-084"))

  candidate_vec <- unique(unlist(out_list[subgoal_vec]))
  in_hand_vec <- unique(intersect(state$hand_vec, candidate_vec))
  if(length(in_hand_vec) == 0) return(character(0))

  in_hand_vec[sapply(in_hand_vec, function(one_id){
    served_vec <- subgoal_vec[sapply(subgoal_vec, function(one_goal){
      one_id %in% out_list[[one_goal]]
    })]

    .out_is_playable(state, one_id) && .out_can_serve(state, one_id, served_vec)
  })]
}

#' Could this out advance one of the sub-goals it was nominated for?
#'
#' Separate from \code{.out_is_playable()}, which asks only whether the card
#' could legally be played at all. A card can be perfectly playable and still be
#' useless for the particular sub-goal that is blocked, and flagging it charges
#' the decision tree for a play that would not have helped.
#'
#' @param state a `"bronzong_state"`.
#' @param card_id the candidate out, known to be in hand and playable.
#' @param served_vec the unmet sub-goals this card is listed under.
#'
#' Reads `deck_vec` -- ground truth -- as the Buddy-Buddy Poffin check already
#' does. That is legitimate here and nowhere else: this is analysis output
#' computed after the window has closed, not an input the policy may consult
#' (ADR 0003).
#'
#' @returns A single logical; TRUE unless a card/sub-goal pair has a known
#'   extra condition.
#' @noRd
.out_can_serve <- function(state, card_id, served_vec){
  # Telepathic Psychic Energy reaches sub-goal A only through its search, and
  # that search fires solely when the RECIPIENT is [P] -- see
  # .telepathic_psychic_trigger(). On an all-Colorless board the attachment is
  # legal and the search is dead, so calling it an unused out for A charges the
  # tree for exactly the play the `telepathic_on_colorless` motif warns against.
  #
  # It remains an unconditional out for D, where it is wanted as a [P] SOURCE:
  # attaching it to a Metal Bronzor searches nothing and still carries a [P]
  # through evolution.
  if(card_id == "POR-088" && identical(served_vec, "A")){
    ptype_vec <- sapply(all_in_play(state), function(one){
      lookup_card(state$card_df, top_card(one))$ptype
    })

    return(any(!is.na(ptype_vec) & ptype_vec == "psychic"))
  }

  # Rare Candy reaches sub-goal C only through the Cursed Blast escape, which
  # needs the whole line to be there at once: a Duskull Active that Rare Candy
  # may legally evolve, a Dusknoir left in the deck, and a Bronzor or Bronzong
  # on the Bench to promote. Any one missing and the card could not have
  # advanced C, so flagging it would accuse the decision tree of declining a
  # play that did not exist.
  if(card_id == "MEG-125" && "C" %in% served_vec){
    if(is.null(state$active)) return(FALSE)
    if(top_card(state$active) != "PRE-035") return(FALSE)
    # can_rare_candy() now covers the Dusknoir being IN HAND, which is where
    # Rare Candy takes it from. This branch previously asked for it in the DECK
    # and so was inverted: it flagged the escape only when it was impossible.
    if(!can_rare_candy(state, state$active, "PRE-037")) return(FALSE)

    # And C is `bronzong_active`, not `bronzor_active`. Promoting a bare Bronzor
    # does not meet it, so the promotion target must either be a Bronzong
    # already, or a Bronzor that can legally evolve this turn with a Bronzong in
    # hand to do it. Accepting any Bronzor was the same false accusation this
    # file has now made three times.
    bool_serves_vec <- sapply(state$bench_list, function(one){
      if(top_card(one) == "TEF-069") return(TRUE)

      lookup_card(state$card_df, top_card(one))$name == "Bronzor" &&
        "TEF-069" %in% state$hand_vec &&
        can_evolve(state, one, "TEF-069")
    })

    return(any(unlist(bool_serves_vec)))
  }

  TRUE
}

#' Could this out actually have been played?
#'
#' The audit's worst finding: the check was a bare `intersect(hand, outs)`, so
#' every unplayable card in hand was charged to the decision tree. In the
#' `item_lock` cell **56% of the reported "decision defects" were the Item lock
#' itself** -- a rule, not a choice -- and in the `clear` cell every single
#' flagged Telepathic Psychic Energy sat behind an already-spent attachment.
#'
#' Evaluated on the END state, which is later than the moment the decision was
#' actually taken. That makes this a conservative test: it can still miss a card
#' that was playable earlier and is not now. Under-reporting is the right
#' direction for a flag whose whole purpose is to accuse the decision tree.
#'
#' @param state a `"bronzong_state"`.
#' @param card_id the candidate out, known to be in hand.
#'
#' @returns A single logical.
#' @noRd
.out_is_playable <- function(state, card_id){
  if(!can_act(state)) return(FALSE)

  card_id <- canonical_card_id(card_id)
  row_df <- lookup_card(state$card_df, card_id)

  if(row_df$category == "energy") return(can_attach_energy(state))

  if(row_df$category == "pokemon"){
    # A Basic in hand is an out only if there is room to bench it; an Evolution
    # only if a legal base is in play.
    if(row_df$stage == "basic") return(has_bench_space(state))

    return(any(sapply(all_in_play(state), function(one){
      can_evolve(state, one, card_id)
    })))
  }

  if(!is.na(row_df$subtype) && row_df$subtype == "supporter"){
    return(can_play_supporter(state))
  }
  if(!can_play_item(state)) return(FALSE)

  # Item-specific costs, each of which can make the card unplayable while it
  # sits in hand looking available.
  if(card_id == "MEG-131"){
    return(length(state$hand_vec) >= 3)
  }
  if(card_id == "TEF-144"){
    # A <=70 HP BRONZOR, not merely a <=70 HP Basic. Poffin is only ever listed
    # as an out for sub-goal A, and Duskull (60), Buneary (70) and Budew (30)
    # all pass a bare HP test while doing nothing for A -- so against a list
    # running only the 80 HP TEF-068 the flag accused the decision tree of not
    # playing a card that could not possibly have helped.
    deck_df <- lookup_card(state$card_df, state$deck_vec)
    bool_target <- any(deck_df$name == "Bronzor" & !is.na(deck_df$hp) &
                         deck_df$hp <= 70)
    return(bool_target && has_bench_space(state))
  }
  if(card_id == "MEG-130") return(length(state$bench_list) > 0)

  TRUE
}

# ---------------------------------------------------------------------------
# Replicate results
# ---------------------------------------------------------------------------

#' Play-motifs worth counting across a whole run
#'
#' The single highest-value addition the usability audit asked for. An agent
#' reading 16 traces reported that it stopped reading them narratively and
#' started counting substrings, and that the counting is what produced its main
#' finding -- so the file should ship the counts rather than make every reader
#' re-derive them. Two lines like
#' "Telepathic attached to a Colorless body: 108/322" convey more than the
#' traces they summarise.
#'
#' Detected from the event log, so a motif is cheap to compute for EVERY
#' replicate even when no trace is kept.
#'
#' @export
MOTIF_VEC <- c(
  telepathic_on_colorless = "Telepathic attached to a Colorless body (search dead)",
  search_declined = "a search resolved with no target named",
  never_promoted = "Bronzor/Bronzong in play but never made Active",
  supporter_slot_unused = "a turn ended with the Supporter slot unspent",
  attack_never_declared = "combo assembled but Evolution Jammer never declared")

#' Detect play-motifs in a finished replicate
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#' @param unmet_vec the unmet sub-goals from \code{unmet_subgoals()}.
#'
#' @returns A character vector of motif names present.
#' @export
detect_motifs <- function(state, unmet_vec){
  stopifnot(inherits(state, "bronzong_state"))

  log_str <- paste0(state$event_log, collapse = " | ")
  motif_vec <- character(0)

  if(grepl("recipient not [P]", log_str, fixed = TRUE)){
    motif_vec <- c(motif_vec, "telepathic_on_colorless")
  }
  if(grepl("DECLINED (no target named)", log_str, fixed = TRUE)){
    motif_vec <- c(motif_vec, "search_declined")
  }
  # A is met but C is not: the piece was on the board and never promoted. This
  # is the motif that the old first-unmet-only reporting hid completely.
  #
  # The Active must ALSO not already be part of the line. "A met, C unmet" is
  # equally true of a Bronzor that led at setup and was simply never evolved --
  # a sub-goal B failure, with nothing to promote and no positioning mistake in
  # it. Counting those under a label that reads "never made Active" inflated the
  # tally by every such replicate (demo seed 13 was one), under a heading that
  # tells the reader these are the counts worth acting on.
  if(!"A" %in% unmet_vec && "C" %in% unmet_vec &&
     !.active_is_bronzong_line(state)){
    motif_vec <- c(motif_vec, "never_promoted")
  }
  if(length(unmet_vec) == 0 && is.na(state$jammer_turn)){
    motif_vec <- c(motif_vec, "attack_never_declared")
  }
  if(length(.turns_with_supporter_unspent(state)) > 0){
    motif_vec <- c(motif_vec, "supporter_slot_unused")
  }

  motif_vec
}

#' Is the Active already part of the Bronzor/Bronzong line?
#'
#' Distinguishes "the piece is benched and was never promoted" (a positioning
#' defect) from "the piece is Active and was never evolved" (a B defect).
#' @noRd
.active_is_bronzong_line <- function(state){
  if(is.null(state$active)) return(FALSE)

  lookup_card(state$card_df, top_card(state$active))$name %in%
    c("Bronzor", "Bronzong")
}

#' Turns that ended with the Supporter slot unspent
#'
#' Asked PER TURN, which is what the motif's own description claims and what the
#' old check did not do: it grepped the whole event log for any Supporter, so a
#' replicate that played Hilda on turn 1 and wasted turn 2's slot was never
#' flagged -- the more interesting of the two cases, and silently invisible.
#'
#' Read from the canonical `supporter played` event that
#' `.play_supporter_from_hand()` writes, not from the card's own log line. The
#' old check grepped a hard-coded list of names that the effects do not actually
#' log -- they log labels like "Hilda (evolution)" and "Codebreaking stacked" --
#' and it omitted Boss's Orders, which decklist2 runs 2 copies of.
#'
#' Turn 1 going first is excluded: no Supporter is legal then
#' (docs/01_rules_standard.md section 6), so an unspent slot is a rule, not a
#' choice -- the same distinction that stopped `unused_outs()` charging the Item
#' lock to the decision tree.
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#'
#' @returns An integer vector of this player's turn numbers, empty when every
#'   turn that could spend a Supporter did.
#' @noRd
.turns_with_supporter_unspent <- function(state){
  played_turn_vec <- integer(0)
  if(length(state$event_log) > 0){
    bool_played_vec <- grepl("supporter played ", state$event_log, fixed = TRUE)
    played_turn_vec <- unique(state$event_turn_vec[bool_played_vec])
  }

  turn_vec <- seq_len(state$turn_number)
  if(state$bool_going_first) turn_vec <- setdiff(turn_vec, 1L)

  as.integer(setdiff(turn_vec, played_turn_vec))
}

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
#'     \item{lead_card_id}{the Basic that led at setup, so a run can be grouped
#'       by it; see \code{summarise_run()}'s `lead_hit_df`.}
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

  bool_hit <- !is.na(state$jammer_turn) && state$jammer_turn <= 2L

  # Diagnose every non-hit, including a LATE attack (turn 3+). The tally used to
  # skip those, so the per-sub-goal counts silently failed to add up to the miss
  # count and a reader summing them got an unexplained residual.
  unmet_vec <- if(bool_hit) character(0) else unmet_subgoals(state)

  result <- structure(
    list(decklist_id = decklist_id,
         scenario = state$scenario,
         bool_going_first = state$bool_going_first,
         seed_number = as.integer(seed_number),
         jammer_turn = state$jammer_turn,
         # Carried on EVERY replicate, not just traced ones: the lead order is
         # deferred to the logs (docs/03_decision_tree.md section 3), and ADR
         # 0006 forbids reading a rate off the traces, so it can only come
         # from an aggregate over all of them.
         lead_card_id = state$lead_card_id,
         # ADR 0004: the bar is the player's own turn 2, and it is the ATTACK
         # that counts, not the attack merely having been available.
         bool_hit = bool_hit,
         num_mulligans = state$num_mulligans,
         bool_mulliganed = state$num_mulligans > 0L,
         unmet_vec = unmet_vec,
         first_unmet = if(length(unmet_vec) == 0) NA_character_ else unmet_vec[1],
         motif_vec = if(bool_hit) character(0) else detect_motifs(state, unmet_vec),
         unused_out_vec = unused_outs(state, unmet_vec),
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

  # NOTE: this used to index SUBGOAL_VEC[[blocking_subgoal]] unguarded, which
  # threw "subscript out of bounds" whenever all four sub-goals were met and the
  # attack was simply never declared -- i.e. precisely the case ADR 0004 exists
  # to expose. A driver that keeps traces would have died on the first such
  # replicate, killing a whole 10,000-replicate run.
  verdict_str <- if(result$bool_hit){
    paste0("HIT t", result$jammer_turn)
  } else if(!is.na(result$jammer_turn)){
    paste0("LATE t", result$jammer_turn)
  } else if(length(result$unmet_vec) == 0){
    "MISS unmet=none (combo assembled, attack never declared)"
  } else {
    paste0("MISS unmet=", paste0(result$unmet_vec, collapse = ","),
           " first=", result$first_unmet)
  }

  # `mull=` and the scenario/side are omitted when they carry no information:
  # they are file-level constants repeated on every trace otherwise.
  header_str <- paste0("#", result$seed_number,
                       if(result$num_mulligans > 0)
                         paste0(" mull=", result$num_mulligans) else "",
                       "  ", verdict_str)

  # The unused-out line separates "the deck did not give me the card" from "I
  # had the card, could have played it, and did not".
  unused_str <- if(length(result$unused_out_vec) > 0){
    paste0("  !! PLAYABLE OUT unused: ",
           paste0(.short_name(card_df, result$unused_out_vec), collapse = ", "))
  } else NULL

  # Motifs catch the defects the residue check cannot see -- notably a card that
  # was MISPLAYED rather than left in hand, which leaves no residue at all.
  motif_str <- if(length(result$motif_vec) > 0){
    paste0("  !! ", MOTIF_VEC[result$motif_vec])
  } else NULL

  c(header_str, unused_str, motif_str, .turn_lines(state), .board_block(state))
}

#' The end-of-window board state, in full
#'
#' Kevin, 2026-08-29: do not record past the end of turn 2, but be *thorough* at
#' the end of turn 2, because what the board looks like by then is a question he
#' wants to ask later. So this reports every zone rather than the one
#' Active-and-Bench line it used to, and the policy is expected to keep playing
#' the turn out properly even once the metric is lost -- see
#' docs/03_decision_tree.md section 7.
#'
#' The prize line is GROUND TRUTH. ADR 0003 forbids the POLICY from reading the
#' prizes; it does not forbid the analysis from recording them, and "both
#' Bronzong prized" is the one line that separates a variance miss from a
#' decision defect. It is labelled in the file itself so that nobody reads the
#' field's existence as permission to wire it into part 5.
#'
#' @param state a `"bronzong_state"` at the end of the measured window.
#'
#' @returns A character vector of trace lines.
#' @noRd
.board_block <- function(state){
  card_df <- state$card_df

  bench_str <- if(length(state$bench_list) == 0) "-" else
    paste0(sapply(state$bench_list, function(one){
      .in_play_str(card_df, one)
    }), collapse = " | ")

  # `items=` is asked of items_are_locked() rather than can_play_item(), which
  # is FALSE once the turn is over -- i.e. in every trace -- and so would report
  # a lock in the `clear` scenario too.
  c(paste0("  end of turn ", state$turn_number,
           " -- board state when the window closed; setup lead=",
           if(is.na(state$lead_card_id)) "-" else
             .short_name(card_df, state$lead_card_id)),
    paste0("    active   ", if(is.null(state$active)) "-" else
      .in_play_str(card_df, state$active)),
    paste0("    bench    ", bench_str),
    paste0("    hand     ", .zone_str(card_df, state$hand_vec)),
    paste0("    discard  ", .zone_str(card_df, state$discard_vec)),
    paste0("    zones    deck=", length(state$deck_vec),
           " prizes=", length(state$prize_vec),
           " stadium=", if(is.na(state$stadium)) "-" else
             .short_name(card_df, state$stadium)),
    paste0("    turn     energy=",
           if(isTRUE(state$turn_flag_list$bool_energy_attached))
             "spent" else "unspent",
           " supporter=",
           if(isTRUE(state$turn_flag_list$bool_supporter_played))
             "played" else "unplayed",
           " items=", if(items_are_locked(state)) "locked" else "open"),
    paste0("    prized   GROUND TRUTH, never visible to the policy (ADR 0003): ",
           .zone_str(card_df, state$prize_vec)))
}

#' One in-play Pokemon, with everything that is true of it
#'
#' `played` and `evo` are here because the end state alone cannot say whether a
#' Bronzong arrived on turn 1 or turn 2, and that is exactly the difference
#' between a Salvatore line and a conventional one.
#' @noRd
.in_play_str <- function(card_df, in_play){
  # The whole stack, bottom to top. Which Bronzor is UNDER a Bronzong is not
  # cosmetic: it decides whether Buddy-Buddy Poffin (<=70 HP) or Telepathic
  # Psychic Energy ([P] only) could have found it, so a board state that names
  # only the top card cannot be reasoned about after the fact.
  under_str <- if(length(in_play$stack_vec) == 1) "" else
    paste0(paste0(.short_name(card_df,
                              in_play$stack_vec[-length(in_play$stack_vec)]),
                  collapse = ">"), ">")

  paste0(under_str,
         .typed_name(card_df, top_card(in_play)),
         .energy_suffix(card_df, in_play),
         if(in_play$damage > 0) paste0(" dmg=", in_play$damage) else "",
         " played=T", in_play$turn_played,
         if(is.na(in_play$turn_evolved)) "" else
           paste0(" evo=T", in_play$turn_evolved))
}

#' A zone's contents as short names, or "-" when empty
#' @noRd
.zone_str <- function(card_df, card_id_vec){
  if(length(card_id_vec) == 0) return("-")

  paste0(.short_name(card_df, card_id_vec), collapse = ", ")
}

# ---------------------------------------------------------------------------
# Trace sampling
# ---------------------------------------------------------------------------

#' One turn's decisions, in readable form
#'
#' The event log stores card ids because they are unambiguous; anything a person
#' reads wants names. \code{format_trace()} does this substitution internally for
#' trace file, and the demo needs the same for a single turn, so it is
#' exposed here rather than copied.
#'
#' Level-2 entries (zone moves, shuffles, draws) are dropped: they triple the
#' length and bury the decisions, which are the point.
#'
#' @param state a `"bronzong_state"`.
#' @param turn_number which of this player's turns to show; `NA` for all.
#'
#' @returns A character vector of log lines, without the turn prefix.
#' @export
readable_log <- function(state, turn_number = NA_integer_){
  stopifnot(inherits(state, "bronzong_state"))

  keep_vec <- state$event_level_vec == 1L
  if(!is.na(turn_number)){
    keep_vec <- keep_vec & state$event_turn_vec == turn_number
  }
  if(!any(keep_vec)) return(character(0))

  message_vec <- sub("^T[0-9-]+: ", "", state$event_log[keep_vec])
  message_vec <- .substitute_card_names(state$card_df, message_vec)

  message_vec[!grepl("^begin turn", message_vec)]
}

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
write_trace_file <- function(result_list, file_path, summary_list,
                             decklist = NULL){
  stopifnot(is.list(result_list))
  # Requiring the class stops the sample being passed as its own summary, which
  # would print a rate derived from the traces -- the exact trap ADR 0006 names.
  if(!inherits(summary_list, "bronzong_summary")){
    stop("`summary_list` must come from summarise_run() over EVERY replicate, ",
         "not from the retained traces")
  }
  if(summary_list$num_replicates < length(result_list)){
    stop("`summary_list` covers ", summary_list$num_replicates,
         " replicates but ", length(result_list), " traces were kept; the ",
         "summary must be over the whole run")
  }

  num_miss <- summary_list$num_miss
  line_vec <- c(
    "# Decision traces -- read the header, then count motifs, then read traces.",
    "",
    "# NOT a representative sample: stratified toward misses on purpose. Never",
    "# compute a rate from the traces; the rates below are over every replicate.",
    "",
    paste0("decklist   : ", summary_list$decklist_id),
    paste0("cell       : ", summary_list$scenario, ", going ",
           if(summary_list$bool_going_first) "first" else "second"),
    paste0("replicates : ", summary_list$num_replicates,
           "   misses: ", num_miss,
           "   traces kept: ", length(result_list)),
    paste0("hit (t<=2) : ", .fmt_pct(summary_list$hit_rate),
           "   turn split  t1=", summary_list$turn_tally_vec[["t1"]],
           " t2=", summary_list$turn_tally_vec[["t2"]],
           " late=", summary_list$turn_tally_vec[["late"]],
           " never=", summary_list$turn_tally_vec[["never"]]),
    paste0("mulligans  : ", .fmt_pct(summary_list$mulligan_rate),
           " of games, mean ",
           format(round(summary_list$mean_mulligans, 3), nsmall = 3),
           "   (orthogonal -- never counts as a miss, ADR 0005)"),
    "",
    .lead_block(summary_list$lead_hit_df),
    .decklist_block(decklist),
    "# UNMET SUB-GOALS, counted as a SET so a miss appears in every row it",
    "# belongs to. Rows therefore sum to more than the miss count, by design:",
    "# reporting only the first unmet goal made C look like it never failed.",
    paste0("#   ", names(summary_list$unmet_tally_vec), " ",
           format(SUBGOAL_VEC[names(summary_list$unmet_tally_vec)], width = 18),
           " ", summary_list$unmet_tally_vec, "/", num_miss),
    "",
    "# PLAY MOTIFS across every miss. These are the counts worth acting on:",
    paste0("#   ", format(summary_list$motif_tally_vec, width = 5), " / ",
           num_miss, "  ", MOTIF_VEC[names(summary_list$motif_tally_vec)]),
    "",
    paste0("# misses holding a PLAYABLE out they did not play: ",
           summary_list$num_unused_out, "/", num_miss),
    "#   (a lower bound on decision defects -- it can only see a card LEFT in",
    "#    hand, never one that was played wrongly. The motifs above catch those.)",
    "",
    "# ------------------------------------------------------------------")

  for(i in seq_along(result_list)){
    one_result <- result_list[[i]]
    if(is.null(one_result$trace_vec)) next
    # Index within the file AND the seed: "#N" alone read as an index and jumped,
    # which looks like a bug.
    header_str <- sub("^#[0-9]+", paste0("#", i, "/", length(result_list),
                                         " seed=", one_result$seed_number),
                      one_result$trace_vec[1])
    line_vec <- c(line_vec, "", header_str, one_result$trace_vec[-1])
  }

  writeLines(line_vec, file_path)

  invisible(file_path)
}

#' Hit rate by setup lead, in the trace file header
#'
#' The one table in this file that IS a rate: it is computed over every
#' replicate by \code{summarise_run()}, not over the stratified sample below it.
#' It exists because docs/03_decision_tree.md section 3 states the lead order as
#' a default and Kevin deferred the real answer to the logs.
#'
#' @param lead_hit_df the `lead_hit_df` element of a `"bronzong_summary"`, or
#'   `NULL` for a summary written before that field existed.
#'
#' @returns Character vector of header lines.
#' @noRd
.lead_block <- function(lead_hit_df){
  if(is.null(lead_hit_df) || nrow(lead_hit_df) == 0) return(character(0))

  card_df <- build_card_database()
  # Anything this database does not know is printed as its raw id. "unknown" is
  # the placeholder for a state that never went through
  # place_opening_pokemon(), and a run on a restricted card table can produce
  # others; lookup_card() stops hard on all of them, which would kill the header
  # write after the whole run had already been simulated.
  bool_known_vec <- lead_hit_df$lead_card_id %in% card_df$card_id
  name_vec <- lead_hit_df$lead_card_id
  name_vec[bool_known_vec] <- .short_name(card_df, name_vec[bool_known_vec])

  c("# HIT RATE BY THE BASIC THAT LED AT SETUP, over EVERY replicate. It is a",
    "# rate and may be read as one -- but it does NOT settle the section 3 lead",
    "# order, and reading it that way is the easy mistake (ADR 0008). The hand",
    "# holding a Kangaskhan is not the hand holding a Duskull, so this compares",
    "# leads ACROSS DIFFERENT HANDS and reports a property of the hands. The lead",
    "# is not randomised here; it is chosen, by the very rule under test. The",
    "# order is settled by varying it and measuring the cell rate instead --",
    "# scripts/tune_lead_order_claude.R. Read this as a fact about the policy.",
    paste0("#   ", format(name_vec, width = 22), " ",
           format(lead_hit_df$num_hit, width = 5), "/",
           format(lead_hit_df$num_replicates, width = 5), "  ",
           .fmt_pct(lead_hit_df$hit_rate)),
    "")
}

#' The decklist, spelled out in the trace file header
#'
#' Without it the header gave only a content hash, and an agent asked to
#' recommend decision-tree changes from the traces proposed several cards that
#' are not in the deck. Twenty-odd lines once, for a file of a thousand.
#'
#' @param decklist a `"bronzong_decklist"`, or `NULL` to omit the block.
#'
#' @returns Character vector of header lines.
#' @noRd
.decklist_block <- function(decklist){
  if(is.null(decklist)) {
    return(c("# NOTE: decklist contents not supplied to write_trace_file(),",
             "# so any recommendation from this file may name absent cards.",
             ""))
  }

  card_df <- build_card_database()
  count_vec <- decklist$count_vec
  name_vec <- .short_name(card_df, names(count_vec))

  c("# THE 60 CARDS IN THIS DECK. Do not recommend a card that is not here.",
    paste0("#   ", paste0(count_vec, " ", name_vec, collapse = " | ")),
    "")
}

#' Aggregate every replicate in one cell
#'
#' @param result_list list of `"bronzong_result"` objects, traced or not.
#'
#' @returns A list of aggregate figures, including the two orthogonal mulligan
#'   metrics, the blocking-sub-goal tally, and `lead_hit_df` -- the hit rate
#'   grouped by the Basic that led at setup, which is what settles the section 3
#'   lead order.
#' @export
summarise_run <- function(result_list){
  stopifnot(is.list(result_list), length(result_list) > 0)
  stopifnot(all(sapply(result_list, inherits, "bronzong_result")))

  # ADR 0002 forbids pooling across cells, and this function used to label the
  # run from result_list[[1]] and average everything regardless -- so a mixture
  # of going-first and going-second results produced one number labelled
  # "first", with no warning. Refuse the mixture instead.
  cell_vec <- unique(sapply(result_list, function(x){
    paste0(x$decklist_id, "|", x$scenario, "|", x$bool_going_first)
  }))
  if(length(cell_vec) > 1){
    stop("summarise_run() was given results from ", length(cell_vec),
         " different cells; ADR 0002 forbids pooling across them. Split by ",
         "(decklist_id, scenario, bool_going_first) first.")
  }

  hit_vec <- sapply(result_list, function(x) x$bool_hit)
  mull_vec <- sapply(result_list, function(x) x$num_mulligans)
  turn_vec <- sapply(result_list, function(x) x$jammer_turn)
  unused_vec <- sapply(result_list, function(x) length(x$unused_out_vec) > 0)

  # Counted over the SET of unmet sub-goals, so a miss appears in every row it
  # belongs to. The old first-only tally could never report C above a handful.
  unmet_tally_vec <- sapply(names(SUBGOAL_VEC), function(one){
    sum(sapply(result_list, function(x) one %in% x$unmet_vec))
  })
  motif_tally_vec <- sapply(names(MOTIF_VEC), function(one){
    sum(sapply(result_list, function(x) one %in% x$motif_vec))
  })

  # ADR 0004 requires the turn distribution alongside the headline rate: it is
  # the only place Salvatore's turn-1 speed is visible, and it was computed
  # nowhere.
  turn_tally_vec <- c(t1 = sum(turn_vec == 1L, na.rm = TRUE),
                      t2 = sum(turn_vec == 2L, na.rm = TRUE),
                      late = sum(turn_vec > 2L, na.rm = TRUE),
                      never = sum(is.na(turn_vec)))

  # The lead order in docs/03_decision_tree.md section 3 is an untested default
  # that Kevin deferred to "the simulation logs" (2026-08-29). This is where the
  # answer has to come from: the traces are stratified toward misses (ADR 0006)
  # and no rate may be read off them, so grouping every replicate by its lead is
  # the only legitimate route.
  # `isTRUE(is.na(.))`, not `is.na(.)`: a result built before this field existed
  # drops the element entirely, and `if(logical(0))` is an error -- which would
  # land after every replicate of a 10,000-replicate run had been simulated.
  lead_vec <- sapply(result_list, function(x){
    lead_str <- x$lead_card_id
    if(length(lead_str) != 1 || is.na(lead_str)) "unknown" else lead_str
  })
  lead_id_vec <- sort(unique(lead_vec))
  num_by_lead_vec <- sapply(lead_id_vec, function(one) sum(lead_vec == one))
  hit_by_lead_vec <- sapply(lead_id_vec, function(one){
    sum(hit_vec[lead_vec == one])
  })
  rate_by_lead_vec <- hit_by_lead_vec / num_by_lead_vec
  lead_hit_df <- data.frame(lead_card_id = lead_id_vec,
                            num_replicates = as.integer(num_by_lead_vec),
                            num_hit = as.integer(hit_by_lead_vec),
                            hit_rate = as.numeric(rate_by_lead_vec),
                            stringsAsFactors = FALSE,
                            row.names = NULL)

  structure(
    list(decklist_id = result_list[[1]]$decklist_id,
         scenario = result_list[[1]]$scenario,
         bool_going_first = result_list[[1]]$bool_going_first,
         num_replicates = length(result_list),
         num_miss = sum(!hit_vec),
         hit_rate = mean(hit_vec),
         turn_tally_vec = turn_tally_vec,
         turn1_rate = sum(turn_vec == 1L, na.rm = TRUE) / length(result_list),
         lead_hit_df = lead_hit_df,
         # Orthogonal to the hit rate, never folded into it (ADR 0005).
         mulligan_rate = mean(mull_vec > 0),
         mean_mulligans = mean(mull_vec),
         max_mulligans = max(mull_vec),
         unmet_tally_vec = unmet_tally_vec,
         motif_tally_vec = motif_tally_vec,
         num_unused_out = sum(unused_vec)),
    class = "bronzong_summary")
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

  if(length(turn_vec) == 0) return(character(0))

  # vapply, not sapply: sapply over an empty vector returns list(), which
  # promotes the whole trace to a list and breaks writeLines().
  vapply(sort(unique(turn_vec)), function(one_turn){
    idx_vec <- which(turn_vec == one_turn)
    label_str <- if(one_turn == 0L) "  setup" else
      formatC(paste0("  T", one_turn), width = -7)

    paste0(label_str, " ", paste0(message_vec[idx_vec], collapse = " | "))
  }, character(1))
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

  # "+PP" was ambiguous between two cards each giving [P] and one card giving
  # [P][P], and hid WHICH cards had been spent -- in one trace that suffix was
  # the only evidence that both turns' attachments went onto a dead body.
  name_vec <- .short_name(card_df, in_play$energy_vec)

  paste0("{", paste0(name_vec, collapse = ","), "}")
}

#' A card name carrying its Pokemon type, e.g. "Duskull[P]"
#'
#' Whether a body is [P] or Colorless decides whether Telepathic Psychic
#' Energy's search fires at all, so a reader should not have to look it up.
#' @noRd
.typed_name <- function(card_df, card_id){
  row_df <- lookup_card(card_df, card_id)
  type_str <- switch(row_df$ptype, psychic = "[P]", metal = "[M]",
                     colorless = "[C]", grass = "[G]", "")

  paste0(.short_name(card_df, card_id), type_str)
}

#' @noRd
.fmt_pct <- function(value_val){
  paste0(format(round(100 * value_val, 2), nsmall = 2), "%")
}
