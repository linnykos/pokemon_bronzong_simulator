context("Test decklist parsing and validation")

.write_temp_decklist <- function(line_vec){
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(line_vec, tmp_file)
  tmp_file
}

.minimal_lines <- function(){
  ## A legal 60 built from few entries, so a test can perturb one line without
  ## rewriting a whole decklist.
  c("Pokemon: 3",
    "4 Bronzor TEF 68",
    "4 Bronzong TEF 69",
    "4 Duskull PRE 35",
    "Trainer: 1",
    "4 Switch MEG 130",
    "Energy: 1",
    "44 Basic {P} Energy SVE 5")
}

test_that("every real decklist parses to exactly 60 legal cards", {
  card_df <- build_card_database()
  file_vec <- list.files("decklists", pattern = "[.]txt$", full.names = TRUE)

  for(one_file in file_vec){
    decklist <- read_decklist(one_file, card_df)
    expect_equal(length(decklist$card_id_vec), 60, info = basename(one_file))
    expect_length(validate_decklist(decklist, card_df), 0)
  }
})

test_that("the section headers are ignored, because they count lines not cards", {
  ## The supplied files head their sections with the number of distinct LINES,
  ## not the number of cards -- "Pokemon: 12" above 24 cards. Trusting the
  ## header would give wrong totals, so the parser must derive the count by
  ## summing entries.
  card_df <- build_card_database()
  tmp_file <- .write_temp_decklist(c("Pokemon: 999",
                                     "4 Bronzor TEF 68",
                                     "Energy: -5",
                                     "4 Basic {P} Energy SVE 5"))
  decklist <- read_decklist(tmp_file, card_df)

  expect_equal(length(decklist$card_id_vec), 8)
})

test_that("a decklist is identified by contents, not by line order", {
  ## CONTEXT.md defines a Decklist by its multiset. Two files whose cards agree
  ## must share a decklist_id however their lines are ordered -- this is what
  ## the duplicate removal relies on.
  card_df <- build_card_database()
  line_vec <- .minimal_lines()
  shuffled_vec <- c(line_vec[1], line_vec[3], line_vec[2], line_vec[4:8])

  id_one <- read_decklist(.write_temp_decklist(line_vec), card_df)$decklist_id
  id_two <- read_decklist(.write_temp_decklist(shuffled_vec), card_df)$decklist_id

  expect_equal(id_one, id_two)
})

test_that("different decklists get different ids", {
  ## Bug pinned: the content hash originally used a 32-bit FNV-1a, but R's
  ## bitwXor coerces to integer, so an accumulator above .Machine$integer.max
  ## silently became NA. Every decklist hashed to "dl_NA" and the duplicate
  ## detection then dropped five of six real lists as identical. A hash that
  ## returns NA passes any test that only checks "equal lists hash equal", so
  ## this test asserts distinctness AND non-NA explicitly.
  card_df <- build_card_database()
  file_vec <- list.files("decklists", pattern = "[.]txt$", full.names = TRUE)
  id_vec <- sapply(file_vec, function(one_file){
    read_decklist(one_file, card_df)$decklist_id
  })

  expect_false(any(is.na(id_vec)))
  expect_false(any(grepl("NA", id_vec, fixed = TRUE)))
  expect_equal(length(unique(id_vec)), length(id_vec))
})

test_that("the six shipped decklists are all distinct", {
  ## Two duplicates (old decklist7, decklist8) were removed. If a future edit
  ## reintroduces one, this catches it.
  card_df <- build_card_database()
  decklist_list <- read_decklist_dir("decklists", card_df,
                                     bool_drop_duplicates = FALSE)
  id_vec <- sapply(decklist_list, function(x) x$decklist_id)

  expect_equal(length(unique(id_vec)), length(id_vec))
})

test_that("read_decklist_dir drops duplicates only when asked", {
  card_df <- build_card_database()
  tmp_dir <- file.path(tempdir(), "dupdecks")
  dir.create(tmp_dir, showWarnings = FALSE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  writeLines(.minimal_lines(), file.path(tmp_dir, "a.txt"))
  writeLines(rev(.minimal_lines()), file.path(tmp_dir, "b.txt"))

  expect_equal(length(read_decklist_dir(tmp_dir, card_df,
                                        bool_drop_duplicates = FALSE)), 2)
  expect_equal(length(read_decklist_dir(tmp_dir, card_df,
                                        bool_drop_duplicates = TRUE)), 1)
})

test_that("validate_decklist catches each construction violation", {
  card_df <- build_card_database()

  ## Wrong total.
  short_file <- .write_temp_decklist(c("4 Bronzor TEF 68",
                                       "4 Basic {P} Energy SVE 5"))
  short_list <- read_decklist(short_file, card_df)
  expect_error(validate_decklist(short_list, card_df), regexp = "not 60")
  expect_true(any(grepl("8 cards",
                        validate_decklist(short_list, card_df,
                                          bool_stop_on_error = FALSE))))

  ## Over four copies of a non-basic-Energy card.
  over_file <- .write_temp_decklist(c("5 Switch MEG 130",
                                      "55 Basic {P} Energy SVE 5"))
  over_list <- read_decklist(over_file, card_df)
  expect_true(any(grepl("more than 4",
                        validate_decklist(over_list, card_df,
                                          bool_stop_on_error = FALSE))))

  ## No Basic Pokemon at all.
  nobasic_file <- .write_temp_decklist(c("4 Switch MEG 130",
                                         "56 Basic {P} Energy SVE 5"))
  nobasic_list <- read_decklist(nobasic_file, card_df)
  expect_true(any(grepl("no Basic Pokemon",
                        validate_decklist(nobasic_list, card_df,
                                          bool_stop_on_error = FALSE))))
})

test_that("basic Energy is exempt from the 4-copy limit but Special is not", {
  ## Rules section 2. Telepathic Psychic Energy and Enriching Energy are Special
  ## Energy and are capped at 4; basic Psychic is uncapped.
  card_df <- build_card_database()

  legal_file <- .write_temp_decklist(c("4 Bronzor TEF 68",
                                       "56 Basic {P} Energy SVE 5"))
  legal_list <- read_decklist(legal_file, card_df)
  expect_length(validate_decklist(legal_list, card_df), 0)

  illegal_file <- .write_temp_decklist(c("4 Bronzor TEF 68",
                                         "5 Telepathic Psychic Energy POR 88",
                                         "51 Basic {P} Energy SVE 5"))
  illegal_list <- read_decklist(illegal_file, card_df)
  expect_true(any(grepl("more than 4",
                        validate_decklist(illegal_list, card_df,
                                          bool_stop_on_error = FALSE))))
})

test_that("the two basic Psychic printings are folded into one entry", {
  ## SVE 5 and MEE 5 are the same card, so a deck running both must count them
  ## together for the copy limit and for every search.
  card_df <- build_card_database()
  tmp_file <- .write_temp_decklist(c("4 Bronzor TEF 68",
                                     "2 Basic {P} Energy SVE 5",
                                     "2 Psychic Energy MEE 5"))
  decklist <- read_decklist(tmp_file, card_df)

  expect_equal(as.integer(decklist$count_vec[["SVE-005"]]), 4)
  expect_false("MEE-005" %in% names(decklist$count_vec))
})

test_that("carriage returns and blank lines do not corrupt card ids", {
  ## The supplied files were authored on Windows. A trailing CR would end up
  ## inside the card number and produce an unknown id.
  card_df <- build_card_database()
  tmp_file <- tempfile(fileext = ".txt")
  writeLines(c("Pokemon: 1\r", "4 Bronzor TEF 68\r", "", "   ",
               "4 Basic {P} Energy SVE 5\r"), tmp_file)
  decklist <- read_decklist(tmp_file, card_df)

  expect_equal(length(decklist$card_id_vec), 8)
  expect_true(all(decklist$card_id_vec %in% c("TEF-068", "SVE-005")))
})

test_that("a decklist citing an unknown printing fails loudly", {
  card_df <- build_card_database()
  tmp_file <- .write_temp_decklist(c("4 Nonsense ZZZ 99"))

  expect_error(read_decklist(tmp_file, card_df), regexp = "unknown card id")
})

test_that("a file with only headers and blanks is an error, not an empty deck", {
  card_df <- build_card_database()
  tmp_file <- .write_temp_decklist(c("Pokemon: 24", "", "Trainer: 31"))

  expect_error(read_decklist(tmp_file, card_df), regexp = "no card lines")
})

test_that("an unparsable line is an error, not a silently shorter deck", {
  ## Found by the coverage audit and the highest-risk parsing defect: lines that
  ## failed the pattern were dropped in SILENCE, so a lowercase set code, a "4x"
  ## count prefix, a missing space, or a PTCG-Live variant tag each produced a
  ## legal-looking 56-card deck. Every rate computed on it would be against the
  ## wrong denominator, and nothing would have complained.
  card_df <- build_card_database()

  bad_line_list <- list("lowercase set" = "4 Bronzor tef 68",
                        "x-prefixed count" = "4x Bronzor TEF 68",
                        "missing space" = "4 Bronzor TEF68",
                        "variant tag" = "4 Bronzor TEF 68 PH",
                        "prose" = "some prose")

  for(one_name in names(bad_line_list)){
    tmp_file <- .write_temp_decklist(c("Pokemon: 1",
                                       bad_line_list[[one_name]],
                                       "4 Basic {P} Energy SVE 5"))
    expect_error(read_decklist(tmp_file, card_df),
                 regexp = "could not parse", info = one_name)
  }
})

test_that("headers and blank lines are still ignored, not treated as errors", {
  ## The stricter parser must not reject the real files' own headers.
  card_df <- build_card_database()
  file_vec <- list.files("decklists", pattern = "[.]txt$", full.names = TRUE)

  for(one_file in file_vec){
    expect_silent(read_decklist(one_file, card_df))
  }
})
