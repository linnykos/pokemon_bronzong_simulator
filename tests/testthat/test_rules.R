context("Test the legality rules")

test_that("the first player may not Supporter or attack on turn 1", {
  ## Rules section 6. This is the entire disadvantage of going first in this
  ## deck, and ADR 0004 rests on it: turn 1 is impossible going first, whatever
  ## Salvatore does.
  pair <- .make_pair(turn_number = 1L, bool_going_first = TRUE)

  expect_false(can_play_supporter(pair$state))
  expect_false(can_attack(pair$state))
})

test_that("the second player may Supporter and attack on turn 1", {
  pair <- .make_pair(turn_number = 1L, bool_going_first = FALSE)

  expect_true(can_play_supporter(pair$state))
  expect_true(can_attack(pair$state))
})

test_that("the first player's restrictions lift on turn 2", {
  ## The restriction is on the first TURN, not on the first player forever.
  pair <- .make_pair(turn_number = 2L, bool_going_first = TRUE)

  expect_true(can_play_supporter(pair$state))
  expect_true(can_attack(pair$state))
})

test_that("per-turn limits are one-shot", {
  grid_df <- expand.grid(flag_name = c("bool_supporter_played",
                                       "bool_energy_attached",
                                       "bool_attacked", "bool_retreated"),
                         stringsAsFactors = FALSE)

  for(i in seq_len(nrow(grid_df))){
    ## Bronzor's retreat cost is 3, so can_retreat() is FALSE for want of Energy
    ## rather than for want of the flag. Attach enough that the flag is the only
    ## thing under test -- otherwise this cell passes for the wrong reason.
    pair <- .make_pair(bench_id_vec = "PRE-035", turn_number = 2L)
    pair$state$active$energy_vec <- rep("SVE-005", 3)
    fn_vec <- list(bool_supporter_played = can_play_supporter,
                   bool_energy_attached = can_attach_energy,
                   bool_attacked = can_attack,
                   bool_retreated = can_retreat)
    one_flag <- grid_df$flag_name[i]

    expect_true(fn_vec[[one_flag]](pair$state), info = paste0(one_flag, " before"))
    pair$state$turn_flag_list[[one_flag]] <- TRUE
    expect_false(fn_vec[[one_flag]](pair$state), info = paste0(one_flag, " after"))
  }
})

test_that("can_attack is FALSE with no Active Pokemon", {
  pair <- .make_pair(active_id = NULL, turn_number = 2L)

  expect_false(can_attack(pair$state))
  expect_false(can_use_evolution_jammer(pair$state))
})

test_that("Items are locked only on our turn 2 in the item_lock scenario", {
  ## Itchy Pollen is an ATTACK, so the opponent could only have used it by
  ## going second -- i.e. only when we went first. It then lands on our turn 2.
  grid_df <- expand.grid(turn_number = 1:3,
                         bool_going_first = c(TRUE, FALSE),
                         scenario = c("clear", "item_lock"),
                         stringsAsFactors = FALSE)

  for(i in seq_len(nrow(grid_df))){
    pair <- .make_pair(turn_number = grid_df$turn_number[i],
                       bool_going_first = grid_df$bool_going_first[i],
                       scenario = grid_df$scenario[i])
    bool_expected <- !(grid_df$scenario[i] == "item_lock" &&
                         grid_df$bool_going_first[i] &&
                         grid_df$turn_number[i] == 2L)

    expect_equal(can_play_item(pair$state), bool_expected,
                 info = paste0("turn ", grid_df$turn_number[i],
                               " first=", grid_df$bool_going_first[i],
                               " ", grid_df$scenario[i]))
  }
})

test_that("evolution is blocked on your own first turn", {
  ## Rules section 5. A Bronzor placed at SETUP still cannot evolve on turn 1,
  ## which is what makes turn 2 the floor without Salvatore.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)

  expect_false(can_evolve(pair$state, pair$state$active, "TEF-069"))
})

test_that("Salvatore overrides the first-turn ban (ADR 0001)", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)

  expect_true(can_evolve(pair$state, pair$state$active, "TEF-069",
                         bool_via_salvatore = TRUE))
})

test_that("evolution is blocked on a Pokemon played this turn", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  pair$state$active$turn_played <- 2L

  expect_false(can_evolve(pair$state, pair$state$active, "TEF-069"))
  ## Salvatore's text covers exactly this case too.
  expect_true(can_evolve(pair$state, pair$state$active, "TEF-069",
                         bool_via_salvatore = TRUE))
})

test_that("a setup Bronzor may evolve normally on turn 2", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)

  expect_true(can_evolve(pair$state, pair$state$active, "TEF-069"))
})

test_that("a Pokemon may not evolve twice in one turn, even via Salvatore", {
  ## Salvatore exempts the setup/this-turn restrictions, NOT the once-per-turn
  ## one -- its text says nothing about evolving twice.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  pair$state$active$turn_evolved <- 2L

  expect_false(can_evolve(pair$state, pair$state$active, "TEF-069"))
  expect_false(can_evolve(pair$state, pair$state$active, "TEF-069",
                          bool_via_salvatore = TRUE))
})

test_that("evolution matches by NAME, so any Bronzor becomes Bronzong", {
  ## The three Bronzor printings are different cards sharing a name. All three
  ## must be legal bases for Bronzong TEF 69.
  for(one_bronzor in c("TEF-068", "PRE-066", "SSP-126")){
    pair <- .make_pair(active_id = NULL, turn_number = 2L)
    pair$state$active <- new_in_play(one_bronzor, turn_played = 0L)

    expect_true(can_evolve(pair$state, pair$state$active, "TEF-069"),
                info = one_bronzor)
  }
})

test_that("an evolution may not be played onto the wrong base", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)

  expect_false(can_evolve(pair$state, pair$state$active, "PRE-037"),
               info = "Dusknoir does not evolve from Bronzor")
  expect_false(can_evolve(pair$state, pair$state$active, "MEG-130"),
               info = "Switch is not an evolution")
})

test_that("Salvatore targets exclude anything with an Ability", {
  ## Bronzong has no Ability so it is legal; Dusclops and Dusknoir have Cursed
  ## Blast so they never are, whatever else is in play.
  pair <- .make_pair(active_id = "TEF-068",
                     bench_id_vec = c("PRE-035", "PFL-083"))

  expect_true(is_salvatore_target(pair$state, "TEF-069"))
  expect_true(is_salvatore_target(pair$state, "PFL-084"),
              info = "Mega Lopunny ex evolves from the benched Buneary")
  expect_false(is_salvatore_target(pair$state, "PRE-036"), info = "Dusclops")
  expect_false(is_salvatore_target(pair$state, "PRE-037"), info = "Dusknoir")
})

test_that("Salvatore needs a matching base in play", {
  ## With no Bronzor anywhere, Bronzong is not a legal target however
  ## Ability-less it is.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = character(0))

  expect_false(is_salvatore_target(pair$state, "TEF-069"))
})

test_that("retreat cost is the Active's cost, not the promoted Pokemon's", {
  ## The error corrected in the docs: retreating costs the retreat cost of the
  ## Pokemon LEAVING the Active spot. A benched Bronzor's cost of 3 is
  ## irrelevant to promoting it.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068")

  expect_equal(retreat_cost(pair$state), 1L, info = "Duskull retreats for 1")
})

test_that("Skyliner zeroes the retreat cost of a Basic only", {
  ## Latias ex works from the Bench and is live the moment it is in play.
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "SSP-076")
  expect_true(has_skyliner(pair$state))
  expect_equal(retreat_cost(pair$state), 0L, info = "Bronzor is a Basic")

  ## Bronzong is a Stage 1, so Skyliner does not apply to it.
  pair$state$active$stack_vec <- c(pair$state$active$stack_vec, "TEF-069")
  expect_equal(retreat_cost(pair$state), 3L)
})

test_that("without Latias ex the printed retreat cost applies", {
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "PRE-035")

  expect_false(has_skyliner(pair$state))
  expect_equal(retreat_cost(pair$state), 3L)
})

test_that("retreating needs enough attached Energy", {
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "PRE-035",
                     turn_number = 2L)
  expect_false(can_retreat(pair$state), info = "cost 3, no energy attached")

  pair$state$active$energy_vec <- rep("SVE-005", 3)
  expect_true(can_retreat(pair$state))
})

test_that("retreating is impossible with an empty bench", {
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = character(0),
                     turn_number = 2L)

  expect_false(can_retreat(pair$state))
})

test_that("Evolution Jammer needs a [P] source, and Enriching does not count", {
  ## Enriching Energy provides [C]. This is the assertion that stops the
  ## simulator overstating consistency.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 2L)
  pair$state$active$stack_vec <- c(pair$state$active$stack_vec, "TEF-069")

  expect_false(can_use_evolution_jammer(pair$state), info = "no energy")

  pair$state$active$energy_vec <- "SSP-191"
  expect_false(can_use_evolution_jammer(pair$state), info = "Enriching is [C]")

  pair$state$active$energy_vec <- "SVE-005"
  expect_true(can_use_evolution_jammer(pair$state), info = "basic Psychic")

  pair$state$active$energy_vec <- "POR-088"
  expect_true(can_use_evolution_jammer(pair$state), info = "Telepathic")
})

test_that("Evolution Jammer requires Bronzong to be Active, not benched", {
  ## Sub-goal C. A Bronzong on the Bench cannot attack, which the decision tree
  ## argues is the deck's real bottleneck.
  pair <- .make_pair(active_id = "PRE-035", bench_id_vec = "TEF-068",
                     turn_number = 2L)
  pair$state$bench_list[[1]]$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$bench_list[[1]]$energy_vec <- "SVE-005"

  expect_false(can_use_evolution_jammer(pair$state))
})

test_that("Evolution Jammer is unavailable to the first player on turn 1", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L,
                     bool_going_first = TRUE)
  pair$state$active$stack_vec <- c("TEF-068", "TEF-069")
  pair$state$active$energy_vec <- "SVE-005"

  expect_false(can_use_evolution_jammer(pair$state))
})

test_that("bench space is capped at five", {
  ## has_bench_space(n) asks whether n MORE will fit, so with 4 benched exactly
  ## one more fits and two do not.
  pair <- .make_pair(bench_id_vec = rep("PRE-035", 4))

  expect_true(has_bench_space(pair$state, 1L))
  expect_false(has_bench_space(pair$state, 2L))

  empty_pair <- .make_pair(bench_id_vec = character(0))
  expect_true(has_bench_space(empty_pair$state, 5L))
  expect_false(has_bench_space(empty_pair$state, 6L))

  full_pair <- .make_pair(bench_id_vec = rep("PRE-035", 5))
  expect_false(has_bench_space(full_pair$state, 1L))
  expect_true(has_bench_space(full_pair$state, 0L))
})

test_that("attacking ends the turn, not just the attack step", {
  ## Rules section 4: "Your turn ends immediately after you attack." The whole
  ## cost/benefit of Buneary's Run Around in the decision tree depends on this.
  ## Found by the spec audit: bool_attacked alone only blocked a SECOND attack,
  ## leaving Items, the Supporter, the attachment and the retreat all legal.
  pair <- .make_pair(active_id = "TEF-068", bench_id_vec = "PRE-035",
                     turn_number = 2L)
  expect_true(can_act(pair$state))

  pair$state$turn_flag_list$bool_turn_over <- TRUE

  expect_false(can_act(pair$state))
  expect_false(can_play_supporter(pair$state))
  expect_false(can_attach_energy(pair$state))
  expect_false(can_play_item(pair$state))
  expect_false(can_retreat(pair$state))
  expect_false(can_attack(pair$state))
})

test_that("Salvatore is illegal when every copy of the target is discarded", {
  ## The discard is public, so the game can see the target is gone. Prizes are
  ## not public, so a fully prized target stays declarable and simply whiffs --
  ## that asymmetry is what keeps this ADR 0003-consistent.
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)
  expect_true(is_salvatore_target(pair$state, "TEF-069"))

  num_bronzong <- as.integer(count_copies(pair$state, "TEF-069"))
  pair$state <- move_cards(pair$state, rep("TEF-069", num_bronzong),
                           from = "deck", to = "discard")

  expect_false(is_salvatore_target(pair$state, "TEF-069"))
})

test_that("a prized Salvatore target is still declarable", {
  pair <- .make_pair(active_id = "TEF-068", turn_number = 1L)
  num_bronzong <- as.integer(count_copies(pair$state, "TEF-069"))
  pair$state <- move_cards(pair$state, rep("TEF-069", num_bronzong),
                           from = "deck", to = "prize")

  expect_true(is_salvatore_target(pair$state, "TEF-069"))
})

# ---------------------------------------------------------------------------
# Rare Candy
# ---------------------------------------------------------------------------

test_that("Rare Candy allows the jump can_evolve correctly refuses", {
  ## The two predicates must disagree, and that is the point. can_evolve()
  ## matches `evolves_from` by name, so Duskull -> Dusknoir is illegal there and
  ## legal here; a single predicate with a flag would have had to weaken the
  ## name match for every card.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "PRE-037",
                     turn_number = 2L)

  expect_false(can_evolve(pair$state, pair$state$active, "PRE-037"))
  expect_true(can_rare_candy(pair$state, pair$state$active, "PRE-037"))
})

test_that("Rare Candy needs the Stage 2 in HAND, not in the deck", {
  ## Found by review, and it had already produced two false accusations in the
  ## demo trace file. Rare Candy does not search: a Dusknoir in the deck is no
  ## use at all. The trace diagnosis asks this predicate speculatively, so
  ## without the check it reported the Cursed Blast escape as an unused out
  ## precisely when the escape was impossible.
  in_deck <- .make_pair(active_id = "PRE-035", turn_number = 2L)
  in_hand <- .make_pair(active_id = "PRE-035", hand_id_vec = "PRE-037",
                        turn_number = 2L)

  expect_true("PRE-037" %in% in_deck$state$deck_vec)
  expect_false(can_rare_candy(in_deck$state, in_deck$state$active, "PRE-037"))
  expect_true(can_rare_candy(in_hand$state, in_hand$state$active, "PRE-037"))
})

test_that("Rare Candy walks the line rather than hard-coding one pair", {
  ## The intermediate stage is resolved from card_df: Dusknoir evolves from
  ## Dusclops, Dusclops from Duskull. A Stage 2 whose line does not reach this
  ## Basic must be refused, or Rare Candy becomes "any Stage 2 onto any Basic".
  bronzor_pair <- .make_pair(active_id = "TEF-068", hand_id_vec = "PRE-037",
                             turn_number = 2L)
  duskull_pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "TEF-069",
                             turn_number = 2L)

  expect_false(can_rare_candy(bronzor_pair$state, bronzor_pair$state$active,
                              "PRE-037"))
  ## And it is not a general evolution shortcut: Bronzong is a Stage 1.
  expect_false(can_rare_candy(duskull_pair$state, duskull_pair$state$active,
                              "TEF-069"))
})

test_that("Rare Candy obeys every evolution timing rule", {
  ## Its own text repeats two of them -- "not during your first turn or on a
  ## Basic put into play this turn" -- and the evolved-this-turn rule covers the
  ## third. Swept because each is a separate early return.
  grid_df <- expand.grid(turn_number = 1:2, turn_played = 0:2)

  for(i in seq_len(nrow(grid_df))){
    label_str <- paste0("turn ", grid_df$turn_number[i],
                        ", played T", grid_df$turn_played[i])
    pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "PRE-037",
                       turn_number = grid_df$turn_number[i])
    pair$state$active$turn_played <- as.integer(grid_df$turn_played[i])

    bool_expected <- grid_df$turn_number[i] > 1L &&
      grid_df$turn_played[i] != grid_df$turn_number[i]
    expect_equal(can_rare_candy(pair$state, pair$state$active, "PRE-037"),
                 bool_expected, info = label_str)
  }

  ## Already evolved this turn: refused even on turn 2 from a setup placement.
  pair <- .make_pair(active_id = "PRE-035", hand_id_vec = "PRE-037",
                     turn_number = 2L)
  pair$state$active$turn_evolved <- 2L
  expect_false(can_rare_candy(pair$state, pair$state$active, "PRE-037"))
})
