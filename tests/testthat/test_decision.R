context("Test the decision-tree policy")

## The policy is a first draft and will change with the tree, so these tests pin
## the things that must hold whatever the tree says next: it stays inside the
## rules, it never reads hidden information, and it does not crash. Tests that
## pinned a specific line of play would all have to be rewritten next week.

test_that("placement leads a Bronzor when held, and benches nothing", {
  ## Section 3, and the bench-nothing rule Kevin gave on 2026-08-29. The empty
  ## bench is the part worth pinning: it reverses what the draft said three
  ## times over, so a later edit could plausibly reintroduce benching.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("MEG-104", "TEF-068", "PRE-035"),
                      from = "deck", to = "hand")

  place_list <- policy_placement(state)

  expect_equal(place_list$active_card_id, "TEF-068")
  expect_length(place_list$bench_card_id_vec, 0)
})

test_that("placement falls down the section 3 order without a Bronzor", {
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  ## Each row is a hand; the expected lead is the highest-ranked Basic present,
  ## going second. Pinned against LEAD_ORDER_LIST as ADR 0008 settled it, so a
  ## re-tuning that moves a name fails here and has to be acknowledged rather
  ## than absorbed. Buneary is last going second now, which is the pair worth
  ## keeping: its whole case was Run Around, and §4.2 makes Run Around a last
  ## resort.
  case_list <- list(list(hand = c("PRE-035", "MEG-104"), lead = "MEG-104"),
                    list(hand = c("PRE-035", "PFL-083"), lead = "PRE-035"),
                    list(hand = c("SSP-076", "MEG-104"), lead = "SSP-076"),
                    list(hand = c("ASC-016", "PRE-035"), lead = "PRE-035"),
                    list(hand = c("TEF-078", "ASC-016"), lead = "ASC-016"))

  for(one_case in case_list){
    state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
    state <- move_cards(state, one_case$hand, from = "deck", to = "hand")

    expect_equal(policy_placement(state)$active_card_id, one_case$lead,
                 info = paste0("hand ", paste0(one_case$hand, collapse = "+")))
  }
})

test_that("Meowth ex is never led while another Basic is available", {
  ## Leading it wastes Last-Ditch Catch outright, which is why it is absent from
  ## the order rather than last in it.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("POR-062", "TEF-078"),
                      from = "deck", to = "hand")

  expect_equal(policy_placement(state)$active_card_id, "TEF-078")
})

test_that("the turn-1 kill line fires only when every piece is there", {
  ## Section 4.1. Each `expect_false` removes exactly one requirement from a
  ## board that otherwise works, so a condition that silently stops being
  ## checked shows up as one failure rather than none.
  .kill_pair <- function(...){
    args_list <- list(...)
    pair <- .make_pair(active_id = "TEF-068",
                       hand_id_vec = args_list$hand_id_vec,
                       turn_number = 1L,
                       bool_going_first = isTRUE(args_list$bool_going_first))
    pair
  }
  full_hand_vec <- c("TEF-160", "SVE-005")

  expect_true(.kill_line_is_live(.kill_pair(hand_id_vec = full_hand_vec)))
  ## Going first: no Supporter is legal on turn 1 at all.
  expect_false(.kill_line_is_live(.kill_pair(hand_id_vec = full_hand_vec,
                                             bool_going_first = TRUE)))
  ## No Salvatore, and no [P] source, each on their own.
  expect_false(.kill_line_is_live(.kill_pair(hand_id_vec = "SVE-005")))
  expect_false(.kill_line_is_live(.kill_pair(hand_id_vec = "TEF-160")))
})

test_that("the kill line needs a Bronzor it can make Active for free", {
  ## Salvatore evolves a Bronzor anywhere on the board, so the positioning is a
  ## separate requirement -- the trap ADR 0001's note warns about.
  benched <- .make_pair(active_id = "MEG-104", bench_id_vec = "TEF-068",
                        hand_id_vec = c("TEF-160", "SVE-005"), turn_number = 1L)
  expect_false(.kill_line_is_live(benched))

  ## A Switch makes it free, and so does Latias ex's Skyliner.
  with_switch <- .make_pair(active_id = "MEG-104", bench_id_vec = "TEF-068",
                            hand_id_vec = c("TEF-160", "SVE-005", "MEG-130"),
                            turn_number = 1L)
  expect_true(.kill_line_is_live(with_switch))

  with_latias <- .make_pair(active_id = "MEG-104",
                            bench_id_vec = c("TEF-068", "SSP-076"),
                            hand_id_vec = c("TEF-160", "SVE-005"),
                            turn_number = 1L)
  expect_true(.kill_line_is_live(with_latias))
})

test_that("the ladder spends the free retreat before it spends a Switch", {
  ## Section 4.3, and the correction Kevin made on 2026-08-29: the retreat is
  ## free and otherwise unspent, so using a card for it throws the card away.
  pair <- .make_pair(active_id = "MEG-104",
                     bench_id_vec = c("TEF-068", "SSP-076"),
                     hand_id_vec = "MEG-130", turn_number = 2L)

  pair <- .policy_position(pair)

  expect_equal(top_card(pair$state$active), "TEF-068")
  expect_true("MEG-130" %in% pair$state$hand_vec)
  expect_true(any(grepl("via retreat", pair$state$event_log)))
})

test_that("the ladder falls to Switch when the retreat is not free", {
  pair <- .make_pair(active_id = "MEG-104", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)

  pair <- .policy_position(pair)

  expect_equal(top_card(pair$state$active), "TEF-068")
  expect_false("MEG-130" %in% pair$state$hand_vec)
})

test_that("the ladder promotes an evolved Bronzong ahead of a bare Bronzor", {
  ## Promoting the Bronzong meets sub-goal C outright; promoting the Bronzor
  ## leaves it unmet and needs an evolution that may not be available.
  pair <- .make_pair(active_id = "MEG-104",
                     bench_id_vec = c("TEF-068", "TEF-068", "SSP-076"),
                     turn_number = 2L)
  pair$state$bench_list[[2]]$stack_vec <- c("TEF-068", "TEF-069")

  pair <- .policy_position(pair)

  expect_equal(top_card(pair$state$active), "TEF-069")
})

test_that("the policy never names a search target the card cannot fetch", {
  ## The defect that killed a third of the first draft's replicates: Poke Pad
  ## was asked for Latias ex, which has a Rule Box. The effects assert legality
  ## with stopifnot(), so this is a crash rather than a misplay.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "POR-081",
                     turn_number = 2L)

  expect_silent(.policy_search_items(pair))
  expect_false(is.null(ALLOWED_TARGET_LIST$poke_pad))
  expect_false(any(ALLOWED_TARGET_LIST$poke_pad(pair$state$card_df, "SSP-076")))
})

test_that("Ultra Ball's discards handle a hand holding duplicates", {
  ## Matching on card ids de-duplicates, so a hand with two copies offered one
  ## discard where two existed and the pair was padded with NA -- which
  ## move_cards() rejected a hundred replicates into a run.
  ##
  ## Two Boss's Orders, which the playbook's order ranks second and protects
  ## nowhere. This used to use two Rare Candy; one Rare Candy is now kept for
  ## the section 4.3 rung-5 escape, which would make this test about that rule
  ## rather than about the NA padding it exists to pin.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("MEG-131", "MEG-114", "MEG-114"),
                     turn_number = 2L)

  discard_vec <- .ultra_ball_discards(pair)

  expect_length(discard_vec, 2)
  expect_false(anyNA(discard_vec))
  expect_false("MEG-131" %in% discard_vec)
  expect_equal(discard_vec, c("MEG-114", "MEG-114"))

  ## And it declines rather than padding when there are not two to spare.
  thin <- .make_pair(active_id = "PRE-035", hand_id_vec = "MEG-131",
                     turn_number = 2L)
  expect_true(is.null(.ultra_ball_discards(thin)))
})

test_that("Ultra Ball protects the whole line until its undo is in hand", {
  ## docs/03a_card_playbook.md -> Ultra Ball, "The line is protected by name,
  ## not by count". EVERY Bronzong is protected, surplus included, and a Night
  ## Stretcher in hand is what releases one; every Bronzor likewise, released by
  ## a Salvatore. This replaces the older "last copy only" rule, which let a
  ## second Bronzong go for nothing.
  ##
  ## The negative case is asserted WITH THE CARD STILL IN HAND rather than by
  ## its absence: an unconditional protection and a correctly conditional one
  ## look identical from the side that declines.
  two_bronzong <- .make_pair(active_id = "PRE-035",
                             hand_id_vec = c("MEG-131", "TEF-069", "TEF-069",
                                             "MEG-114"),
                             turn_number = 2L)
  ## Boss's Orders is the only spare, and one is not two.
  expect_true(is.null(.ultra_ball_discards(two_bronzong)))

  ## Add the Night Stretcher and the surplus Bronzong is released -- but the
  ## Stretcher itself is now protected, even though it ranks third on the
  ## discard order, because spending both is the ordering the rule forbids.
  with_stretcher <- .make_pair(active_id = "PRE-035",
                               hand_id_vec = c("MEG-131", "TEF-069", "TEF-069",
                                               "MEG-114", "ASC-196"),
                               turn_number = 2L)
  discard_vec <- .ultra_ball_discards(with_stretcher)

  expect_length(discard_vec, 2)
  expect_equal(sum(discard_vec == "TEF-069"), 1)
  expect_equal(sum(discard_vec == "ASC-196"), 0)
  ## Boss's Orders is second in the playbook's order, so it goes first.
  expect_equal(discard_vec[1], "MEG-114")
})

test_that("Ultra Ball spends a surplus Bronzor only alongside Salvatore", {
  ## The second half of the same rule. Without Salvatore a Bronzor played on
  ## turn 2 cannot be evolved that turn (ADR 0001), so discarding one costs a
  ## turn rather than a card -- and the window is two turns long.
  ##
  ## Two Bronzor plus two genuine spares: with the rule off, both Bronzor would
  ## still be safe, so the discriminating hand has to make the Bronzor the
  ## CHEAPEST cards available. Flutter Mane and Dusknoir rank below the surplus
  ## Bronzor only once the Bronzor are released, which is what makes the two
  ## halves of this test differ at all.
  hand_vec <- c("MEG-131", "TEF-068", "TEF-068", "TEF-069")
  without_salv <- .make_pair(active_id = "PRE-035", hand_id_vec = hand_vec,
                             turn_number = 2L)
  expect_true(is.null(.ultra_ball_discards(without_salv)))

  with_salv <- .make_pair(active_id = "PRE-035",
                          hand_id_vec = c(hand_vec, "TEF-160"),
                          turn_number = 2L)
  discard_vec <- .ultra_ball_discards(with_salv)

  expect_length(discard_vec, 2)
  ## One Bronzor is released, the other still protected as the last copy.
  expect_equal(sum(discard_vec == "TEF-068"), 1)
})

test_that("Ultra Ball follows the playbook's discard ORDER", {
  ## Transcribed from docs/03a_card_playbook.md: Special Red Card, then Boss's
  ## Orders, then surplus Duskull, and so on. Pinned because the list is one of
  ## the four questions still open there -- when Kevin changes it, this fails.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("MEG-131", "TEF-078", "MEG-114",
                                     "CRI-082", "PRE-035"),
                     turn_number = 2L)

  expect_equal(.ultra_ball_discards(pair), c("CRI-082", "MEG-114"))
})

test_that("a full replicate runs and conserves all 60 cards, over many seeds", {
  ## The broadest guard there is, and the one that has actually caught things:
  ## every defect above first appeared as a crash or a lost card in a sweep like
  ## this one. Both coin-flip branches and both scenarios, because the item lock
  ## changes which plays are legal on turn 2.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  grid_df <- expand.grid(seed_number = 1:12,
                         bool_going_first = c(FALSE, TRUE),
                         scenario = c("clear", "item_lock"),
                         stringsAsFactors = FALSE)

  for(i in seq_len(nrow(grid_df))){
    label_str <- paste0("seed ", grid_df$seed_number[i],
                        if(grid_df$bool_going_first[i]) " first" else " second",
                        " ", grid_df$scenario[i])
    pair <- play_replicate(decklist, card_df,
                           bool_going_first = grid_df$bool_going_first[i],
                           scenario = grid_df$scenario[i],
                           seed_number = grid_df$seed_number[i])

    expect_equal(.total_cards(pair$state), 60, info = label_str)
    expect_equal(sort(.card_multiset(pair$state)),
                 sort(decklist$card_id_vec), info = label_str)
    expect_true(pair$state$turn_number <= 2L, info = label_str)
  }
})

test_that("the policy source never reads the prizes or the deck", {
  ## ADR 0003, asserted statically because it cannot be asserted dynamically:
  ## reading a field leaves no trace in the state, so no amount of playing games
  ## can prove the policy did not peek. Grepping the source can.
  ##
  ## `believes_findable()` is the sanctioned route, and it reads the deck itself
  ## -- inside knowledge_claude.R, where the deduction is the player's own.
  ## Root-relative, matching .test_decklist()'s use of "decklists/": the shim
  ## runner sources everything from the project root.
  source_vec <- readLines(file.path("R", "decision_claude.R"))
  code_vec <- source_vec[!grepl("^\\s*#", source_vec)]

  expect_false(any(grepl("state\\$prize_vec", code_vec)))
  expect_false(any(grepl("state\\$deck_vec", code_vec)))
  ## And the sanctioned route is actually used, so the two above are not passing
  ## simply because the policy asks nothing at all.
  expect_true(any(grepl("believes_findable", code_vec)))
})

test_that("the policy is deterministic given a seed", {
  ## Part 6 will replay a seed to reproduce any trace it samples, so a policy
  ## that consulted the RNG outside the seeded path would make every trace
  ## unreproducible -- and the trace file promises reproducibility explicitly.
  card_df <- .test_card_df()
  decklist <- .test_decklist()

  first_log_vec <- readable_log(play_replicate(decklist, card_df,
                                               bool_going_first = FALSE,
                                               seed_number = 5L)$state)
  second_log_vec <- readable_log(play_replicate(decklist, card_df,
                                                bool_going_first = FALSE,
                                                seed_number = 5L)$state)

  expect_true(length(first_log_vec) > 0)
  expect_equal(first_log_vec, second_log_vec)
})

# ---------------------------------------------------------------------------
# Checks Kevin asked for on 2026-08-29
# ---------------------------------------------------------------------------

test_that("Run Errand is used whenever Kangaskhan is Active", {
  ## The policy skipped it entirely, which is why Kangaskhan looked like a poor
  ## lead in the first demo run -- it was being judged with its whole upside
  ## switched off. It must also fire BEFORE positioning, since the section 4.3
  ## ladder is about to move Kangaskhan out of the only spot the Ability works.
  pair <- .make_pair(active_id = "MEG-104", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L)
  num_before <- length(pair$state$hand_vec)

  pair <- policy_turn(pair)

  expect_true(any(grepl("Run Errand", pair$state$event_log)))
  ## Two drawn, one Switch spent moving Bronzor up: net +1.
  expect_equal(length(pair$state$hand_vec), num_before + 1)
  expect_equal(top_card(pair$state$active), "TEF-068")

  ## Once per turn only, and never while it is on the Bench.
  benched <- .make_pair(active_id = "TEF-068", bench_id_vec = "MEG-104",
                        turn_number = 2L)
  benched <- policy_turn(benched)
  expect_false(any(grepl("Run Errand", benched$state$event_log)))
})

test_that("Telepathic fetches two Basics even when only one is wanted", {
  ## Kevin, 2026-08-29: take both, because every card pulled out of the deck
  ## thins it, and a thinner deck is a better chance the next draw is the
  ## Bronzong the turn is missing. Declining the second target gives that up for
  ## nothing.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088",
                     turn_number = 2L)

  target_vec <- .telepathic_search_targets(pair)

  expect_length(target_vec, 2)
  expect_false(anyDuplicated(target_vec) > 0)
  ## Both must be things the card may legally take: Basic and [P].
  expect_true(all(ALLOWED_TARGET_LIST$telepathic(pair$state$card_df,
                                                 target_vec)))

  ## Capped by Bench space, not by appetite.
  full <- .make_pair(active_id = "TEF-068",
                     bench_id_vec = rep("PRE-035", 4),
                     hand_id_vec = "POR-088", turn_number = 2L)
  expect_length(.telepathic_search_targets(full), 1)
})

test_that("Latias ex leads the want-list when sub-goal C is what is blocked", {
  ## Kevin, 2026-08-29: Ultra Ball and Brock's Scouting are the cards that go
  ## and get Latias ex when the line is stuck on the Bench. Poke Pad cannot --
  ## Rule Box -- which is why Poke Pad ends up being the card that finds
  ## Bronzong.
  blocked <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                        turn_number = 2L)

  expect_true(.c_is_blocked(blocked))
  expect_equal(.want_vec(blocked)[1], "SSP-076")
  expect_true("SSP-076" %in% .brocks_targets(blocked))
  ## Poke Pad is not offered it, and falls through to Bronzong.
  expect_equal(.first_findable(blocked, .want_vec(blocked),
                               ALLOWED_TARGET_LIST$poke_pad), "TEF-069")

  ## Not blocked once a Switch is in hand, or once Latias ex is already down.
  with_switch <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                            hand_id_vec = "MEG-130", turn_number = 2L)
  expect_false(.c_is_blocked(with_switch))

  with_latias <- .make_pair(active_id = "PRE-035",
                            bench_id_vec = c("TEF-068", "SSP-076"),
                            turn_number = 2L)
  expect_false(.c_is_blocked(with_latias))
})

test_that("Brock's Scouting is played for Latias ex even once A is met", {
  ## Its guard was "sub-goal A unmet", so with a Bronzor already benched and the
  ## line stuck there, the one Supporter that could fetch the Latias ex to
  ## unblock it was never chosen.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "JTG-146", turn_number = 2L)

  expect_false("A" %in% unmet_subgoals(pair$state))
  expect_equal(.choose_supporter(pair), "JTG-146")
})

# ---------------------------------------------------------------------------
# Alignment with docs/03_decision_tree.md, checked 2026-08-29
# ---------------------------------------------------------------------------

test_that("Buneary is the last lead on both branches", {
  ## Section 3, as ADR 0008 measured it. Buneary was §3's SECOND choice going
  ## second on the strength of Run Around, and the greedy search moved it to
  ## last -- which is the tree agreeing with itself rather than a surprise:
  ## §4.2 classes Run Around as a last resort because it spends the turn's
  ## Energy attachment and strands the Energy on the Bench, so a lead whose one
  ## virtue the rest of the tree declines to use is not a virtue.
  ##
  ## Duskull is the comparison because it is ranked immediately above Buneary
  ## going second and well above it going first; if Buneary were still second,
  ## the first expectation would return it.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  hand_vec <- c("PFL-083", "PRE-035")

  second <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  second <- move_cards(second, hand_vec, from = "deck", to = "hand")
  expect_equal(policy_placement(second)$active_card_id, "PRE-035")

  first <- new_game_state(decklist, card_df, bool_going_first = TRUE)
  first <- move_cards(first, hand_vec, from = "deck", to = "hand")
  expect_equal(policy_placement(first)$active_card_id, "PRE-035")
})

test_that("Latias ex leads going second and not going first", {
  ## The other half of what ADR 0008's search moved, and the more surprising
  ## one: Skyliner works from the Bench, so leading Latias ex looks like a
  ## waste. Leading it gets the free retreat online on turn 1 at no card and no
  ## Bench slot, and turn 1 going second is the turn with the most to do.
  ##
  ## Going first it stays last, because the search found nothing there worth
  ## acting on -- so this pair also pins the fact that the two branches are
  ## allowed to differ.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  hand_vec <- c("SSP-076", "PRE-035")

  second <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  second <- move_cards(second, hand_vec, from = "deck", to = "hand")
  expect_equal(policy_placement(second)$active_card_id, "SSP-076")

  first <- new_game_state(decklist, card_df, bool_going_first = TRUE)
  first <- move_cards(first, hand_vec, from = "deck", to = "hand")
  expect_equal(policy_placement(first)$active_card_id, "PRE-035")
})

test_that("no shuffling Item is played while a stack is pending", {
  ## Sections 5 and 7. Every search Item in the deck shuffles, so a pending
  ## stack skips the whole step rather than filtering inside it.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "POR-081",
                     turn_number = 2L)
  pair$knowledge <- knowledge_after_stacking(pair$knowledge, "TEF-069")

  expect_true(.stack_is_pending(pair))
  after <- .policy_search_items(pair)
  expect_true("POR-081" %in% after$state$hand_vec)

  ## Once the stack has been drawn, the Item is playable again.
  pair$knowledge <- knowledge_after_draw(pair$knowledge, num_cards = 1L)
  expect_false(.stack_is_pending(pair))
  expect_false("POR-081" %in% .policy_search_items(pair)$state$hand_vec)
})

test_that("Brock's Scouting falls to Evolution mode once Hilda is gone", {
  ## Section 6 priority 3. While Hilda is reachable the slot is worth more to
  ## her -- she fetches the Bronzong AND an Energy.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "JTG-146",
                     turn_number = 2L)

  ## Hilda still in the deck: Evolution mode declined.
  expect_true(is.null(.brocks_evolution_target(pair)))

  ## Every Hilda gone, and Bronzong becomes the target.
  num_hilda <- as.integer(count_copies(pair$state, "WHT-084"))
  pair$state <- move_cards(pair$state, rep("WHT-084", num_hilda),
                           from = "deck", to = "discard")
  expect_equal(.brocks_evolution_target(pair), "TEF-069")
  expect_equal(.choose_supporter(pair), "JTG-146")

  played <- .play_chosen_supporter(pair, "JTG-146")
  expect_true(any(grepl("Brock's Scouting (evolution)",
                        played$state$event_log, fixed = TRUE)))
})

test_that("a Stadium is played, but never Mystery Garden", {
  ## Section 4.2 step 6. It changes no rate -- but a Stadium in play is part of
  ## the end-of-turn-2 board state ADR 0007 records in full.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TWM-153",
                     turn_number = 2L)
  expect_equal(.policy_stadium(pair)$state$stadium, "TWM-153")

  ## Mystery Garden is excluded: the playbook reads it as costing a [P] source
  ## to draw, which is the one Stadium that could work against sub-goal D.
  garden <- .make_pair(active_id = "TEF-068", hand_id_vec = "MEG-122",
                       turn_number = 2L)
  expect_true(is.na(.policy_stadium(garden)$state$stadium))

  ## And not twice in a turn.
  once <- .policy_stadium(pair)
  once$state$hand_vec <- c(once$state$hand_vec, "TWM-149")
  expect_equal(.policy_stadium(once)$state$stadium, "TWM-153")
})

test_that("the want-list chases Meowth ex but never a second Bronzor", {
  ## docs/03a_card_playbook.md -> Search priority: "Two things the list does not
  ## chase". A second Bronzor is insurance against a Knock Out this window cannot
  ## produce, and it cost 1.4 points where it used to sit; Meowth ex stays, but
  ## only for a search that puts cards in HAND.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  want_vec <- .want_vec(pair)

  expect_false("TEF-068" %in% want_vec)
  expect_true("POR-062" %in% want_vec)
  ## Duskull is filler and stays last.
  expect_equal(want_vec[length(want_vec)], "PRE-035")

  ## bool_to_hand = FALSE is what Poffin and Telepathic pass: a Meowth ex
  ## fetched onto the Bench never triggers Last-Ditch Catch, so it is not a
  ## target for them at all.
  expect_false("POR-062" %in% .want_vec(pair, bool_to_hand = FALSE))
  expect_false("POR-062" %in% .telepathic_search_targets(pair))
})

test_that("the attachment is declined once sub-goal D is already paid", {
  ## docs/03_decision_tree.md section 4.2 step 6, from S-11: a second Telepathic
  ## onto a line that already carries a [P] source buys a search whose fetches
  ## fill the Bench slots section 4.4 is holding. The Energy stays in hand.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088",
                     turn_number = 2L)
  pair$state$active$energy_vec <- "POR-088"

  after <- .policy_energy(pair)

  expect_length(after$state$active$energy_vec, 1)
  expect_true("POR-088" %in% after$state$hand_vec)

  ## The negative case, with the card still in hand: with D unpaid it DOES
  ## attach. Without this half the test passes against a policy that has simply
  ## stopped attaching anything.
  unpaid <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088",
                       turn_number = 2L)
  expect_length(.policy_energy(unpaid)$state$active$energy_vec, 1)
})

test_that("sub-goal C counts as blocked while the Bronzor is still in hand", {
  ## docs/03a_card_playbook.md -> "*blocked* is prospective". From S-06: by the
  ## time the Bronzor has been benched the searches that could have found the
  ## mover are spent, so Latias ex has to rise BEFORE it is played.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-068",
                     turn_number = 1L)

  expect_true(.c_is_blocked(pair))
  expect_equal(.want_vec(pair)[1], "SSP-076")

  ## Still false when a mover is available, Bronzor in hand or not.
  with_switch <- .make_pair(active_id = "PRE-035",
                            hand_id_vec = c("TEF-068", "MEG-130"),
                            turn_number = 1L)
  expect_false(.c_is_blocked(with_switch))
})

test_that("Hilda takes both searches once she is played", {
  ## docs/03a_card_playbook.md -> Hilda: "the two searches are independent and
  ## declining one gains nothing". Kevin's S-02 answer -- make sure Hilda always
  ## grabs an Energy -- is the Energy half of this.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("WHT-084", "TEF-069", "POR-088"),
                     turn_number = 2L)
  target_list <- .hilda_targets(pair)

  expect_false(is.null(target_list$evo_id))
  expect_false(is.null(target_list$energy_id))

  ## Whether she is worth PLAYING is section 6's question and is unchanged: a
  ## redundant fetch does not by itself make her the right Supporter.
  expect_false(target_list$bool_worth_slot)
})

test_that("Meowth ex fetches Salvatore only when it can actually be cashed", {
  ## docs/03a_card_playbook.md -> Meowth ex, from S-06. Salvatore fixes sub-goal
  ## B alone, so fetching it without the Energy and the positioning already in
  ## place buys a card the turn cannot use. Hilda fixes B and D.
  bare <- .make_pair(active_id = "PRE-035", hand_id_vec = "POR-062",
                     turn_number = 1L)
  bare <- .policy_bench_meowth(bare)
  expect_true("WHT-084" %in% bare$state$hand_vec)
  expect_false("TEF-160" %in% bare$state$hand_vec)

  ## The negative case, with Meowth ex still in hand: C solved by the Active
  ## Bronzor and a [P] source held, so Salvatore IS the fetch.
  ready <- .make_pair(active_id = "TEF-068",
                      hand_id_vec = c("POR-062", "POR-088"),
                      turn_number = 1L)
  ready <- .policy_bench_meowth(ready)
  expect_true("TEF-160" %in% ready$state$hand_vec)
})

test_that("the Supporter slot is never left unspent while one is playable", {
  ## docs/03_decision_tree.md section 6 priority 8, from S-04: "it's important to
  ## play at least one Supporter a turn whenever possible". An eight-card hand
  ## put Lillie's below its four-card gate and Hilda had nothing to fetch, so the
  ## slot was dropped entirely.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("MEG-119", "TEF-069", "POR-088",
                                     "PRE-037", "PRE-037", "CRI-082",
                                     "MEG-114", "TWM-153"),
                     turn_number = 2L)

  expect_equal(.choose_supporter(pair), "MEG-119")
})

test_that("the fallback Supporter's cards are used on the turn it is played", {
  ## docs/03_decision_tree.md section 6 priority 8 and section 7 step 5. Kevin's
  ## S-04 answer is "play at least one Supporter a turn whenever possible if it
  ## even increases my chances to get set up" -- and a Lillie's played at the end
  ## of a turn whose eight cards are never played increases nothing. The window
  ## closes at the end of turn 2, so there is no later turn to spend them on.
  ##
  ## The deck is stacked to exactly what Lillie's will draw, because the shuffle
  ## is real: with 8 cards in the deck and hand, the draw-8 takes all of them and
  ## the assertion does not depend on the RNG.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "MEG-119",
                     turn_number = 2L)
  pair$state$deck_vec <- c("TEF-069", "POR-088", rep("PRE-035", 6))

  after <- .policy_build_turn(pair)

  expect_equal(top_card(after$state$active), "TEF-069")
  expect_true("MEG-119" %in% after$state$discard_vec)
  expect_true(after$state$turn_flag_list$bool_attacked)
})

test_that("Ciphermaniac's waits for a hand it can actually finish", {
  ## docs/03_decision_tree.md section 6 priority 7, from S-05. It delivers one
  ## card into turn 2's draw, so it is worth the slot only when exactly one of
  ## B, C and D is missing. Missing three, Lillie's replaces the whole hand.
  many <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("TEF-145", "MEG-119", "PRE-037"),
                     turn_number = 1L)
  expect_equal(.choose_supporter(many), "MEG-119")

  ## The negative case, with Ciphermaniac's still in hand: Bronzor Active and a
  ## [P] source attached, so B alone is missing and the stack finishes the job.
  one <- .make_pair(active_id = "TEF-068",
                    hand_id_vec = c("TEF-145", "MEG-119", "PRE-037"),
                    turn_number = 1L)
  one$state$active$energy_vec <- "POR-088"
  expect_equal(.choose_supporter(one), "TEF-145")
})

test_that("Salvatore is ranked against Hilda on turn 2", {
  ## docs/03_decision_tree.md section 6 priority 2 (DT-13, which arises in 23% of
  ## games). With the [P] source already secured Hilda's second search adds
  ## nothing, and Salvatore both fetches Bronzong and puts it on the Bronzor.
  secured <- .make_pair(active_id = "TEF-068",
                        hand_id_vec = c("TEF-160", "WHT-084"),
                        turn_number = 2L)
  secured$state$active$energy_vec <- "POR-088"
  expect_equal(.choose_supporter(secured), "TEF-160")

  ## The negative case, with Salvatore still in hand: no [P] source anywhere, so
  ## Hilda's two searches beat Salvatore's one.
  open <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("TEF-160", "WHT-084"),
                     turn_number = 2L)
  expect_equal(.choose_supporter(open), "WHT-084")
})

test_that("the Cursed Blast escape promotes a benched Bronzor", {
  ## docs/03_decision_tree.md section 4.3 rung 5 and section 8, from S-13. A
  ## Dusclops Active is a Stage 1, so Skyliner cannot free its retreat and Rare
  ## Candy cannot reach past it; its own Ability is the only door left.
  pair <- .make_pair(active_id = "PRE-036", bench_id_vec = "TEF-068",
                     turn_number = 2L)
  pair$state$bench_list[[1]]$energy_vec <- "SVE-005"

  after <- .policy_position(pair)

  expect_equal(top_card(after$state$active), "TEF-068")
  expect_true("PRE-036" %in% after$state$discard_vec)

  ## The negative case, with the Dusclops still Active: a free retreat under
  ## Latias ex does not exist for a Stage 1, but a Switch does, and rung 2 must
  ## win so the escape is never taken while a cheaper rung is open.
  cheap <- .make_pair(active_id = "PRE-036", bench_id_vec = "TEF-068",
                      hand_id_vec = "MEG-130", turn_number = 2L)
  cheap <- .policy_position(cheap)
  expect_equal(top_card(cheap$state$active), "TEF-068")
  expect_false("PRE-036" %in% cheap$state$discard_vec)
})

test_that("Ultra Ball never discards the Supporter chosen for this turn", {
  ## docs/03a_card_playbook.md -> Ultra Ball never-discard list, from S-05. The
  ## Salvatore clause generalised: a Supporter about to be played is not spare,
  ## and discarding it trades the whole slot for one search.
  ## Nothing else in this hand is on the discard ORDER at all, so every
  ## candidate ties and the first two in hand order go -- which without the
  ## protection is Hilda herself.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("MEG-131", "WHT-084", "MEG-119",
                                     "MEG-119"),
                     turn_number = 2L)

  expect_equal(.choose_supporter(pair), "WHT-084")
  expect_false("WHT-084" %in% .ultra_ball_discards(pair))
})

test_that("the section 3 lead order is a parameter, not a constant", {
  ## docs/03_decision_tree.md section 3: "the lead order is a policy parameter
  ## that part 6 varies across runs, not a constant compiled into the policy".
  ## scripts/tune_lead_order_claude.R is what varies it, and a hardcoded order
  ## would make that script silently measure the same thing twenty times.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  state <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  state <- move_cards(state, c("MEG-104", "PRE-035"), from = "deck",
                      to = "hand")

  ## The shipped order prefers Kangaskhan; an inverted one must prefer Duskull,
  ## from the same hand and the same state.
  expect_equal(policy_placement(state)$active_card_id, "MEG-104")

  flipped_list <- list(going_first = c("Bronzor", "Duskull",
                                       "Mega Kangaskhan ex"),
                       going_second = c("Bronzor", "Duskull",
                                        "Mega Kangaskhan ex"))
  expect_equal(policy_placement(state, flipped_list)$active_card_id, "PRE-035")
  ## And through the hook setup_game() actually calls, which takes `(state)`
  ## alone -- a factory that forgot to close over the order would pass the line
  ## above and fail here.
  place_fn <- make_policy_placement(flipped_list)
  expect_equal(place_fn(state)$active_card_id, "PRE-035")
})

test_that("a spare [P] source goes to a second Bronzong and never a Bronzor", {
  ## docs/03_decision_tree.md section 4.2 step 6, from S-18 and S-26. The two
  ## answers only look contradictory: S-18 attaches the spare to a second
  ## BRONZONG, S-26 declines to attach it beside a second BRONZOR. The rule is
  ## scoped to the evolved body, because that is the one that can attack.
  ##
  ## The negative case is asserted with the Energy STILL IN HAND, not by
  ## removing it: a rule that attaches nowhere and a rule that attaches only to
  ## a Bronzong are indistinguishable from the side that declines.
  bronzong <- .make_pair(active_id = "TEF-069", bench_id_vec = "TEF-069",
                         hand_id_vec = "POR-088", turn_number = 2L)
  bronzong$state$active$energy_vec <- "POR-088"

  after <- .policy_energy(bronzong)
  expect_length(after$state$bench_list[[1]]$energy_vec, 1)
  expect_false("POR-088" %in% after$state$hand_vec)

  bronzor <- .make_pair(active_id = "TEF-069", bench_id_vec = "TEF-068",
                        hand_id_vec = "POR-088", turn_number = 2L)
  bronzor$state$active$energy_vec <- "POR-088"

  declined <- .policy_energy(bronzor)
  expect_length(declined$state$bench_list[[1]]$energy_vec, 0)
  expect_true("POR-088" %in% declined$state$hand_vec)
})

test_that("Enriching Energy takes the attachment only when nothing else can", {
  ## docs/03a_card_playbook.md -> Enriching Energy, from S-22. It is [C], so it
  ## never pays sub-goal D -- but an attachment nobody claims is destroyed at
  ## end of turn, and attaching draws 4. Latias ex is the preferred recipient
  ## because [C] on the attacker buys nothing Evolution Jammer can spend.
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "SSP-076",
                     hand_id_vec = "SSP-191", turn_number = 1L)

  after <- .policy_enriching(pair)
  expect_length(after$state$bench_list[[1]]$energy_vec, 1)
  expect_length(after$state$active$energy_vec, 0)

  ## The negative case, with the Enriching still in hand: the attachment has
  ## already been spent this turn, so there is nothing left for it to take.
  spent <- .make_pair(active_id = "TEF-068", bench_id_vec = "SSP-076",
                      hand_id_vec = "SSP-191", turn_number = 1L)
  spent$state$turn_flag_list$bool_energy_attached <- TRUE

  declined <- .policy_enriching(spent)
  expect_true("SSP-191" %in% declined$state$hand_vec)
  expect_length(declined$state$bench_list[[1]]$energy_vec, 0)
})

test_that("Rare Candy reaches a benched Duskull once Bronzong is settled", {
  ## docs/03_decision_tree.md section 8, from S-19. The non-goal is about ORDER,
  ## not about the card: Bronzong first, always; Dusknoir with what is left
  ## over. Sub-goal B is met here, so nothing competes for the Rare Candy.
  won <- .make_pair(active_id = "TEF-069", bench_id_vec = "PRE-035",
                    hand_id_vec = c("MEG-125", "PRE-037"), turn_number = 2L)

  after <- .policy_leftover_rare_candy(won)
  expect_equal(top_card(after$state$bench_list[[1]]), "PRE-037")

  ## Turn 1, with both cards still in hand: the rung-5 escape needs exactly this
  ## pair on turn 2, and spending them early is how a turn-2 Duskull Active ends
  ## up with no door. Same board, one field different.
  early <- .make_pair(active_id = "TEF-069", bench_id_vec = "PRE-035",
                      hand_id_vec = c("MEG-125", "PRE-037"), turn_number = 1L)
  held <- .policy_leftover_rare_candy(early)
  expect_equal(top_card(held$state$bench_list[[1]]), "PRE-035")
  expect_true("PRE-037" %in% held$state$hand_vec)

  ## And never the Active, whose only job on turn 2 is to be the Bronzong.
  active_duskull <- .make_pair(active_id = "PRE-035",
                               bench_id_vec = "TEF-069",
                               hand_id_vec = c("MEG-125", "PRE-037"),
                               turn_number = 2L)
  untouched <- .policy_leftover_rare_candy(active_duskull)
  expect_equal(top_card(untouched$state$active), "PRE-035")
})

test_that("Dusknoir joins the want-list only when the escape is the only door", {
  ## docs/03_decision_tree.md section 8 and PB-17, from S-20. Every clause of
  ## the condition is load-bearing, so each negative case below removes exactly
  ## one of them from a board that otherwise qualifies.
  .escape_pair <- function(extra_vec = character(0)){
    pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                       hand_id_vec = c("MEG-125", "TEF-069", extra_vec),
                       turn_number = 2L)
    pair$state$bench_list[[1]]$energy_vec <- "POR-088"
    pair
  }

  pair <- .escape_pair()
  expect_true(.escape_is_only_route(pair))
  expect_equal(.want_vec(pair)[1], "PRE-037")
  ## Hilda is aimed at the Dusknoir rather than at a second Bronzong.
  expect_equal(.hilda_targets(pair)$evo_id, "PRE-037")

  ## A Switch in hand is a cheaper rung, so the escape is not the only door and
  ## the want-list reads as it always does -- asserted WITH the Rare Candy still
  ## in hand, since a promotion that never fires looks the same as one that
  ## fires correctly if the board cannot qualify at all.
  with_switch <- .escape_pair("MEG-130")
  expect_false(.escape_is_only_route(with_switch))
  expect_false(identical(.want_vec(with_switch)[1], "PRE-037"))

  ## And with sub-goal B open: one search cannot close both gaps, and B has no
  ## other route this turn either, so the Bronzong keeps the search.
  b_open <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                       hand_id_vec = "MEG-125", turn_number = 2L)
  b_open$state$bench_list[[1]]$energy_vec <- "POR-088"
  expect_false(.escape_is_only_route(b_open))
})

test_that("every Poke Pad in hand is played, not just the first", {
  ## docs/03a_card_playbook.md -> Poke Pad, from S-22. It costs nothing, so a
  ## copy held back is a free search thrown away and the window has no later
  ## turn to spend it on. Two copies, two gaps: the Bronzor and the Bronzong.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("POR-081", "POR-081"), turn_number = 1L)

  after <- .policy_search_items(pair)

  expect_false("POR-081" %in% after$state$hand_vec)
  expect_equal(sum(after$state$discard_vec == "POR-081"), 2)
})

test_that("the kill line never plays a Salvatore it no longer holds", {
  ## Found by scripts/tune_lead_order_claude.R, which crashed with "card TEF-160
  ## is not in zone 'hand'" the first time a candidate order made the sequence
  ## common. .kill_line_is_live() gates entry, but the free Items run INSIDE the
  ## line and can make it dead again: Ultra Ball protects Salvatore only while
  ## the line is live, and liveness reads believes_findable(), so a search that
  ## empties the deck of Bronzong releases the Salvatore onto the discard order.
  ## is_salvatore_target() then still answers TRUE, because it reads public
  ## information and keeps a prized Bronzong declarable -- so it is no
  ## substitute for holding the card.
  ##
  ## Simulated directly rather than reached through a shuffle: the point is that
  ## .policy_kill_line() survives a hand the Items have emptied, whatever
  ## emptied it.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("TEF-160", "POR-088"), turn_number = 1L)
  expect_true(.kill_line_is_live(pair))

  pair$state <- move_cards(pair$state, "TEF-160", from = "hand", to = "discard")

  expect_silent(after <- .policy_kill_line(pair))
  expect_false("TEF-160" %in% after$state$hand_vec)
  ## And the turn still gets played rather than abandoned: the attachment the
  ## ordinary build would make is the visible sign it fell through to it.
  expect_true(isTRUE(after$state$turn_flag_list$bool_energy_attached))
})

test_that("Gwynn is declined when it has nothing spare to pay with", {
  ## docs/03a_card_playbook.md -> Gwynn. "Up to 2" is literal and discarding
  ## nothing draws nothing, so a Gwynn played on a hand with no spare Pokemon
  ## spends the Supporter slot for zero cards. That is the one place in section
  ## 6 where the priority-8 fallback has a floor.
  ##
  ## The negative case holds a Bronzong and a Bronzor -- both Pokemon, both
  ## legal Gwynn targets by the card's own text, and both protected by the line
  ## rule. A version that only checked "is there a Pokemon in hand" passes the
  ## positive case below and fails here.
  no_spare <- .make_pair(active_id = "PRE-035",
                         hand_id_vec = c("PBL-078", "TEF-069", "TEF-068"),
                         turn_number = 2L)
  expect_length(.gwynn_discards(no_spare), 0)

  spare <- .make_pair(active_id = "PRE-035",
                      hand_id_vec = c("PBL-078", "PRE-037", "PRE-036"),
                      turn_number = 2L)
  discard_vec <- .gwynn_discards(spare)
  expect_length(discard_vec, 2)
  expect_false(any(c("PBL-078") %in% discard_vec))
})

test_that("Gwynn never discards a Pokemon with a Rule Box", {
  ## The card's own text excludes them, and play_gwynn() asserts it -- so a
  ## policy that named one would kill the replicate rather than misplay. Latias
  ## ex is the case that matters: it is the single most valuable Pokemon in
  ## hand AND it is illegal to discard, so the two reasons agree here and would
  ## not in general.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("PBL-078", "SSP-076", "POR-062",
                                     "PRE-037"),
                     turn_number = 2L)

  discard_vec <- .gwynn_discards(pair)

  expect_false("SSP-076" %in% discard_vec)
  expect_false("POR-062" %in% discard_vec)
  expect_true("PRE-037" %in% discard_vec)
})

test_that("the draw Supporters sit behind Ciphermaniac's, not ahead of it", {
  ## docs/03_decision_tree.md section 6, and the numbering error it fixes. The
  ## table once put Lillie's at 5 and Ciphermaniac's at 7 while the prose argued
  ## the reverse; measured, the table's order costs 1.92 points with a standard
  ## error of 0.22 (4,000 paired replicates, decklist2, going second), because
  ## Ciphermaniac's is a TUTOR for the one missing card and Lillie's is eight
  ## random cards out of forty.
  ##
  ## Bronzor Active with a [P] source attached, so B alone is missing and the
  ## stack finishes the job -- with Lillie's in hand and the hand short enough
  ## for its four-card gate to fire.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("TEF-145", "MEG-119", "PRE-037"),
                     turn_number = 1L)
  pair$state$active$energy_vec <- "POR-088"

  expect_equal(.choose_supporter(pair), "TEF-145")
})

test_that("Risky Ruins is never played, because it damages our own Bench", {
  ## docs/03_decision_tree.md section 4.2 step 7 plays a Stadium only when it is
  ## not disruptive to us, and "any player" in Risky Ruins' text includes this
  ## one. With no opposing board modelled the whole effect falls on our Bench.
  ##
  ## Jamming Tower in the same hand is the control: the step must still play a
  ## Stadium, so a rule that switched the whole step off would pass a test that
  ## only checked Risky Ruins stayed in hand.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("MEG-127", "TWM-153"), turn_number = 1L)

  after <- .policy_stadium(pair)

  expect_equal(after$state$stadium, "TWM-153")
  expect_true("MEG-127" %in% after$state$hand_vec)

  ## And alone, it is simply not played and the Stadium slot stays empty.
  alone <- .make_pair(active_id = "PRE-035", hand_id_vec = "MEG-127",
                      turn_number = 1L)
  expect_true(is.na(.policy_stadium(alone)$state$stadium))
})

test_that("Meowth ex is not benched for a Supporter that can never be played", {
  ## docs/03_decision_tree.md section 4.4: "wanted" means playable. On turn 2
  ## with the Supporter slot already spent the fetched card can never be played
  ## at all, so benching for it trades a Bench slot for a card that sits in hand
  ## while the turn misses. Found in S-27's own appendix line.
  ##
  ## The two halves differ ONLY in the spent-slot flag, and Meowth ex is in hand
  ## in both -- a rule that never benched it would pass the negative case and
  ## fail the positive one.
  unspent <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-062",
                        turn_number = 2L)
  after <- .policy_bench_meowth(unspent)
  expect_equal(length(after$state$bench_list), 1)

  spent <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-062",
                      turn_number = 2L)
  spent$state$turn_flag_list$bool_supporter_played <- TRUE
  held <- .policy_bench_meowth(spent)
  expect_length(held$state$bench_list, 0)
  expect_true("POR-062" %in% held$state$hand_vec)

  ## And on turn 1 GOING FIRST the fetch is still right, even though no
  ## Supporter is legal that turn: the card is for turn 2. This is the case a
  ## naive `can_play_supporter()` guard would break, and section 5 step 1 calls
  ## it the one branch where benching Meowth ex is close to automatic.
  first <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-062",
                      turn_number = 1L, bool_going_first = TRUE)
  expect_equal(length(.policy_bench_meowth(first)$state$bench_list), 1)
})

test_that("Latias ex counts as in play when it is the ACTIVE, not just benched", {
  ## docs/03a_card_playbook.md want-list item 4: "**Latias ex** -- if NOT IN
  ## PLAY and Bronzor is not Active". Three predicates read "in play" as
  ## "on the Bench" via .bench_idx_named(), which never inspects state$active.
  ##
  ## That was survivable while Latias ex was the LAST lead in section 3. ADR
  ## 0008 moved it to FIRST going second, so an Active Latias ex is now the most
  ## common opening on the strong branch -- and decklist7 runs two copies, so
  ## the searches chase a redundant one with a real Ultra Ball.
  active_latias <- .make_pair(active_id = "SSP-076",
                              bench_id_vec = "TEF-068", turn_number = 2L,
                              decklist_name = "decklist7")
  expect_false("SSP-076" %in% .want_vec(active_latias))
  expect_false(.c_is_blocked(active_latias))

  ## The benched case must keep working, so this is not simply "never want it".
  no_latias <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                          turn_number = 2L, decklist_name = "decklist7")
  expect_true("SSP-076" %in% .want_vec(no_latias))
  expect_true(.c_is_blocked(no_latias))
})

test_that("Latias ex leaves the want-list once a BRONZOR is Active", {
  ## Same want-list item 4, second clause: "and **Bronzor** is not Active". The
  ## code tested status_vec[["c"]], which is a BRONZONG Active -- so with a
  ## Bronzor Active, one evolution from C, it still wanted a mover it does not
  ## need.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)

  expect_false("SSP-076" %in% .want_vec(pair))
})

test_that("Ultra Ball never spends the last Rare Candy", {
  ## docs/03a_card_playbook.md -> Ultra Ball lists "**surplus** Rare Candy", and
  ## the Rare Candy entry says "never spending a copy the rung-5 escape still
  ## needs". Rare Candy had no protection at all: it sat on the discard order
  ## and the only copy was spendable.
  ##
  ## decklist7 and decklist8 run ONE Rare Candy, so a single Ultra Ball could
  ## destroy the section 4.3 rung-5 escape for the whole game.
  only_copy <- .make_pair(active_id = "PRE-035",
                          hand_id_vec = c("MEG-131", "MEG-125", "MEG-114",
                                          "TEF-078"),
                          turn_number = 2L)
  expect_false("MEG-125" %in% .ultra_ball_discards(only_copy))

  ## The surplus stays spendable, which is what "beyond 1" means -- asserted
  ## with a second copy in hand rather than by its absence.
  ## Boss's Orders is the second spare, so the pair is a protected-copy test
  ## rather than a "fewer than 2 remain" test by accident.
  surplus <- .make_pair(active_id = "PRE-035",
                        hand_id_vec = c("MEG-131", "MEG-125", "MEG-125",
                                        "MEG-114"),
                        turn_number = 2L)
  expect_equal(sum(.ultra_ball_discards(surplus) == "MEG-125"), 1)
})

test_that("Ultra Ball keeps one Duskull, as 'surplus beyond 1' says", {
  ## The same clause, one line up the order. A hand holding exactly one Duskull
  ## discarded it; the Duskull is the base of the Cursed Blast escape.
  one_duskull <- .make_pair(active_id = "TEF-068",
                            hand_id_vec = c("MEG-131", "PRE-035", "MEG-114",
                                            "TEF-078"),
                            turn_number = 2L)
  expect_false("PRE-035" %in% .ultra_ball_discards(one_duskull))

  two_duskull <- .make_pair(active_id = "TEF-068",
                            hand_id_vec = c("MEG-131", "PRE-035", "PRE-035",
                                            "MEG-114"),
                            turn_number = 2L)
  expect_equal(sum(.ultra_ball_discards(two_duskull) == "PRE-035"), 1)
})

test_that("Hilda's Energy search takes ANY Energy, including Darkness", {
  ## docs/03a_card_playbook.md -> Hilda: "the Energy search takes **any** Energy
  ## card when no [P] source is findable, since her text is not restricted to
  ## [P]. A whiff on the Energy search therefore means something sharp: every
  ## Energy in the list is prized or discarded."
  ##
  ## The want vector was the literal c(Telepathic, Psychic, Enriching), so basic
  ## Darkness Energy was invisible -- and decklist7 runs three of them and no
  ## basic Psychic at all. Hilda could report DECLINED with Energy still in the
  ## deck, which is exactly the inference the document says a whiff licenses.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "WHT-084",
                     turn_number = 2L, decklist_name = "decklist7")
  ## Strip every [P] source and the Enriching from the deck, so Darkness is the
  ## only Energy left to find.
  drop_vec <- pair$state$deck_vec[pair$state$deck_vec %in%
                                    c("POR-088", "SVE-005", "SSP-191")]
  pair$state <- move_cards(pair$state, drop_vec, from = "deck", to = "discard")

  expect_equal(.hilda_targets(pair)$energy_id, "MEE-007")
})

test_that("the Telepathic goes to the [P] Bronzor when the board offers both", {
  ## docs/03a_card_playbook.md -> Telepathic Psychic Energy: "With both a Metal
  ## and a [P] Bronzor available, put it on the [P] one so the search fires."
  ## .energy_recipient() took bench_idx_vec[1] -- board order -- so a Metal
  ## Bronzor sitting in the first slot swallowed the attachment and fired
  ## nothing.
  ##
  ## Only reachable since decklist7 paired PBL 63 (Metal) with TEF 68 ([P]).
  ## The Metal one is deliberately FIRST on the Bench here; with the ordering
  ## reversed the old code passes by accident.
  pair <- .make_pair(active_id = "PRE-035",
                     bench_id_vec = c("PBL-063", "TEF-068"),
                     hand_id_vec = "POR-088", turn_number = 2L,
                     decklist_name = "decklist7")

  after <- .policy_energy(pair)

  expect_length(after$state$bench_list[[1]]$energy_vec, 0)
  expect_length(after$state$bench_list[[2]]$energy_vec, 1)
})

test_that("a second Latias ex is not benched while one is already in play", {
  ## docs/03_decision_tree.md section 4.4 justifies benching Latias ex as "the
  ## one Basic whose presence alone advances a sub-goal". A second adds nothing
  ## and takes the slot section 2 calls the fourth scarce resource. decklist7
  ## and decklist8 run two copies, so this is reachable on two of eight lists.
  ##
  ## Asserted with the second copy STILL IN HAND, because a rule that never
  ## benches Latias ex at all would pass a bench-count check.
  second <- .make_pair(active_id = "PRE-035", bench_id_vec = "SSP-076",
                       hand_id_vec = "SSP-076", turn_number = 2L,
                       decklist_name = "decklist7")
  after <- .policy_bench(second)
  expect_length(after$state$bench_list, 1)
  expect_true("SSP-076" %in% after$state$hand_vec)

  ## The first copy is still benched at the first opportunity.
  first <- .make_pair(active_id = "PRE-035", hand_id_vec = "SSP-076",
                      turn_number = 2L, decklist_name = "decklist7")
  expect_length(.policy_bench(first)$state$bench_list, 1)
})

test_that("Ultra Ball protects one [P] source, not one of each printing", {
  ## docs/03a_card_playbook.md -> Ultra Ball, "Never discard: **the only** [P]
  ## source". Singular. The keep list seeded single_vec with both printings and
  ## kept one copy of EACH, so a hand holding a Telepathic and a basic Psychic
  ## protected both -- and protecting a second source can push the discardable
  ## count below 2 and make Ultra Ball unplayable, which is the exact failure
  ## the "fewer than 2 remain" clause describes.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("MEG-131", "POR-088", "SVE-005",
                                     "MEG-114"),
                     turn_number = 2L, decklist_name = "decklist5")

  discard_vec <- .ultra_ball_discards(pair)

  expect_length(discard_vec, 2)
  ## Exactly one [P] source is spendable, and the Telepathic is the one kept,
  ## because it also searches.
  expect_true("SVE-005" %in% discard_vec)
  expect_false("POR-088" %in% discard_vec)
})

test_that("Meowth ex leaves the want-list once no Supporter can be played", {
  ## docs/03a_card_playbook.md want-list item 6: "**Meowth ex** -- **if a
  ## Supporter is still wanted** and Meowth ex is unplayed". The first clause
  ## was missing from .want_vec() entirely, so on turn 2 with the slot already
  ## spent an Ultra Ball would still pay two discards for a Meowth ex whose
  ## Ability cannot be cashed. .policy_bench_meowth() already carries the gate;
  ## the want-list did not.
  spent <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  spent$state$turn_flag_list$bool_supporter_played <- TRUE
  expect_false("POR-062" %in% .want_vec(spent))

  unspent <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  expect_true("POR-062" %in% .want_vec(unspent))
})

test_that("one multi-target search never fetches two Bronzor printings", {
  ## docs/03a_card_playbook.md -> "Two things the list does not chase: **a
  ## second Bronzor as insurance**", which cost 1.4 points where it used to sit
  ## on the list.
  ##
  ## .want_vec() emits every Bronzor PRINTING as its own entry, and the
  ## multi-target loops walk those entries one at a time -- so in decklist7,
  ## which runs PBL 63 alongside two TEF 68, a single Buddy-Buddy Poffin or
  ## Brock's Scouting fetches one of each. Invisible on the six single-printing
  ## lists, which is why it survived.
  pair <- .make_pair(active_id = "PRE-035", turn_number = 1L,
                     decklist_name = "decklist7")

  target_vec <- .brocks_targets(pair)
  name_vec <- lookup_card(pair$state$card_df, target_vec)$name

  expect_true(sum(name_vec == "Bronzor") <= 1)
  ## And it still fetches ONE, so this is not "stop wanting Bronzor at all".
  expect_equal(sum(name_vec == "Bronzor"), 1)
})

test_that("Brock's Basics mode is not chosen for a Bronzor already in hand", {
  ## docs/03_decision_tree.md section 6 priority 4 fires Basics mode "when a
  ## Bronzor is **missing**", and 03a's want-list defines missing as "none in
  ## play **and none in hand**". The code read only !status_vec[["a"]] -- none
  ## in PLAY -- so with a Bronzor in hand the Supporter slot went to Brock's at
  ## priority 4, ahead of priorities 5 to 7, and .brocks_targets() then returned
  ## filler because .want_vec() had already dropped Bronzor.
  ## Two things are deliberately arranged. Hilda is ABSENT, or priority 3 fires
  ## first and the test passes without reaching priority 4. And a Latias ex is
  ## BENCHED, so `.c_is_blocked()` is FALSE -- priority 4's other trigger --
  ## leaving the Bronzor clause as the only thing under test.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "SSP-076",
                     hand_id_vec = c("JTG-146", "TEF-068"), turn_number = 2L)
  expect_false(.c_is_blocked(pair))
  expect_false(identical(.choose_supporter(pair, bool_fallback = FALSE),
                         "JTG-146"))

  ## With no Bronzor in play OR in hand, Basics mode is exactly right and still
  ## fires -- the same board, one card different.
  missing <- .make_pair(active_id = "PRE-035", bench_id_vec = "SSP-076",
                        hand_id_vec = "JTG-146", turn_number = 2L)
  expect_equal(.choose_supporter(missing, bool_fallback = FALSE), "JTG-146")
})

test_that("sub-goal D is independent of C, as section 1 says", {
  ## docs/03_decision_tree.md section 1: "Treat them as four **independent**
  ## sub-goals". .subgoal_status() defined D as `bool_c && has_..._cost(...)`,
  ## so a Bronzong sitting on the Bench with a [P] source attached reported D
  ## unmet. The field is read nowhere today, which is why it never surfaced --
  ## but the header map points section 1 at this function, so it should compute
  ## what section 1 describes.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-069",
                     turn_number = 2L)
  pair$state$bench_list[[1]]$energy_vec <- "POR-088"

  status_vec <- .subgoal_status(pair$state)

  expect_true(status_vec[["a"]])
  expect_true(status_vec[["b"]])
  expect_false(status_vec[["c"]])
  expect_true(status_vec[["d"]])
})

test_that("the leftover Rare Candy fires before a fallback Lillie's buries it", {
  ## docs/03_decision_tree.md section 6 priority 8: "the fallback fires **after**
  ## every other play of the turn has resolved, so Lillie's never shuffles away
  ## a card the turn still meant to use." Five plays ran after it -- the Stadium
  ## (section 4.2 step 7), Pokegear, the section 8 leftover Rare Candy, Run
  ## Around and the Enriching.
  ##
  ## The Rare Candy is the one that actually loses a card: section 4.4's
  ## bench-before-Lillie's rule saves BASICS, and the Dusknoir the rule needs is
  ## a Stage 2, so Lillie's shuffled it into the deck and the evolution never
  ## happened.
  ##
  ## Five cards in hand, so the mid-turn priority-7 gate (four or fewer) does
  ## NOT fire and the Lillie's is genuinely the priority-8 fallback.
  pair <- .make_pair(active_id = "TEF-069", bench_id_vec = "PRE-035",
                     hand_id_vec = c("MEG-125", "PRE-037", "MEG-119",
                                     "MEG-114", "TEF-078"),
                     turn_number = 2L)
  pair$state$active$energy_vec <- "POR-088"

  after <- .policy_build_turn(pair)

  expect_equal(top_card(after$state$bench_list[[1]]), "PRE-037")
  expect_true(any(grepl("Lillie's", after$state$event_log)))
})

test_that("Enriching Energy prefers a [C] attacker over a bystander", {
  ## docs/03a_card_playbook.md -> Enriching Energy: "**Latias ex** first, then
  ## another `[C]` attacker, and only then anything else". The rank vector had
  ## only two tiers plus the line -- Latias ex, then EVERYTHING else tied -- so
  ## which.min() took whichever body all_in_play() returned first and a Duskull
  ## beat a Mega Kangaskhan ex by sitting earlier on the Bench.
  ##
  ## The Duskull is deliberately in the FIRST Bench slot; with the order
  ## reversed the two-tier code passes by accident.
  pair <- .make_pair(active_id = "TEF-068",
                     bench_id_vec = c("PRE-035", "MEG-104"),
                     hand_id_vec = "SSP-191", turn_number = 1L)

  after <- .policy_enriching(pair)

  expect_length(after$state$bench_list[[1]]$energy_vec, 0)
  expect_length(after$state$bench_list[[2]]$energy_vec, 1)

  ## Latias ex still outranks the [C] attacker, so this is a third tier and not
  ## a replacement of the first.
  with_latias <- .make_pair(active_id = "TEF-068",
                            bench_id_vec = c("MEG-104", "SSP-076"),
                            hand_id_vec = "SSP-191", turn_number = 1L)
  after_latias <- .policy_enriching(with_latias)
  expect_length(after_latias$state$bench_list[[2]]$energy_vec, 1)

  ## And the line is still last: with nothing but the Active Bronzor it goes
  ## there, because an unspent attachment is destroyed either way.
  alone <- .make_pair(active_id = "TEF-068", hand_id_vec = "SSP-191",
                      turn_number = 1L)
  expect_length(.policy_enriching(alone)$state$active$energy_vec, 1)
})
