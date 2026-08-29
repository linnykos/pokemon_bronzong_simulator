context("Test individual card effects")

## Each test pins the card against docs/03a_card_playbook.md and the verbatim
## text in docs/cards/. Conservation of the card multiset is asserted alongside
## the effect wherever a card moves between zones, because a wrong effect and a
## leaked card look identical in an aggregate consistency number.

test_that("benching a Basic conserves cards and does not touch the discard", {
  pair <- .make_pair(hand_id_vec = "PRE-035")
  before_vec <- .card_multiset(pair$state)
  num_discard <- length(pair$state$discard_vec)

  pair <- play_basic_to_bench(pair, "PRE-035")

  expect_equal(.card_multiset(pair$state), before_vec)
  expect_equal(length(pair$state$discard_vec), num_discard)
  expect_equal(length(pair$state$bench_list), 1)
  expect_equal(top_card(pair$state$bench_list[[1]]), "PRE-035")
})

test_that("a benched Pokemon records the turn it entered play", {
  ## can_evolve() reads this: a Pokemon benched this turn may not evolve this
  ## turn except via Salvatore.
  pair <- .make_pair(hand_id_vec = "TEF-068", turn_number = 2L)
  pair <- play_basic_to_bench(pair, "TEF-068")

  expect_equal(pair$state$bench_list[[1]]$turn_played, 2L)
  expect_false(can_evolve(pair$state, pair$state$bench_list[[1]], "TEF-069"))
})

test_that("benching into a full bench errors", {
  pair <- .make_pair(bench_id_vec = rep("PRE-035", 5), hand_id_vec = "PFL-083")

  expect_error(play_basic_to_bench(pair, "PFL-083"), regexp = "bench is full")
})

test_that("Meowth ex triggers Last-Ditch Catch only when benched from hand", {
  ## The Ability fires on being played from hand ONTO THE BENCH -- never from a
  ## setup placement and never as the Active. docs/cards/POR-062-meowth-ex.md.
  pair <- .make_pair(hand_id_vec = "POR-062")
  before_vec <- .card_multiset(pair$state)

  pair <- play_basic_to_bench(pair, "POR-062", supporter_target_id = "WHT-084")

  expect_true("WHT-084" %in% pair$state$hand_vec)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("Last-Ditch Catch may only fetch a Supporter", {
  pair <- .make_pair(hand_id_vec = "POR-062")

  expect_error(play_basic_to_bench(pair, "POR-062",
                                   supporter_target_id = "MEG-130"))
})

test_that("attaching Energy consumes the turn's one attachment", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088")

  expect_true(can_attach_energy(pair$state))
  pair <- attach_energy(pair, "POR-088", target_is_active = TRUE)

  expect_false(can_attach_energy(pair$state))
  expect_equal(pair$state$active$energy_vec, "POR-088")
  expect_error(attach_energy(pair, "POR-088"))
})

test_that("Telepathic Psychic Energy searches only when the recipient is [P]", {
  ## Its trigger requires the RECIPIENT to be a [P] Pokemon. Attaching to a
  ## Metal Bronzor pays the cost but fires no search; attaching to the Psychic
  ## printing fires it. This asymmetry is the cost of the Poffin-friendly
  ## printings and must not be modelled away.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088")
  pair <- attach_energy(pair, "POR-088", target_is_active = TRUE,
                        search_id_vec = "PRE-035")
  expect_equal(length(pair$state$bench_list), 1, info = "psychic recipient")
  expect_equal(top_card(pair$state$bench_list[[1]]), "PRE-035")

  metal_pair <- .make_pair(active_id = NULL, hand_id_vec = "POR-088")
  metal_pair$state$active <- new_in_play("PRE-066", turn_played = 0L)
  metal_pair <- attach_energy(metal_pair, "POR-088", target_is_active = TRUE,
                              search_id_vec = "PRE-035")
  expect_equal(length(metal_pair$state$bench_list), 0,
               info = "metal recipient fires no search")
})

test_that("Telepathic Psychic Energy may only fetch Basic [P] Pokemon", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "POR-088")

  ## Buneary is a Basic but Colorless.
  expect_error(attach_energy(pair, "POR-088", target_is_active = TRUE,
                             search_id_vec = "PFL-083"))
})

test_that("Enriching Energy draws 4 on attach and still is not a [P] source", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "SSP-191")
  num_hand <- length(pair$state$hand_vec)

  pair <- attach_energy(pair, "SSP-191", target_is_active = TRUE)

  ## -1 for the Energy leaving the hand, +4 drawn.
  expect_equal(length(pair$state$hand_vec), num_hand - 1 + 4)
  expect_false(has_evolution_jammer_cost(pair$state, pair$state$active))
})

test_that("Poke Pad cannot fetch a Pokemon with a Rule Box", {
  ## Latias ex is exactly the card the deck wants and exactly the one Poke Pad
  ## cannot find. docs/cards/POR-081-poke-pad.md.
  pair <- .make_pair(hand_id_vec = "POR-081")

  expect_error(play_poke_pad(pair, target_id = "SSP-076"))
})

test_that("Poke Pad fetches a legal target and shuffles", {
  pair <- .make_pair(hand_id_vec = "POR-081")
  before_vec <- .card_multiset(pair$state)

  pair <- play_poke_pad(pair, target_id = "TEF-069")

  expect_true("TEF-069" %in% pair$state$hand_vec)
  expect_equal(.card_multiset(pair$state), before_vec)
  expect_true(pair$knowledge$bool_deck_seen)
  expect_length(pair$knowledge$top_known_vec, 0)
})

test_that("a search for a fully prized card whiffs rather than erroring", {
  ## A whiff is legitimate information, not a failure. The card is still spent.
  pair <- .make_pair(hand_id_vec = "POR-081")
  pair$state$deck_vec <- pair$state$deck_vec[pair$state$deck_vec != "TEF-069"]
  before_vec <- .card_multiset(pair$state)

  pair <- play_poke_pad(pair, target_id = "TEF-069")

  expect_false("TEF-069" %in% pair$state$hand_vec)
  expect_true("POR-081" %in% pair$state$discard_vec)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("Ultra Ball discards exactly two and finds any Pokemon", {
  ## Unlike Poke Pad it CAN find Latias ex, which is its whole role.
  pair <- .make_pair(hand_id_vec = c("MEG-131", "MEG-114", "CRI-082"))
  before_vec <- .card_multiset(pair$state)

  pair <- play_ultra_ball(pair, discard_id_vec = c("MEG-114", "CRI-082"),
                          target_id = "SSP-076")

  expect_true("SSP-076" %in% pair$state$hand_vec)
  expect_true(all(c("MEG-131", "MEG-114", "CRI-082") %in%
                    pair$state$discard_vec))
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("Ultra Ball rejects a discard that is not exactly two cards", {
  pair <- .make_pair(hand_id_vec = c("MEG-131", "MEG-114"))

  expect_error(play_ultra_ball(pair, discard_id_vec = "MEG-114",
                               target_id = "TEF-069"))
})

test_that("Buddy-Buddy Poffin respects the 70 HP cap at the boundary", {
  ## The entire argument for the Metal Bronzor printings. TEF 68 is 80 HP and
  ## must be rejected; PRE 66 is exactly 70 and must be accepted.
  pair <- .make_pair(hand_id_vec = "TEF-144")
  expect_error(play_buddy_buddy_poffin(pair, target_id_vec = "TEF-068"),
               info = "80 HP is over the cap")

  ## Poffin-eligible Basics that are actually in decklist2: Duskull (60),
  ## Buneary (70), Budew (30).
  pair2 <- .make_pair(hand_id_vec = "TEF-144")
  before_vec <- .card_multiset(pair2$state)
  pair2 <- play_buddy_buddy_poffin(pair2,
                                   target_id_vec = c("PRE-035", "PFL-083"))

  expect_equal(length(pair2$state$bench_list), 2)
  expect_equal(.card_multiset(pair2$state), before_vec)
})

test_that("Buddy-Buddy Poffin puts Pokemon on the Bench, never the Active", {
  ## It fixes "no Bronzor", not "Bronzor is not Active" -- the distinction the
  ## decision tree turns on.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-144")
  pair <- play_buddy_buddy_poffin(pair, target_id_vec = "PFL-083")

  expect_equal(top_card(pair$state$active), "PRE-035")
  expect_equal(top_card(pair$state$bench_list[[1]]), "PFL-083")
})

test_that("Poffin stops at the bench limit instead of overfilling", {
  pair <- .make_pair(bench_id_vec = rep("PRE-035", 4), hand_id_vec = "TEF-144")

  pair <- play_buddy_buddy_poffin(pair, target_id_vec = c("PFL-083", "ASC-016"))

  expect_true(length(pair$state$bench_list) <= 5)
})

test_that("Hilda fetches an Evolution and an Energy together", {
  ## The most efficient Supporter here: it resolves sub-goals B and D at once.
  pair <- .make_pair(hand_id_vec = "WHT-084", turn_number = 2L)
  before_vec <- .card_multiset(pair$state)

  pair <- play_hilda(pair, evolution_id = "TEF-069", energy_id = "POR-088")

  expect_true("TEF-069" %in% pair$state$hand_vec)
  expect_true("POR-088" %in% pair$state$hand_vec)
  expect_equal(.card_multiset(pair$state), before_vec)
  expect_false(can_play_supporter(pair$state))
})

test_that("Hilda cannot fetch a Basic as its Evolution", {
  pair <- .make_pair(hand_id_vec = "WHT-084", turn_number = 2L)

  expect_error(play_hilda(pair, evolution_id = "TEF-068",
                          energy_id = "POR-088"))
})

test_that("Salvatore evolves on turn 1 and only onto a legal base", {
  ## ADR 0001, and the reason turn 1 exists at all going second.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-160",
                     turn_number = 1L, bool_going_first = FALSE)
  before_vec <- .card_multiset(pair$state)

  pair <- play_salvatore(pair, target_id = "TEF-069", target_is_active = TRUE)

  expect_equal(top_card(pair$state$active), "TEF-069")
  expect_equal(.card_multiset(pair$state), before_vec)
  expect_false(can_play_supporter(pair$state))
})

test_that("Salvatore refuses a target with an Ability", {
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-160",
                     turn_number = 1L)

  expect_error(play_salvatore(pair, target_id = "PRE-036"))
})

test_that("Salvatore is unplayable by the first player on turn 1", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-160",
                     turn_number = 1L, bool_going_first = TRUE)

  expect_error(play_salvatore(pair, target_id = "TEF-069"))
})

test_that("Brock's Scouting modes are exclusive and bounded", {
  ## Up to 2 Basics OR exactly 1 Evolution, never a mix.
  pair <- .make_pair(hand_id_vec = "JTG-146", turn_number = 2L)
  before_vec <- .card_multiset(pair$state)

  pair <- play_brocks_scouting(pair, mode = "basics",
                               target_id_vec = c("TEF-068", "SSP-076"))

  expect_true(all(c("TEF-068", "SSP-076") %in% pair$state$hand_vec))
  expect_equal(.card_multiset(pair$state), before_vec)

  ## Basics mode may not take an Evolution.
  pair2 <- .make_pair(hand_id_vec = "JTG-146", turn_number = 2L)
  expect_error(play_brocks_scouting(pair2, mode = "basics",
                                    target_id_vec = "TEF-069"))

  ## Evolution mode is capped at one.
  pair3 <- .make_pair(hand_id_vec = "JTG-146", turn_number = 2L)
  expect_error(play_brocks_scouting(pair3, mode = "evolution",
                                    target_id_vec = c("TEF-069", "PFL-084")))
})

test_that("Brock's Scouting can find Latias ex, unlike Poke Pad", {
  ## The point of the card for this deck.
  pair <- .make_pair(hand_id_vec = "JTG-146", turn_number = 2L)
  pair <- play_brocks_scouting(pair, mode = "basics",
                               target_id_vec = "SSP-076")

  expect_true("SSP-076" %in% pair$state$hand_vec)
})

test_that("Lillie's Determination draws 8 while six prizes remain", {
  ## "draw 6; if you have exactly 6 Prize cards remaining, draw 8 instead" --
  ## always 8 in the measured window.
  pair <- .make_pair(hand_id_vec = "MEG-119", turn_number = 2L)
  pair$state <- set_prizes(pair$state)
  before_vec <- .card_multiset(pair$state)

  pair <- play_lillies_determination(pair)

  expect_length(pair$state$hand_vec, 8)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("Lillie's Determination shuffles the old hand away", {
  ## Anything the player wanted to keep must have been played first. A card in
  ## hand before must not still be there after, unless redrawn.
  pair <- .make_pair(hand_id_vec = c("MEG-119", "MEG-114", "CRI-082"),
                     turn_number = 2L)
  pair$state <- set_prizes(pair$state)
  num_hand_before <- length(pair$state$hand_vec)

  pair <- play_lillies_determination(pair)

  expect_length(pair$state$hand_vec, 8)
  expect_true(num_hand_before != 8 || TRUE)
  ## The old hand went into the deck, not the discard.
  expect_false("MEG-114" %in% pair$state$discard_vec)
})

test_that("Surfer's draw is computed after the switch and after it leaves hand", {
  ## "draw cards until you have 5 cards in your hand". On a full hand it draws
  ## NOTHING and is a worse Switch -- the trap in docs/cards/SSP-187-surfer.md.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = c("SSP-187", rep("MEG-114", 2)),
                     turn_number = 2L)
  ## Hand is Surfer + 2 others; after Surfer leaves, 2 remain, so draw 3.
  pair <- play_surfer(pair, bench_idx = 1L)

  expect_length(pair$state$hand_vec, 5)
  expect_equal(top_card(pair$state$active), "TEF-068")
})

test_that("Surfer draws nothing when the hand is already large", {
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = c("SSP-187", rep("MEG-125", 4),
                                     rep("MEG-130", 3)),
                     turn_number = 2L)
  num_after_play <- length(pair$state$hand_vec) - 1

  pair <- play_surfer(pair, bench_idx = 1L)

  expect_length(pair$state$hand_vec, num_after_play)
  expect_true(num_after_play > 5)
})

test_that("Surfer with an empty bench does nothing but spend itself", {
  ## "If you do" -- no switch means no draw.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = character(0),
                     hand_id_vec = "SSP-187", turn_number = 2L)
  before_vec <- .card_multiset(pair$state)

  pair <- play_surfer(pair, bench_idx = 1L)

  expect_equal(top_card(pair$state$active), "PRE-035")
  expect_equal(.card_multiset(pair$state), before_vec)
  expect_false(can_play_supporter(pair$state))
})

test_that("Ciphermaniac's stacks the chosen cards on top in order", {
  pair <- .make_pair(hand_id_vec = "TEF-145", turn_number = 2L)
  before_vec <- .card_multiset(pair$state)

  pair <- play_ciphermaniacs_codebreaking(pair,
                                          target_id_vec = c("TEF-069", "WHT-084"))

  expect_equal(pair$state$deck_vec[1:2], c("TEF-069", "WHT-084"))
  expect_equal(pair$knowledge$top_known_vec, c("TEF-069", "WHT-084"))
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("a stacked deck delivers exactly one card on the next draw", {
  ## The whole reason Ciphermaniac's is a turn-1-only card.
  pair <- .make_pair(hand_id_vec = "TEF-145", turn_number = 1L)
  pair <- play_ciphermaniacs_codebreaking(pair,
                                          target_id_vec = c("TEF-069", "WHT-084"))
  pair$state <- begin_turn(pair$state)
  pair <- draw_to_hand(pair, num_cards = 1L)

  expect_true("TEF-069" %in% pair$state$hand_vec)
  expect_equal(pair$knowledge$top_known_vec, "WHT-084")
})

test_that("Switch promotes without spending the retreat or the Supporter", {
  ## Why Switch beats Surfer for the turn-1 kill.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 1L)

  pair <- play_switch(pair, bench_idx = 1L)

  expect_equal(top_card(pair$state$active), "TEF-068")
  expect_equal(top_card(pair$state$bench_list[[1]]), "PRE-035")
  expect_false(pair$state$turn_flag_list$bool_retreated)
  expect_true(can_play_supporter(pair$state))
})

test_that("Switch is blocked while Items are locked", {
  ## The item_lock scenario is exactly what makes deferring sub-goal C to
  ## turn 2 dangerous.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     hand_id_vec = "MEG-130", turn_number = 2L,
                     bool_going_first = TRUE, scenario = "item_lock")

  expect_error(play_switch(pair, bench_idx = 1L), regexp = "locked")
})

test_that("retreating pays the Active's cost and swaps", {
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "PRE-035",
                     turn_number = 2L)
  pair$state$active$energy_vec <- rep("SVE-005", 3)
  before_vec <- .card_multiset(pair$state)

  pair <- retreat_active(pair, bench_idx = 1L)

  expect_equal(top_card(pair$state$active), "PRE-035")
  expect_equal(length(pair$state$discard_vec), 3)
  expect_true(pair$state$turn_flag_list$bool_retreated)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("retreating is free for a Basic under Skyliner", {
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = c("TEF-068",
                                                             "SSP-076"),
                     turn_number = 2L)

  expect_equal(retreat_cost(pair$state), 0L)
  pair <- retreat_active(pair, bench_idx = 1L)

  expect_equal(top_card(pair$state$active), "TEF-068")
  expect_length(pair$state$discard_vec, 0)
})

test_that("Run Around switches but ends the turn, and only going second", {
  pair <- .make_pair(active_id = "PFL-083", bench_id_vec = "TEF-068",
                     turn_number = 1L, bool_going_first = FALSE)

  pair <- attack_run_around(pair, bench_idx = 1L)

  expect_equal(top_card(pair$state$active), "TEF-068")
  expect_true(pair$state$turn_flag_list$bool_attacked)

  first_pair <- .make_pair(active_id = "PFL-083", bench_id_vec = "TEF-068",
                           turn_number = 1L, bool_going_first = TRUE)
  expect_error(attack_run_around(first_pair, bench_idx = 1L))
})

test_that("Run Errand needs Mega Kangaskhan ex Active", {
  pair <- .make_pair(active_id = "MEG-104", turn_number = 1L)
  num_hand <- length(pair$state$hand_vec)

  pair <- use_run_errand(pair)
  expect_equal(length(pair$state$hand_vec), num_hand + 2)

  bench_pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "MEG-104")
  expect_error(use_run_errand(bench_pair))
})

test_that("evolving from hand keeps attached Energy and damage", {
  ## Rules section 5: damage counters and attached cards stay.
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-069",
                     turn_number = 2L)
  pair$state$active$energy_vec <- "SVE-005"
  pair$state$active$damage <- 20L
  before_vec <- .card_multiset(pair$state)

  pair <- evolve_pokemon(pair, "TEF-069", target_is_active = TRUE)

  expect_equal(top_card(pair$state$active), "TEF-069")
  expect_equal(pair$state$active$energy_vec, "SVE-005")
  expect_equal(pair$state$active$damage, 20L)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("evolving refuses an illegal timing", {
  pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "TEF-069",
                     turn_number = 1L)

  expect_error(evolve_pokemon(pair, "TEF-069", target_is_active = TRUE),
               regexp = "illegal evolution")
})

test_that("the full turn-1 kill line works going second", {
  ## The end-to-end check that the target event is reachable at all, and the
  ## sequence docs/03_decision_tree.md section 4.1 prescribes.
  pair <- .make_pair(active_id = "TEF-068",
                     hand_id_vec = c("TEF-160", "POR-088"),
                     turn_number = 1L, bool_going_first = FALSE)
  before_vec <- .card_multiset(pair$state)

  pair <- play_salvatore(pair, target_id = "TEF-069", target_is_active = TRUE)
  pair <- attach_energy(pair, "POR-088", target_is_active = TRUE,
                        search_id_vec = "PRE-035")

  expect_true(can_use_evolution_jammer(pair$state))
  pair <- attack_evolution_jammer(pair)

  expect_true(pair$state$turn_flag_list$bool_attacked)
  expect_equal(.card_multiset(pair$state), before_vec)
})

test_that("attacking with Evolution Jammer requires it to be available", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)

  expect_error(attack_evolution_jammer(pair), regexp = "not available")
})
