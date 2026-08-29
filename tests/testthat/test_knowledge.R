context("Test the belief state (ADR 0003)")

## ADR 0003 forbids the policy from reading hidden information, and specifies
## three mechanics. These tests pin all three, plus the asymmetry between them
## that is easiest to implement wrongly: a shuffle destroys knowledge of ORDER
## but NOT knowledge of CONTENTS.

test_that("a fresh belief state knows the decklist and nothing else", {
  decklist <- .test_decklist()
  knowledge <- new_knowledge(decklist)

  expect_false(knowledge$bool_deck_seen)
  expect_true(all(knowledge$known_unavailable_vec == 0))
  expect_length(knowledge$top_known_vec, 0)
  expect_equal(sum(knowledge$decklist_count_vec), 60)
})

test_that("prizes are invisible before the first deck search", {
  ## The central guarantee. A prized card must still look findable, because a
  ## real player has no way to know it is gone until they look through the deck.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:15){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    prized_id <- pair$state$prize_vec[1]

    label_str <- paste0("seed ", one_seed, " prized ", prized_id)
    expect_false(pair$knowledge$bool_deck_seen, info = label_str)
    expect_true(all(pair$knowledge$known_unavailable_vec == 0), info = label_str)

    ## Findable unless the player can already see every copy in hand or play.
    visible_num <- sum(pair$state$hand_vec == prized_id) +
      sum(sapply(all_in_play(pair$state),
                 function(x) sum(x$stack_vec == prized_id)))
    total_num <- as.integer(pair$knowledge$decklist_count_vec[[prized_id]])
    if(visible_num < total_num){
      expect_true(believes_findable(pair$knowledge, pair$state, prized_id),
                  info = label_str)
    }
  }
})

test_that("a search deduces exactly the six prized cards", {
  ## The only legitimate route to prize knowledge is subtraction after seeing
  ## the deck. Six cards are prized, so exactly six copies must be deduced
  ## unavailable -- no more, no fewer.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:15){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    knowledge <- knowledge_after_search(pair$knowledge, pair$state)

    expect_true(knowledge$bool_deck_seen, info = paste0("seed ", one_seed))
    expect_equal(sum(knowledge$known_unavailable_vec), 6,
                 info = paste0("seed ", one_seed))
  }
})

test_that("the deduced prizes are the actual prizes", {
  ## Stronger than counting: the deduction must identify the right cards.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:10){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    knowledge <- knowledge_after_search(pair$knowledge, pair$state)

    deduced_vec <- rep(names(knowledge$known_unavailable_vec),
                       times = knowledge$known_unavailable_vec)
    expect_equal(sort(deduced_vec), sort(pair$state$prize_vec),
                 info = paste0("seed ", one_seed))
  }
})

test_that("after a search, findability tracks the real deck", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(7)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
  knowledge <- knowledge_after_search(pair$knowledge, pair$state)

  for(one_id in names(knowledge$decklist_count_vec)){
    bool_really_there <- one_id %in% pair$state$deck_vec
    expect_equal(believes_findable(knowledge, pair$state, one_id),
                 bool_really_there, info = one_id)
  }
})

test_that("a shuffle clears deck ORDER but keeps deck CONTENTS", {
  ## The asymmetry ADR 0003 calls out explicitly. Modelling "unknown" as one
  ## flag would make the player forget what is in their deck every time they
  ## searched, which would make every later search look like a blind guess.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(3)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

  knowledge <- knowledge_after_search(pair$knowledge, pair$state)
  knowledge <- knowledge_after_stacking(knowledge, c("TEF-069", "WHT-084"))
  expect_length(knowledge$top_known_vec, 2)

  num_unavailable <- sum(knowledge$known_unavailable_vec)
  knowledge <- knowledge_after_shuffle(knowledge)

  expect_length(knowledge$top_known_vec, 0)
  expect_true(knowledge$bool_deck_seen)
  expect_equal(sum(knowledge$known_unavailable_vec), num_unavailable)
})

test_that("drawing consumes a stacked top card one at a time", {
  ## Ciphermaniac's Codebreaking stacks two, and the following turn's draw step
  ## takes exactly ONE. If the draw failed to consume the stack, the policy
  ## would believe both were still on top and plan around a card it had drawn.
  decklist <- .test_decklist()
  knowledge <- new_knowledge(decklist)
  knowledge <- knowledge_after_stacking(knowledge, c("TEF-069", "WHT-084"))

  knowledge <- knowledge_after_draw(knowledge, num_cards = 1L)
  expect_equal(knowledge$top_known_vec, "WHT-084")

  knowledge <- knowledge_after_draw(knowledge, num_cards = 1L)
  expect_length(knowledge$top_known_vec, 0)
})

test_that("drawing more than the stack does not error or go negative", {
  ## Lillie's Determination draws 8; the stack is at most 2.
  decklist <- .test_decklist()
  knowledge <- new_knowledge(decklist)
  knowledge <- knowledge_after_stacking(knowledge, "TEF-069")

  knowledge <- knowledge_after_draw(knowledge, num_cards = 8L)

  expect_length(knowledge$top_known_vec, 0)
})

test_that("drawing zero does not consume the stack", {
  decklist <- .test_decklist()
  knowledge <- new_knowledge(decklist)
  knowledge <- knowledge_after_stacking(knowledge, c("TEF-069", "WHT-084"))

  knowledge <- knowledge_after_draw(knowledge, num_cards = 0L)

  expect_length(knowledge$top_known_vec, 2)
})

test_that("believed_deck_count is an upper bound before a search", {
  ## Before looking, the player cannot distinguish prized from still-in-deck, so
  ## the belief must be >= the truth -- never below it, which would make the
  ## policy wrongly give up on a findable card.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:10){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

    for(one_id in names(pair$knowledge$decklist_count_vec)){
      believed_num <- as.integer(believed_deck_count(pair$knowledge,
                                                     pair$state, one_id))
      actual_num <- sum(pair$state$deck_vec == one_id)
      expect_true(believed_num >= actual_num,
                  info = paste0("seed ", one_seed, " ", one_id))
    }
  }
})

test_that("believes_findable never reads the prize pile", {
  ## A behavioural check rather than a code inspection: rewriting the prizes to
  ## something else must not change any belief, because beliefs may not depend
  ## on them.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(11)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

  id_vec <- names(pair$knowledge$decklist_count_vec)
  before_vec <- believes_findable(pair$knowledge, pair$state, id_vec)

  tampered <- pair$state
  tampered$prize_vec <- rep("TEF-069", length(tampered$prize_vec))
  after_vec <- believes_findable(pair$knowledge, tampered, id_vec)

  expect_equal(before_vec, after_vec)
})

test_that("believes_findable handles empty and unknown input", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(5)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

  expect_length(believes_findable(pair$knowledge, pair$state, character(0)), 0)
})

test_that("deck-contents belief stays current after cards move", {
  ## Found by the spec audit. The belief state originally SNAPSHOT the deck at
  ## search time and never updated it, so the policy would believe a card was
  ## still in the deck after drawing it, and -- worse -- believe a card was gone
  ## after shuffling it back in from hand, declining to search for something it
  ## had just watched go into the deck.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(9)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
  pair$knowledge <- knowledge_after_search(pair$knowledge, pair$state)

  ## Direction 1: drawing a card must reduce the believed deck count.
  target_id <- pair$state$deck_vec[1]
  before_num <- as.integer(believed_deck_count(pair$knowledge, pair$state,
                                               target_id))
  pair$state <- draw_cards(pair$state, num_cards = 1L)
  after_num <- as.integer(believed_deck_count(pair$knowledge, pair$state,
                                              target_id))

  expect_equal(after_num, before_num - 1L)
  expect_equal(after_num, sum(pair$state$deck_vec == target_id))
})

test_that("shuffling the hand into the deck restores belief in those cards", {
  ## Lillie's Determination is the case that broke the snapshot design.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  set.seed(13)
  pair <- setup_game(decklist, card_df, bool_going_first = FALSE)

  ## Put every Hilda in hand, then search so the deck is "seen" while they are
  ## demonstrably not in it.
  num_hilda <- as.integer(count_copies(pair$state, "WHT-084"))
  num_in_deck <- sum(pair$state$deck_vec == "WHT-084")
  if(num_in_deck > 0){
    pair$state <- move_cards(pair$state, rep("WHT-084", num_in_deck),
                             from = "deck", to = "hand")
  }
  pair$knowledge <- knowledge_after_search(pair$knowledge, pair$state)
  expect_false(believes_findable(pair$knowledge, pair$state, "WHT-084"))

  ## Now shuffle the hand back in, as Lillie's does.
  pair$state <- move_cards(pair$state, rep("WHT-084", num_in_deck),
                           from = "hand", to = "deck")

  expect_equal(as.integer(believed_deck_count(pair$knowledge, pair$state,
                                              "WHT-084")),
               num_in_deck)
  if(num_in_deck > 0) expect_true(believes_findable(pair$knowledge, pair$state,
                                                    "WHT-084"))
})

test_that("believed deck count matches the truth after a search, always", {
  ## The strongest form of the invariant, swept over seeds and every card.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  for(one_seed in 1:10){
    set.seed(one_seed)
    pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
    pair$knowledge <- knowledge_after_search(pair$knowledge, pair$state)
    pair$state <- draw_cards(pair$state, num_cards = 3L)

    for(one_id in names(pair$knowledge$decklist_count_vec)){
      expect_equal(as.integer(believed_deck_count(pair$knowledge, pair$state,
                                                  one_id)),
                   sum(pair$state$deck_vec == one_id),
                   info = paste0("seed ", one_seed, " ", one_id))
    }
  }
})

test_that("the prize deduction is exact after every real search effect", {
  ## The coverage audit's highest-value gap. Every prize-deduction test called
  ## knowledge_after_search() DIRECTLY on a fresh setup_game(); none went
  ## through a card. The last round's worst bug -- a played Stadium being
  ## deduced as prized -- was exactly that shape, so drive the deduction through
  ## each effect and assert the deduced multiset EQUALS the real prize pile.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  ## Each entry returns NULL when its precondition is not met for this deal,
  ## rather than forcing the position. `.force_into_hand()` ADDS a copy to the
  ## deck when none is there, which would inflate the total above the decklist
  ## count and break the very arithmetic under test -- at seed 6 both
  ## Ciphermaniac's are already out of the deck (one in hand, one prized).
  effect_list <- list(
    poke_pad = function(pair) .run_with("POR-081", pair, function(p){
      play_poke_pad(p, target_id = "TEF-069")
    }),
    poffin = function(pair) .run_with("TEF-144", pair, function(p){
      play_buddy_buddy_poffin(p, target_id_vec = "PRE-035")
    }),
    hilda = function(pair) .run_with("WHT-084", pair, function(p){
      play_hilda(p, evolution_id = "TEF-069", energy_id = "POR-088")
    }),
    brocks = function(pair) .run_with("JTG-146", pair, function(p){
      play_brocks_scouting(p, mode = "basics", target_id_vec = "SSP-076")
    }),
    codebreaking = function(pair) .run_with("TEF-145", pair, function(p){
      play_ciphermaniacs_codebreaking(p, target_id_vec = "TEF-069")
    }),
    telepathic = function(pair) .run_with("POR-088", pair, function(p){
      ## The trigger fires only when the RECIPIENT is [P]. At several seeds the
      ## Active is Mega Kangaskhan ex (Colorless), where firing nothing is the
      ## CORRECT behaviour -- so skip rather than assert a search happened.
      if(lookup_card(p$state$card_df,
                     top_card(p$state$active))$ptype != "psychic") return(NULL)
      attach_energy(p, "POR-088", target_is_active = TRUE,
                    search_id_vec = "PRE-035")
    }),
    stadium_then_search = function(pair) .run_with("TWM-153", pair, function(p){
      p <- play_stadium(p, "TWM-153")
      .run_with("POR-081", p, function(q) play_poke_pad(q, target_id = "TEF-069"))
    }))

  num_cells_run <- 0L
  for(one_name in names(effect_list)){
    for(one_seed in 1:8){
      set.seed(one_seed)
      pair <- setup_game(decklist, card_df, bool_going_first = FALSE)
      pair$state <- begin_turn(pair$state)
      prize_vec <- sort(pair$state$prize_vec)

      pair <- effect_list[[one_name]](pair)
      if(is.null(pair)) next
      num_cells_run <- num_cells_run + 1L
      label_str <- paste0(one_name, " seed ", one_seed)

      expect_true(pair$knowledge$bool_deck_seen, info = label_str)

      deduced_vec <- rep(names(pair$knowledge$known_unavailable_vec),
                         times = pair$knowledge$known_unavailable_vec)
      expect_equal(sort(deduced_vec), prize_vec, info = label_str)
    }
  }

  ## Guard against the whole sweep skipping itself into vacuity.
  expect_true(num_cells_run > 30)
})

test_that("belief queries reject an unknown card id instead of answering FALSE", {
  ## Named in a test whose body never covered it. A mistyped id ("TEF-68" for
  ## "TEF-068") was answered FALSE / 0, so a policy would decline a search it
  ## should have made -- invisible in an aggregate rate.
  pair <- .make_pair()

  expect_error(believes_findable(pair$knowledge, pair$state, "ZZZ-999"))
  expect_error(believes_findable(pair$knowledge, pair$state, "TEF-68"))
  expect_error(believed_deck_count(pair$knowledge, pair$state, "ZZZ-999"))
})
