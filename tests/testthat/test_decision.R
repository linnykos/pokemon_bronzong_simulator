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

  ## Each row is a hand; the expected lead is the highest-ranked Basic present.
  case_list <- list(list(hand = c("PRE-035", "MEG-104"), lead = "MEG-104"),
                    list(hand = c("PRE-035", "PFL-083"), lead = "PFL-083"),
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
  ## move_cards() rejected a hundred replicates into a run. Two Rare Candy,
  ## which the playbook's order lists as discardable.
  pair <- .make_pair(active_id = "PRE-035",
                     hand_id_vec = c("MEG-131", "MEG-125", "MEG-125"),
                     turn_number = 2L)

  discard_vec <- .ultra_ball_discards(pair)

  expect_length(discard_vec, 2)
  expect_false(anyNA(discard_vec))
  expect_false("MEG-131" %in% discard_vec)
  expect_equal(discard_vec, c("MEG-125", "MEG-125"))

  ## And it declines rather than padding when there are not two to spare.
  thin <- .make_pair(active_id = "PRE-035", hand_id_vec = "MEG-131",
                     turn_number = 2L)
  expect_true(is.null(.ultra_ball_discards(thin)))
})

test_that("Ultra Ball protects the last copy but spends the surplus", {
  ## The playbook's never-discard list is about the LAST copy of each: "surplus
  ## Bronzong beyond 1" is explicitly IN the discard order while "the only
  ## Bronzong" is explicitly protected. Two Bronzong therefore leaves exactly
  ## one discardable card, and one is not two -- so the card is unplayable,
  ## which is the playbook's own rule rather than a shortfall.
  two_bronzong <- .make_pair(active_id = "PRE-035",
                             hand_id_vec = c("MEG-131", "TEF-069", "TEF-069"),
                             turn_number = 2L)
  expect_true(is.null(.ultra_ball_discards(two_bronzong)))

  ## With a spare alongside them, the surplus Bronzong goes and the last stays.
  with_spare <- .make_pair(active_id = "PRE-035",
                           hand_id_vec = c("MEG-131", "TEF-069", "TEF-069",
                                           "MEG-114"),
                           turn_number = 2L)
  discard_vec <- .ultra_ball_discards(with_spare)

  expect_length(discard_vec, 2)
  ## Boss's Orders is second in the playbook's order, so it goes first.
  expect_equal(discard_vec[1], "MEG-114")
  expect_equal(sum(discard_vec == "TEF-069"), 1)
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

test_that("Buneary is a lead going second and not going first", {
  ## Section 3: its whole case is Run Around, an ATTACK, so going first "the
  ## option does not exist at all". The code ranked it third either way.
  card_df <- .test_card_df()
  decklist <- .test_decklist()
  hand_vec <- c("PFL-083", "PRE-035")

  second <- new_game_state(decklist, card_df, bool_going_first = FALSE)
  second <- move_cards(second, hand_vec, from = "deck", to = "hand")
  expect_equal(policy_placement(second)$active_card_id, "PFL-083")

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
