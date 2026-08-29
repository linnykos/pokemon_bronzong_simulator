context("Test the card database")

## The card table is pure data projected from docs/cards/. An error here is
## silent: it corrupts every downstream result without ever raising. So these
## tests assert the specific values that the rules read, not just that the table
## parses.

test_that("the database is internally consistent", {
  card_df <- build_card_database()

  expect_false(anyDuplicated(card_df$card_id) > 0)
  expect_true(all(card_df$category %in% c("pokemon", "trainer", "energy")))
  expect_true(all(card_df$energy_provided %in% c("P", "C", "")))

  ## Only Pokemon rows may carry a stage, and every Pokemon row must.
  is_pokemon_vec <- card_df$category == "pokemon"
  expect_true(all(!is.na(card_df$stage[is_pokemon_vec])))
  expect_true(all(is.na(card_df$stage[!is_pokemon_vec])))
})

test_that("every card in every decklist is in the database", {
  ## Guards the failure mode where a decklist cites a printing nobody
  ## transcribed: read_decklist() would otherwise build a short deck.
  card_df <- build_card_database()
  file_vec <- list.files("decklists", pattern = "[.]txt$", full.names = TRUE)
  expect_true(length(file_vec) > 0)

  for(one_file in file_vec){
    expect_silent(read_decklist(one_file, card_df), info = one_file)
  }
})

test_that("Enriching Energy is not a Psychic source but the others are", {
  ## The single most consequential predicate in the project. Enriching Energy
  ## provides [C] and cannot pay Evolution Jammer; treating all Energy as [P]
  ## would silently overstate every decklist's consistency.
  card_df <- build_card_database()

  expect_true(is_psychic_source(card_df, "SVE-005"), info = "basic Psychic")
  expect_true(is_psychic_source(card_df, "MEE-005"), info = "basic Psychic alt")
  expect_true(is_psychic_source(card_df, "POR-088"), info = "Telepathic")
  expect_false(is_psychic_source(card_df, "SSP-191"), info = "Enriching is [C]")
})

test_that("has_ability matches the card text, because Salvatore reads it", {
  ## Salvatore may only fetch a card with NO Abilities. Bronzong has none
  ## (Evolution Jammer is an attack), so it is legal; Dusclops and Dusknoir both
  ## have Cursed Blast, so they never are. Getting either wrong changes what the
  ## turn-1 line can do.
  card_df <- build_card_database()

  expect_false(lookup_card(card_df, "TEF-069")$has_ability, info = "Bronzong")
  expect_true(lookup_card(card_df, "PRE-036")$has_ability, info = "Dusclops")
  expect_true(lookup_card(card_df, "PRE-037")$has_ability, info = "Dusknoir")
  expect_false(lookup_card(card_df, "PFL-084")$has_ability,
               info = "Mega Lopunny ex")
  expect_true(lookup_card(card_df, "SSP-076")$has_ability, info = "Latias ex")
})

test_that("the three Bronzor printings differ exactly as documented", {
  ## docs/02_cards.md: TEF 68 is Psychic/80 (Telepathic-findable, not
  ## Poffin-findable); PRE 66 is Metal/70 and SSP 126 Metal/60 (the reverse).
  ## All three are named "Bronzor" so all three evolve into Bronzong TEF 69.
  card_df <- build_card_database()
  bronzor_df <- lookup_card(card_df, c("TEF-068", "PRE-066", "SSP-126"))

  expect_equal(bronzor_df$name, rep("Bronzor", 3))
  expect_equal(bronzor_df$hp, c(80L, 70L, 60L))
  expect_equal(bronzor_df$ptype, c("psychic", "metal", "metal"))
  expect_equal(bronzor_df$retreat, c(3L, 1L, 1L))

  ## The Poffin cap is "70 HP or less", so 70 passes and 80 fails. The boundary
  ## is the entire argument for the alternate printings.
  expect_true(bronzor_df$hp[2] <= 70)
  expect_false(bronzor_df$hp[1] <= 70)
})

test_that("Mega Kangaskhan ex is a Basic and Mega Lopunny ex is a Stage 1", {
  ## Kangaskhan being Basic is why no decklist runs a Kangaskhan; Lopunny being
  ## Stage 1 is why Rare Candy cannot reach it.
  card_df <- build_card_database()

  expect_equal(lookup_card(card_df, "MEG-104")$stage, "basic")
  expect_equal(lookup_card(card_df, "PFL-084")$stage, "stage1")
  expect_equal(lookup_card(card_df, "PFL-084")$evolves_from, "Buneary")
})

test_that("rule boxes are marked, because Poke Pad reads them", {
  card_df <- build_card_database()

  expect_true(all(lookup_card(card_df,
                              c("SSP-076", "POR-062", "PFL-084",
                                "MEG-104"))$has_rule_box))
  expect_false(any(lookup_card(card_df,
                               c("TEF-068", "TEF-069", "PRE-035",
                                 "PFL-083"))$has_rule_box))
})

test_that("canonical_card_id folds MEE-005 onto SVE-005 and leaves others", {
  expect_equal(canonical_card_id("MEE-005"), "SVE-005")
  expect_equal(canonical_card_id("SVE-005"), "SVE-005")
  expect_equal(canonical_card_id(c("MEE-005", "TEF-069", "MEE-005")),
               c("SVE-005", "TEF-069", "SVE-005"))

  ## Empty input must round-trip rather than erroring or returning NULL: this
  ## is called on possibly-empty search target vectors.
  expect_length(canonical_card_id(character(0)), 0)
})

test_that("lookup_card errors loudly on an unknown id", {
  ## Returning an NA row instead would propagate into every rule as a false
  ## negative -- e.g. can_evolve() would quietly return FALSE forever.
  card_df <- build_card_database()

  expect_error(lookup_card(card_df, "ZZZ-999"), regexp = "unknown card id")
})

test_that("lookup_card preserves the order and length of its input", {
  card_df <- build_card_database()
  query_vec <- c("TEF-069", "SVE-005", "TEF-069", "PRE-035")
  row_df <- lookup_card(card_df, query_vec)

  expect_equal(nrow(row_df), length(query_vec))
  expect_equal(row_df$card_id, query_vec)
})

test_that("is_basic_pokemon is FALSE for Trainers and Energy", {
  ## A Trainer must never be placeable during setup. This is the predicate that
  ## stops it.
  card_df <- build_card_database()

  expect_true(is_basic_pokemon(card_df, "TEF-068"))
  expect_false(is_basic_pokemon(card_df, "TEF-069"), info = "Stage 1")
  expect_false(is_basic_pokemon(card_df, "MEG-130"), info = "Switch is an Item")
  expect_false(is_basic_pokemon(card_df, "SVE-005"), info = "Energy")
})
