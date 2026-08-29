# The player's belief state.
#
# This is what the player KNOWS, as opposed to what is true. ADR 0003 forbids
# the policy from reading ground truth, so every question the policy asks about
# hidden zones must be answered from here.
#
# Three mechanics, specified by Kevin (ADR 0003), and the asymmetry between the
# second and third is the part that is easy to get wrong:
#
#   1. Deck CONTENTS are unknown until the first deck search. Searching reveals
#      what is in the deck; what is missing from it is prized or already gone.
#   2. Deck ORDER is never known, except for cards deliberately placed on top by
#      Ciphermaniac's Codebreaking.
#   3. The deck is reshuffled, unseen, after every deck search. A shuffle
#      destroys knowledge of ORDER but NOT knowledge of CONTENTS -- having seen
#      the deck once, the player still knows what is in it.
#
# Because of (3), "unknown" cannot be a single flag.

#' Create a belief state for the start of a game
#'
#' At this point the player knows only their own decklist. They have not seen
#' the deck, so they do not know which six cards are prized.
#'
#' @param decklist a `"bronzong_decklist"`.
#'
#' @returns An object of class `"bronzong_knowledge"`: a list with
#'   \describe{
#'     \item{decklist_count_vec}{named integer, the 60-card list as built.}
#'     \item{bool_deck_seen}{logical, whether the deck has ever been searched.}
#'     \item{known_unavailable_vec}{named integer, copies known to be prized,
#'       deduced by subtraction at the first search. This is the ONLY durable
#'       fact a search establishes; deck contents are derived from it rather
#'       than stored, so they cannot go stale.}
#'     \item{top_known_vec}{character vector of card ids known to be on top of
#'       the deck, position 1 first. Emptied by any shuffle.}
#'     \item{seen_vec}{character vector of card ids the player has observed at
#'       any point, for auditing.}
#'   }
#' @export
new_knowledge <- function(decklist){
  stopifnot(inherits(decklist, "bronzong_decklist"))

  structure(list(decklist_count_vec = decklist$count_vec,
                 bool_deck_seen = FALSE,
                 known_unavailable_vec = decklist$count_vec * 0L,
                 top_known_vec = character(0),
                 seen_vec = character(0)),
            class = "bronzong_knowledge")
}

#' Record that the player has searched the deck
#'
#' A deck search shows the player the whole deck, so afterwards they know its
#' contents exactly. What they learn about prizes is a deduction: any copy in
#' the decklist that is neither in the deck, nor in hand, nor in play, nor in
#' the discard must be prized. That deduction is the ONLY way the player is
#' allowed to learn about prizes.
#'
#' @param knowledge a `"bronzong_knowledge"`.
#' @param state the ground-truth `"bronzong_state"`. Read here, and only here,
#'   to compute what an honest player would see by looking through their deck.
#'
#' @returns The updated belief state.
#' @export
knowledge_after_search <- function(knowledge, state){
  stopifnot(inherits(knowledge, "bronzong_knowledge"),
            inherits(state, "bronzong_state"))

  card_id_vec <- names(knowledge$decklist_count_vec)

  deck_count_vec <- as.integer(sapply(card_id_vec, function(one_id){
    sum(state$deck_vec == one_id)
  }))
  visible_vec <- .visible_count(state, card_id_vec)

  # Everything the player can otherwise account for. Whatever is left over is
  # prized -- this subtraction is the deduction described above, and it is the
  # only durable fact the search establishes.
  #
  # Deliberately NOT stored: a snapshot of the deck's contents. Prizes cannot
  # change during a game, so `known_unavailable_vec` stays true for the rest of
  # it; a contents snapshot would go stale the moment anything was drawn or
  # shuffled back in, and the player would then "know" a card was in the deck
  # after drawing it, or believe a card they had just shuffled in was gone.
  # believed_deck_count() derives contents from this instead, so it is always
  # current.
  unavailable_vec <- knowledge$decklist_count_vec - deck_count_vec - visible_vec
  knowledge$known_unavailable_vec <- pmax(unavailable_vec, 0L)
  knowledge$bool_deck_seen <- TRUE

  knowledge$seen_vec <- union(knowledge$seen_vec,
                              card_id_vec[deck_count_vec > 0])

  knowledge
}

#' Record that the deck was shuffled
#'
#' Destroys knowledge of ordering. Deliberately leaves `bool_deck_seen` and
#' `known_unavailable_vec` alone: a shuffle rearranges the deck, it does not make
#' the player forget what is in it, nor un-deduce which cards are prized.
#'
#' @param knowledge a `"bronzong_knowledge"`.
#'
#' @returns The updated belief state.
#' @export
knowledge_after_shuffle <- function(knowledge){
  stopifnot(inherits(knowledge, "bronzong_knowledge"))

  knowledge$top_known_vec <- character(0)

  knowledge
}

#' Record cards deliberately placed on top of the deck
#'
#' Ciphermaniac's Codebreaking is the only card here that creates ordering
#' knowledge. It shuffles first and then places, so the caller must apply
#' \code{knowledge_after_shuffle()} before this.
#'
#' @param knowledge a `"bronzong_knowledge"`.
#' @param card_id_vec card ids placed on top, position 1 first.
#'
#' @returns The updated belief state.
#' @export
knowledge_after_stacking <- function(knowledge, card_id_vec){
  stopifnot(inherits(knowledge, "bronzong_knowledge"), is.character(card_id_vec))

  knowledge$top_known_vec <- canonical_card_id(card_id_vec)

  knowledge
}

#' Record that a card was drawn from the top
#'
#' Consumes the first element of any known top-of-deck stack, so that a stack of
#' two placed by Ciphermaniac's Codebreaking correctly yields exactly one card
#' on the following turn's draw.
#'
#' @param knowledge a `"bronzong_knowledge"`.
#' @param num_cards how many cards were drawn.
#'
#' @returns The updated belief state.
#' @export
knowledge_after_draw <- function(knowledge, num_cards){
  stopifnot(inherits(knowledge, "bronzong_knowledge"), num_cards >= 0)

  num_consumed <- min(num_cards, length(knowledge$top_known_vec))
  if(num_consumed > 0){
    knowledge$top_known_vec <- knowledge$top_known_vec[-seq_len(num_consumed)]
  }

  knowledge
}

#' Could a search plausibly find this card?
#'
#' The predicate the policy uses before committing a search card. Before the
#' deck has ever been seen the player must assume any card not otherwise
#' accounted for might be in the deck -- that assumption is what makes a whiff
#' possible, and a whiff is legitimate information rather than a bug.
#'
#' @param knowledge a `"bronzong_knowledge"`.
#' @param state the ground-truth state, read only for the zones the player can
#'   legitimately see: hand, board, and discard.
#' @param card_id_vec card ids to test.
#'
#' @returns A logical vector, `TRUE` where the player has reason to believe at
#'   least one copy may still be in the deck.
#' @export
believes_findable <- function(knowledge, state, card_id_vec){
  stopifnot(inherits(knowledge, "bronzong_knowledge"),
            inherits(state, "bronzong_state"))

  as.logical(believed_deck_count(knowledge, state, card_id_vec) > 0)
}

#' How many copies the player believes remain in the deck
#'
#' @param knowledge a `"bronzong_knowledge"`.
#' @param state the ground-truth state, for the visible zones only.
#' @param card_id_vec card ids to count.
#'
#' @returns A named integer vector. Before the first search this is an upper
#'   bound, since prized copies cannot yet be distinguished from copies still in
#'   the deck. After a search it is exact.
#' @export
believed_deck_count <- function(knowledge, state, card_id_vec){
  stopifnot(inherits(knowledge, "bronzong_knowledge"),
            inherits(state, "bronzong_state"))

  card_id_vec <- canonical_card_id(card_id_vec)
  if(length(card_id_vec) == 0) return(stats::setNames(integer(0), character(0)))

  # Route through lookup_card() purely for its loud-failure contract. Without
  # it, an unknown or mistyped id (say "TEF-68" for "TEF-068") answered 0 /
  # FALSE, so a policy asking about a typo would be told the card is not
  # findable and would decline a search it should have made -- invisible in an
  # aggregate rate. lookup_card()'s own documentation warns that a silent NA
  # here "propagates into every downstream rule as a false negative"; these
  # queries were bypassing exactly that.
  lookup_card(state$card_df, card_id_vec)

  # Derived, never stored. What is in the deck is what the decklist held, minus
  # everything the player can see, minus what a search proved to be prized. This
  # is exactly the arithmetic a real player does, and because it reads the
  # CURRENT board it stays correct after draws, discards, and cards shuffled
  # back in -- which a snapshot taken at search time would not.
  total_vec <- knowledge$decklist_count_vec[card_id_vec]
  total_vec[is.na(total_vec)] <- 0L
  visible_vec <- .visible_count(state, card_id_vec)

  unavailable_vec <- rep(0L, length(card_id_vec))
  if(knowledge$bool_deck_seen){
    unavailable_vec <- knowledge$known_unavailable_vec[card_id_vec]
    unavailable_vec[is.na(unavailable_vec)] <- 0L
  }

  stats::setNames(pmax(as.integer(total_vec - visible_vec - unavailable_vec), 0L),
                  card_id_vec)
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

#' Count copies in the zones a player can legitimately see
#'
#' Hand, in-play stacks, attached Energy, and the discard pile are all open
#' information. The deck and the prizes are not, and are deliberately excluded.
#'
#' @param state a `"bronzong_state"`.
#' @param card_id_vec card ids to count.
#'
#' @returns An integer vector aligned with `card_id_vec`.
#' @noRd
.visible_count <- function(state, card_id_vec){
  if(length(card_id_vec) == 0) return(integer(0))

  in_play_vec <- unlist(lapply(all_in_play(state), function(x) x$stack_vec))
  energy_vec <- unlist(lapply(all_in_play(state), function(x) x$energy_vec))

  # The Stadium in play is face up on the table and is as visible as anything on
  # the board. Omitting it made a played Stadium unaccounted for, and the prize
  # deduction in knowledge_after_search() then concluded it was prized.
  visible_vec <- c(state$hand_vec, state$discard_vec, in_play_vec, energy_vec,
                   state$stadium[!is.na(state$stadium)])

  as.integer(sapply(card_id_vec, function(one_id) sum(visible_vec == one_id)))
}

#' @export
print.bronzong_knowledge <- function(x, ...){
  cat("<bronzong_knowledge>", if(x$bool_deck_seen) "deck seen" else "deck unseen",
      "\n")
  if(x$bool_deck_seen && any(x$known_unavailable_vec > 0)){
    unavailable_vec <- x$known_unavailable_vec[x$known_unavailable_vec > 0]
    cat("  known prized:",
        paste0(names(unavailable_vec), " x", unavailable_vec, collapse = ", "),
        "\n")
  }
  if(length(x$top_known_vec) > 0){
    cat("  known on top:", paste0(x$top_known_vec, collapse = ", "), "\n")
  }
  invisible(x)
}
