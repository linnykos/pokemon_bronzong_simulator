context("Test game setup")

test_that("setup conserves all 60 cards across many seeds", {
  ## Sweep rather than sample: setup branches on how many Basics the opening
  ## hand holds, and a bookkeeping bug in the placement path only shows up for
  ## some hands.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:40){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

    expect_equal(.total_cards(pair$state), 60,
                 info = paste0("seed ", one_seed))
    expect_equal(sort(.card_multiset(pair$state)), sort(decklist$card_id_vec),
                 info = paste0("seed ", one_seed))
  }
})

test_that("setup ends with 7 drawn, 6 prized, and an Active in place", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:20){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    num_in_play <- length(all_in_play(pair$state))

    expect_length(pair$state$prize_vec, 6)
    expect_false(is.null(pair$state$active))
    ## 7 drawn, minus however many were placed.
    expect_equal(length(pair$state$hand_vec) + num_in_play, 7,
                 info = paste0("seed ", one_seed))
    expect_equal(length(pair$state$deck_vec), 60 - 7 - 6,
                 info = paste0("seed ", one_seed))
  }
})

test_that("the opening hand always contains a Basic", {
  ## The mulligan loop's only job. If it ever exits without one, placement
  ## fails downstream with a confusing error instead of here.
  card_df <- .test_card_df()

  for(one_name in c("decklist1", "decklist2", "decklist5")){
    decklist <- .test_decklist(one_name)
    for(one_seed in 1:20){
      set.seed(one_seed)
      state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
      state <- deal_opening_hand(state)

      expect_length(state$hand_vec, 7)
      expect_true(any(is_basic_pokemon(card_df, state$hand_vec)),
                  info = paste0(one_name, " seed ", one_seed))
    }
  }
})

test_that("mulligans conserve the deck and are counted", {
  ## A mulligan shuffles the hand back and redraws. If the return-to-deck step
  ## leaked, the deck would shrink by 7 per mulligan.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:30){
    set.seed(one_seed)
    state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
    state <- deal_opening_hand(state)

    expect_equal(length(state$deck_vec) + length(state$hand_vec), 60,
                 info = paste0("seed ", one_seed))
    expect_true(state$num_mulligans >= 0)
  }
})

test_that("a deck with no Basic Pokemon aborts rather than looping forever", {
  ## The safety valve. Without it this is an infinite loop, which in a 10,000
  ## replicate run looks like a hang rather than an error.
  card_df <- .test_card_df()
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(c("4 Switch MEG 130", "56 Basic {P} Energy SVE 5"), tmp_file)
  decklist <- read_decklist(tmp_file, card_df)
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)

  expect_error(deal_opening_hand(state, max_mulligans = 5L),
               regexp = "mulligans")
})

test_that("only Basic Pokemon may be placed during setup", {
  ## Rules section 3 step 6. Placing an Evolution or a Trainer must fail loudly.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(2)
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("TEF-068", "TEF-069", "MEG-130"),
                      from = "deck", to = "hand")

  expect_error(place_opening_pokemon(state, "TEF-069"), regexp = "Basic")
  expect_error(place_opening_pokemon(state, "MEG-130"), regexp = "Basic")
  expect_silent(place_opening_pokemon(state, "TEF-068"))
})

test_that("placement cannot exceed the bench limit", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, rep("PRE-035", 4), from = "deck", to = "hand")
  state <- move_cards(state, c("TEF-068", "PFL-083", "ASC-016"),
                      from = "deck", to = "hand")

  expect_error(place_opening_pokemon(state, "TEF-068",
                                     c(rep("PRE-035", 4), "PFL-083", "ASC-016")),
               regexp = "limit")
})

test_that("placed Pokemon leave the hand and appear in play exactly once", {
  ## Pins the discard round-trip in place_opening_pokemon(): the cards are moved
  ## to the discard and then trimmed back off. If the trim removed the wrong
  ## elements, cards would be duplicated or lost.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("TEF-068", "PRE-035", "PFL-083"),
                      from = "deck", to = "hand")
  before_vec <- .card_multiset(state)

  state <- place_opening_pokemon(state, "TEF-068", c("PRE-035", "PFL-083"))

  expect_equal(.card_multiset(state), before_vec)
  expect_length(state$discard_vec, 0)
  expect_equal(top_card(state$active), "TEF-068")
  expect_equal(length(state$bench_list), 2)
  expect_false("TEF-068" %in% state$hand_vec)
})

test_that("placement works when the discard is already non-empty", {
  ## The trim-the-discard trick is only safe if it removes the cards just added.
  ## Seed the discard first so a naive implementation that clears it, or trims
  ## from the wrong end, is caught.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("MEG-130", "MEG-131"), from = "deck",
                      to = "discard")
  state <- move_cards(state, c("TEF-068", "PRE-035"), from = "deck", to = "hand")
  before_vec <- .card_multiset(state)

  state <- place_opening_pokemon(state, "TEF-068", "PRE-035")

  expect_equal(.card_multiset(state), before_vec)
  expect_equal(sort(state$discard_vec), sort(c("MEG-130", "MEG-131")))
})

test_that("placement is correct when the same card is Active and benched", {
  ## Two copies of one Bronzor is the common case, and it is exactly where
  ## "remove all matches" bugs surface.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("TEF-068", "TEF-068"), from = "deck", to = "hand")
  before_vec <- .card_multiset(state)

  state <- place_opening_pokemon(state, "TEF-068", "TEF-068")

  expect_equal(.card_multiset(state), before_vec)
  expect_equal(top_card(state$active), "TEF-068")
  expect_equal(top_card(state$bench_list[[1]]), "TEF-068")
})

test_that("prizes come off the deck and are not looked at", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(4)
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- deal_opening_hand(state)
  num_deck_before <- length(state$deck_vec)

  state <- set_prizes(state)

  expect_length(state$prize_vec, 6)
  expect_equal(length(state$deck_vec), num_deck_before - 6)
})

test_that("set_prizes errors rather than silently short-prizing", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state$deck_vec <- state$deck_vec[1:3]

  expect_error(set_prizes(state), regexp = "prizes")
})

test_that("setup_game returns a paired state and knowledge", {
  ## The pairing is deliberate: nearly every effect touches both, so bundling
  ## makes it hard to update one and forget the other.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(1)
  pair <- setup_game(decklist, card_df, bool_going_first = TRUE)

  expect_true(inherits(pair$state, "bronzong_state"))
  expect_true(inherits(pair$knowledge, "bronzong_knowledge"))
  expect_true(pair$state$bool_going_first)
  expect_equal(pair$state$turn_number, 0L)
})

test_that("the default placement leads a Bronzor whenever it holds one", {
  ## docs/03_decision_tree.md section 3: leading Bronzor costs nothing and
  ## satisfies sub-goal C outright. The placeholder placement must at least do
  ## this much, or the smoke numbers are misleadingly bad.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:30){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    in_play_vec <- unlist(lapply(all_in_play(pair$state), top_card))
    bronzor_vec <- c("TEF-068", "PRE-066", "SSP-126")

    if(any(in_play_vec %in% bronzor_vec)){
      expect_true(top_card(pair$state$active) %in% bronzor_vec,
                  info = paste0("seed ", one_seed))
    }
  }
})

test_that("set_prizes(0) leaves the deck alone instead of destroying it", {
  ## `deck_vec[-integer(0)]` returns an EMPTY vector, not the deck. The guard
  ## admits num_prizes = 0, so this was one negative index away from silently
  ## wiping all 60 cards.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  num_before <- length(state$deck_vec)

  state <- set_prizes(state, num_prizes = 0L)

  expect_equal(length(state$deck_vec), num_before)
  expect_length(state$prize_vec, 0)
})

test_that("the mulligan bound fires at the bound, not one past it", {
  card_df <- .test_card_df()
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(c("4 Switch MEG 130", "56 Basic {P} Energy SVE 5"), tmp_file)
  decklist <- read_decklist(tmp_file, card_df)
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)

  expect_error(deal_opening_hand(state, max_mulligans = 3L),
               regexp = "exceeded 3 mulligans")
})
