context("Test the ground-truth game state")

test_that("move_cards conserves the card multiset", {
  ## The invariant that matters most. A slip here creates or destroys cards and
  ## every consistency number downstream is wrong by an unknown amount.
  pair <- .make_pair()
  before_vec <- .card_multiset(pair$state)

  state <- move_cards(pair$state, pair$state$deck_vec[1], from = "deck",
                      to = "hand")
  state <- move_cards(state, state$hand_vec[1], from = "hand", to = "discard")

  expect_equal(.card_multiset(state), before_vec)
})

test_that("move_cards moves one instance per request, not every match", {
  ## A hand can legitimately hold two copies and only one may be moving. If the
  ## implementation removed all matches, a deck would silently shrink.
  pair <- .make_pair(hand_id_vec = c("PRE-035", "PRE-035", "PRE-035"))
  num_before <- sum(pair$state$hand_vec == "PRE-035")

  state <- move_cards(pair$state, "PRE-035", from = "hand", to = "discard")

  expect_equal(sum(state$hand_vec == "PRE-035"), num_before - 1)
  expect_equal(sum(state$discard_vec == "PRE-035"), 1)
})

test_that("move_cards errors when the card is not in the source zone", {
  ## Silently no-op'ing would let a caller "play" a card it never held.
  pair <- .make_pair()

  expect_error(move_cards(pair$state, "TEF-160", from = "discard", to = "hand"),
               regexp = "not in zone")
})

test_that("move_cards on an empty request is a no-op, not an error", {
  ## Search targets are routinely empty vectors when the policy declines to
  ## search, so this path is hit constantly.
  pair <- .make_pair()
  before_vec <- .card_multiset(pair$state)

  state <- move_cards(pair$state, character(0), from = "hand", to = "discard")

  expect_equal(.card_multiset(state), before_vec)
})

test_that("move_cards folds alternate printings to canonical ids", {
  card_df <- .test_card_df()
  decklist <- read_decklist("decklists/decklist5.txt", card_df)
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)

  ## decklist5 cites MEE 5; the deck must hold it as SVE-005.
  expect_true("SVE-005" %in% state$deck_vec)
  expect_false("MEE-005" %in% state$deck_vec)
  expect_silent(move_cards(state, "MEE-005", from = "deck", to = "hand"))
})

test_that("draw_cards moves from the top of the deck in order", {
  pair <- .make_pair()
  top_vec <- pair$state$deck_vec[1:3]

  state <- draw_cards(pair$state, num_cards = 3L)

  expect_equal(state$hand_vec[(length(state$hand_vec) - 2):length(state$hand_vec)],
               top_vec)
  expect_equal(state$deck_vec[1], pair$state$deck_vec[4])
})

test_that("drawing zero cards leaves the state alone", {
  ## Bug pinned: `x[-seq_len(0)]` is `x[integer(0)]` in one reading and an
  ## empty vector in another. Drawing 0 must not empty the deck. This path is
  ## reached whenever Surfer resolves on a full hand.
  pair <- .make_pair()
  before_vec <- .card_multiset(pair$state)
  num_deck_before <- length(pair$state$deck_vec)

  state <- draw_cards(pair$state, num_cards = 0L)

  expect_equal(length(state$deck_vec), num_deck_before)
  expect_equal(.card_multiset(state), before_vec)
})

test_that("drawing more than the deck holds sets the deck-out flag", {
  pair <- .make_pair()
  num_deck <- length(pair$state$deck_vec)

  state <- draw_cards(pair$state, num_cards = num_deck + 5L)

  expect_equal(length(state$deck_vec), 0)
  expect_true(isTRUE(state$bool_decked_out))
})

test_that("shuffle_deck preserves the deck multiset", {
  pair <- .make_pair()
  before_vec <- sort(pair$state$deck_vec)

  set.seed(42)
  state <- shuffle_deck(pair$state)

  expect_equal(sort(state$deck_vec), before_vec)
})

test_that("shuffling a one-card deck returns that card, not a permutation", {
  ## Bug pinned: `sample(x)` on a length-1 numeric permutes seq_len(x) rather
  ## than returning x. The implementation must permute POSITIONS. With a
  ## character deck the failure mode differs but the guard is the same, so
  ## sweep seeds rather than trusting one.
  for(one_seed in 1:20){
    pair <- .make_pair()
    pair$state$deck_vec <- "TEF-069"

    set.seed(one_seed)
    state <- shuffle_deck(pair$state)

    expect_equal(state$deck_vec, "TEF-069", info = paste0("seed ", one_seed))
  }
})

test_that("shuffling an empty deck is safe", {
  pair <- .make_pair()
  pair$state$deck_vec <- character(0)

  expect_silent(shuffle_deck(pair$state))
  expect_length(shuffle_deck(pair$state)$deck_vec, 0)
})

test_that("begin_turn increments the turn and clears every per-turn flag", {
  pair <- .make_pair(turn_number = 1L)
  pair$state$turn_flag_list$bool_supporter_played <- TRUE
  pair$state$turn_flag_list$bool_energy_attached <- TRUE
  pair$state$turn_flag_list$bool_attacked <- TRUE

  state <- begin_turn(pair$state)

  expect_equal(state$turn_number, 2L)
  expect_true(all(!unlist(state$turn_flag_list)))
})

test_that("top_card reads the top of an evolution stack", {
  in_play <- new_in_play("TEF-068", turn_played = 0L)
  expect_equal(top_card(in_play), "TEF-068")

  in_play$stack_vec <- c(in_play$stack_vec, "TEF-069")
  expect_equal(top_card(in_play), "TEF-069")
})

test_that("all_in_play puts the Active first and copes with no Active", {
  pair <- .make_pair(active_id = "TEF-068",
                     bench_id_vec = c("PRE-035", "PFL-083"))

  in_play_list <- all_in_play(pair$state)
  expect_equal(length(in_play_list), 3)
  expect_equal(top_card(in_play_list[[1]]), "TEF-068")

  pair$state$active <- NULL
  expect_equal(length(all_in_play(pair$state)), 2)
})

test_that("an in-play record starts with no energy and no damage", {
  in_play <- new_in_play("TEF-068", turn_played = 2L)

  expect_length(in_play$energy_vec, 0)
  expect_equal(in_play$damage, 0L)
  expect_equal(in_play$turn_played, 2L)
  expect_true(is.na(in_play$turn_evolved))
})

test_that("count_copies counts every zone including attached energy", {
  pair <- .make_pair(active_id = "TEF-068")
  pair$state$active$energy_vec <- "SVE-005"
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  ## decklist2 runs 2 Bronzor and 0 basic Psychic, so after the fixture forces
  ## one Bronzor into play the total is still 2, and the attached SVE-005 is an
  ## extra card the fixture added -- count it, do not lose it.
  expect_equal(as.integer(count_copies(pair$state, "TEF-068")), 2L)
  expect_equal(as.integer(count_copies(pair$state, "SVE-005")), 1L)
})

test_that("the event log grows and is stamped with the turn", {
  pair <- .make_pair(turn_number = 2L)
  num_before <- length(pair$state$event_log)

  state <- draw_cards(pair$state, num_cards = 1L)

  expect_true(length(state$event_log) > num_before)
  expect_true(grepl("^T2:", state$event_log[length(state$event_log)]))
})

test_that("the Stadium in play is counted as a card in the game", {
  ## Found by the correctness audit, and the nastiest of the batch. A played
  ## Stadium sits in state$stadium -- neither hand nor discard -- and both
  ## count_copies() and the belief state's .visible_count() omitted it. The card
  ## vanished from the census, and knowledge_after_search() then deduced it was
  ## PRIZED while it sat face up on the table, corrupting the ADR 0003 deduction
  ## for any game where a Stadium was played.
  ##
  ## The test helper had its own census that DID count the stadium, which is
  ## exactly why the suite masked this instead of catching it. Assert against the
  ## production census here.
  pair <- .make_pair(hand_id_vec = "TWM-153", turn_number = 2L)
  num_before <- as.integer(count_copies(pair$state, "TWM-153"))
  num_total_before <- length(all_cards_in_game(pair$state))

  pair <- play_stadium(pair, "TWM-153")

  expect_equal(as.integer(count_copies(pair$state, "TWM-153")), num_before)
  expect_equal(length(all_cards_in_game(pair$state)), num_total_before)
})

test_that("a played Stadium is not deduced to be prized", {
  card_df <- .test_card_df()
  decklist <- read_decklist("decklists/decklist1.txt", card_df)
  set.seed(2)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
  pair$state <- begin_turn(pair$state)

  if("ASC-197" %in% pair$state$deck_vec){
    pair$state <- move_cards(pair$state, "ASC-197", from = "deck", to = "hand")
  }
  if("ASC-197" %in% pair$state$hand_vec){
    pair <- play_stadium(pair, "ASC-197")
    pair$knowledge <- knowledge_after_search(pair$knowledge, pair$state)

    expect_equal(sum(pair$knowledge$known_unavailable_vec), 6)
    expect_equal(as.integer(pair$knowledge$known_unavailable_vec[["ASC-197"]]), 0)
  }
})

test_that("count_copies returns an integer vector, even when empty", {
  ## sapply() over an empty input returns a list, and sum() then errors on it.
  pair <- .make_pair()

  expect_true(is.integer(count_copies(pair$state, character(0))))
  expect_length(count_copies(pair$state, character(0)), 0)
  expect_true(is.integer(count_copies(pair$state, "TEF-069")))
})

test_that("bool_decked_out exists from the start", {
  ## Documented as "the flag exists so a bug shows up as a flag", but it was
  ## absent until an over-draw created it, so `if(state$bool_decked_out)` failed
  ## with "argument is of length zero".
  pair <- .make_pair()

  expect_false(pair$state$bool_decked_out)
})
