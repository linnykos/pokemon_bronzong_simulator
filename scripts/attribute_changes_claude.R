# What each change is worth, one change at a time.
#
# A single "the rate moved N points" is not useful: it cannot say which rule
# earned the movement, and it hides the changes that COST points and are kept
# anyway because they are rulings rather than optimisations. So each change is
# NEUTRALISED on its own, against the otherwise-current policy, and the cells
# are re-run.
#
# THE FAILURE THIS SCRIPT IS BUILT AGAINST. A neutralising patch that silently
# matches nothing reads as a change that costs nothing -- the first attribution
# run in this project reported ten of thirteen changes as worth 0.0 because the
# patches were multiline `perl` regexes written with \n against a CRLF source,
# so they matched nothing and `perl` still exited 0. So every patch here is an
# EXACT line-block substitution applied in R, which reads and writes line
# endings for us, and every substitution is asserted to have matched exactly
# once. A patch that matches nothing stops the script rather than producing a
# plausible number.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" \
#     scripts/attribute_changes_claude.R

rm(list = ls())

source_dir <- "R"
policy_path <- file.path(source_dir, "decision_claude.R")
num_replicates <- 1000L

# Which set of changes to price. "answers" is the S-15 to S-26 bank; "alignment"
# is the /align-decision-tree pass that followed it. Two sets rather than one
# list, because they answer different questions -- *what were Kevin's answers
# worth* and *what was the alignment worth* -- and a single table mixing them
# would let a reader add up numbers that do not belong together.
patch_set <- "alignment"
out_path <- file.path("results",
                      if(patch_set == "alignment"){
                        "alignment_attribution.md"
                      } else "change_attribution.md")

#' Every change worth attributing, and how to switch it off
#'
#' `old_str` is one or more CONSECUTIVE lines that must appear exactly once in
#' `R/decision_claude.R`; `new_str` is the same number of lines that neutralise
#' the rule. `decklist` names the list to measure it on, because a rule about a
#' card no decklist runs measures exactly zero on a list without it -- and a
#' zero that means "not exercised" looks identical to a zero that means "worth
#' nothing".
PATCH_LIST <- list(
  list(label = "S-18: a spare `[P]` goes to a second Bronzong",
       decklist = "decklist2",
       old_str = "  for(one_idx in .bench_idx_named(state, \"Bronzong\")){",
       new_str = "  for(one_idx in integer(0)){"),
  list(label = "S-19: Rare Candy once Bronzong is settled (§8)",
       decklist = "decklist2",
       old_str = "  if(state$turn_number != 2L) return(pair)",
       new_str = "  if(TRUE) return(pair)"),
  list(label = "S-20: Dusknoir on the want-list for the escape (PB-17)",
       decklist = "decklist2",
       old_str = "  if(status_vec[[\"c\"]]) return(FALSE)",
       new_str = "  if(TRUE) return(FALSE)"),
  list(label = "S-21: Ultra Ball protects every Bronzong, not the last copy",
       decklist = "decklist2",
       old_str = "  if(POLICY_ID_LIST$night_stretcher %in% state$hand_vec){",
       new_str = "  if(TRUE){"),
  list(label = "S-21: ...and every Bronzor, without a Salvatore in hand",
       decklist = "decklist2",
       old_str = "  if(POLICY_ID_LIST$salvatore %in% state$hand_vec){",
       new_str = "  if(TRUE){"),
  list(label = "S-22: every Poké Pad in hand is played",
       decklist = "decklist2",
       old_str =
         "  num_pad <- sum(pair$state$hand_vec == POLICY_ID_LIST$poke_pad)",
       new_str = paste0("  num_pad <- min(1L, sum(pair$state$hand_vec == ",
                        "POLICY_ID_LIST$poke_pad))")),
  list(label = "S-22: Enriching Energy takes an unclaimed attachment (PB-09)",
       decklist = "decklist2",
       old_str = "  pair <- .policy_enriching(pair)",
       new_str = "  pair <- pair"),
  list(label = "the kill line re-checks it still holds the Salvatore",
       decklist = "decklist2",
       old_str = "  if(!POLICY_ID_LIST$salvatore %in% pair$state$hand_vec ||",
       new_str = "  if(FALSE ||"),
  list(label = "S-24 / ADR 0008: the measured lead order, going second",
       decklist = "decklist2",
       old_str = c(
         "  going_second = c(\"Bronzor\", \"Latias ex\", \"Mega Kangaskhan ex\", \"Duskull\",",
         "                   \"Budew\", \"Flutter Mane\", \"Buneary\"))"),
       new_str = c(
         "  going_second = c(\"Bronzor\", \"Mega Kangaskhan ex\", \"Buneary\", \"Duskull\",",
         "                   \"Budew\", \"Flutter Mane\", \"Latias ex\"))")),
  # The two rules the new decklists brought with them. Measured on decklist7,
  # which is the only list that runs either card.
  list(label = "Gwynn is played at all (decklist7)",
       decklist = "decklist7",
       old_str = "  bool_gwynn <- POLICY_ID_LIST$gwynn %in% state$hand_vec &&",
       new_str = "  bool_gwynn <- FALSE &&"),
  list(label = "Risky Ruins is declined as disruptive to us (decklist7)",
       decklist = "decklist7",
       old_str = "                                        POLICY_ID_LIST$risky_ruins))",
       new_str = "                                        \"MEG-122\"))"))

#' The `/align-decision-tree` fixes, each switched off on its own
#'
#' Measured on **decklist7** unless stated. That is not a preference: seven of
#' the nine bite only on a list that runs two Bronzor printings, two Latias ex or
#' a basic Darkness Energy, and decklist7 is the only one that does. Measuring
#' them on decklist2 would report nine zeros and every one of them would mean
#' *not exercised* rather than *worth nothing*.
ALIGNMENT_PATCH_LIST <- list(
  list(label = "\"in play\" includes the Active spot, not just the Bench",
       decklist = "decklist7",
       old_str = "  .active_is(state, name_str) ||",
       new_str = "  FALSE ||"),
  list(label = "want-list item 4's second clause is about a **Bronzor** Active",
       decklist = "decklist7",
       old_str = "  if(!.active_is(state, c(\"Bronzor\", \"Bronzong\")) &&",
       new_str = "  if(!.subgoal_status(state)[[\"c\"]] &&"),
  list(label = "only one Latias ex is benched",
       decklist = "decklist7",
       old_str = c("     !.in_play_named(state, \"Latias ex\")){",
                   "    pair <- play_basic_to_bench(pair, POLICY_ID_LIST$latias)"),
       new_str = c("     TRUE){",
                   "    pair <- play_basic_to_bench(pair, POLICY_ID_LIST$latias)")),
  list(label = "the Telepathic goes to the `[P]` printing, not to Bench order",
       decklist = "decklist7",
       old_str = "    bench_idx_vec <- bench_idx_vec[order(!bool_psychic_vec)]",
       new_str = "    bench_idx_vec <- bench_idx_vec"),
  list(label = "one multi-target search never fetches two Bronzor printings",
       decklist = "decklist7",
       old_str =
         "    if(one_id %in% bronzor_vec && any(target_vec %in% bronzor_vec)) next",
       new_str = "    if(FALSE) next"),
  list(label = "Hilda's Energy search takes **any** Energy, Darkness included",
       decklist = "decklist7",
       old_str = c(
         "  energy_want_vec <- c(energy_want_vec,",
         "                       setdiff(state$card_df$card_id[",
         "                         state$card_df$category == \"energy\"], energy_want_vec))"),
       new_str = c("  energy_want_vec <- c(energy_want_vec,",
                   "                       character(0),",
                   "                       character(0))")),
  list(label = "one Duskull and one Rare Candy are protected from the discard",
       decklist = "decklist7",
       old_str =
         "  for(one_id in c(POLICY_ID_LIST$duskull, POLICY_ID_LIST$rare_candy)){",
       new_str = "  for(one_id in character(0)){"),
  list(label = "Meowth ex leaves the want-list once no Supporter can be played",
       decklist = "decklist7",
       old_str = paste0("  bool_supporter_wanted <- state$turn_number == 1L ",
                        "|| can_play_supporter(state)"),
       new_str = "  bool_supporter_wanted <- TRUE"),
  list(label = "\"a Bronzor is missing\" counts one in hand",
       decklist = "decklist7",
       old_str =
         "    length(intersect(state$hand_vec, .bronzor_ids(state$card_df))) == 0",
       new_str = "    TRUE"),
  list(label = "the Stadium and the leftover Rare Candy precede the fallback",
       decklist = "decklist7",
       old_str = c("  pair <- .policy_stadium(pair)",
                   "  pair <- .policy_leftover_rare_candy(pair)", ""),
       new_str = c("  pair <- pair", "  pair <- pair", "")),
  # decklist2 is measured for the two that are not printing-specific, so the
  # flat result on that list is attributed rather than merely observed.
  list(label = "\"in play\" includes the Active spot (decklist2)",
       decklist = "decklist2",
       old_str = "  .active_is(state, name_str) ||",
       new_str = "  FALSE ||"),
  list(label = "the Stadium and the Rare Candy precede the fallback (decklist2)",
       decklist = "decklist2",
       old_str = c("  pair <- .policy_stadium(pair)",
                   "  pair <- .policy_leftover_rare_candy(pair)", ""),
       new_str = c("  pair <- pair", "  pair <- pair", "")))

if(patch_set == "alignment") PATCH_LIST <- ALIGNMENT_PATCH_LIST

# ---------------------------------------------------------------------------
# Running one policy, patched or not
# ---------------------------------------------------------------------------

#' Apply one exact line-block patch and return the patched lines
#'
#' Stops if the block matched anything other than exactly once. Both zero and
#' many are silent-wrong-answer conditions rather than errors otherwise: the run
#' completes and reports a delta of 0.0 for a change that was never switched
#' off.
#' @noRd
.patched_lines <- function(line_vec, old_str, new_str){
  stopifnot(length(old_str) == length(new_str))
  num_line <- length(old_str)

  start_vec <- which(line_vec == old_str[1])
  hit_vec <- start_vec[sapply(start_vec, function(one_idx){
    idx_vec <- one_idx + seq_len(num_line) - 1L
    max(idx_vec) <= length(line_vec) &&
      identical(line_vec[idx_vec], old_str)
  })]
  if(length(hit_vec) != 1){
    stop("patch matched ", length(hit_vec), " blocks, expected exactly 1: `",
         old_str[1], "`")
  }

  line_vec[hit_vec + seq_len(num_line) - 1L] <- new_str
  line_vec
}

#' The three reported cells under one version of the policy
#'
#' Sources the whole simulator into a fresh environment, then sources the policy
#' file -- patched or not -- OVER it, so the patched definitions win. Every cell
#' uses seeds 1..`num_replicates`, so a difference between two rows is the
#' patch and nothing else.
#'
#' @param policy_lines the lines of the policy file to use.
#' @param decklist_name which list to measure on.
#'
#' @returns A named numeric vector of hit rates.
#' @noRd
.rates_of <- function(policy_lines, decklist_name){
  env <- new.env(parent = globalenv())
  for(one_file in list.files(source_dir, pattern = "[.]R$",
                             full.names = TRUE)){
    sys.source(one_file, envir = env)
  }
  tmp_path <- file.path(tempdir(), "patched_policy.R")
  writeLines(policy_lines, tmp_path)
  sys.source(tmp_path, envir = env)

  card_df <- env$build_card_database()
  decklist <- env$read_decklist(file.path("decklists",
                                          paste0(decklist_name, ".txt")),
                                card_df)

  .one_cell <- function(bool_going_first, scenario){
    hit_vec <- sapply(seq_len(num_replicates), function(i){
      one_pair <- env$play_replicate(decklist, card_df,
                                     bool_going_first = bool_going_first,
                                     scenario = scenario,
                                     seed_number = i)
      env$summarise_replicate(one_pair, decklist$decklist_id, i)$bool_hit
    })
    mean(hit_vec)
  }

  c(second = .one_cell(FALSE, "clear"),
    first = .one_cell(TRUE, "clear"),
    lock = .one_cell(TRUE, "item_lock"))
}

# ---------------------------------------------------------------------------
# The sweep
# ---------------------------------------------------------------------------

base_lines <- readLines(policy_path)
name_vec <- unique(sapply(PATCH_LIST, function(x) x$decklist))
base_list <- list()
for(one_name in name_vec){
  print(paste0("current policy, ", one_name))
  base_list[[one_name]] <- .rates_of(base_lines, one_name)
  print(base_list[[one_name]])
}

delta_list <- list()
for(one_patch in PATCH_LIST){
  print(one_patch$label)
  patched_lines <- .patched_lines(base_lines, one_patch$old_str,
                                  one_patch$new_str)
  off_vec <- .rates_of(patched_lines, one_patch$decklist)
  base_vec <- base_list[[one_patch$decklist]]

  delta_list[[length(delta_list) + 1]] <- data.frame(
    label = one_patch$label,
    decklist = one_patch$decklist,
    second = 100 * (base_vec[["second"]] - off_vec[["second"]]),
    first = 100 * (base_vec[["first"]] - off_vec[["first"]]),
    lock = 100 * (base_vec[["lock"]] - off_vec[["lock"]]),
    stringsAsFactors = FALSE)
  print(delta_list[[length(delta_list)]])
}

delta_df <- do.call(rbind, delta_list)
delta_df <- delta_df[order(delta_df$decklist, -delta_df$second), ]

# ---------------------------------------------------------------------------
# Write it down
# ---------------------------------------------------------------------------

.pts <- function(x) format(round(x, 1), nsmall = 1)

line_vec <- c(
  if(patch_set == "alignment"){
    "# What each `/align-decision-tree` fix is worth"
  } else "# What each change from the S-15 to S-26 answers is worth",
  "",
  paste0("Written by `scripts/attribute_changes_claude.R` on ",
         format(Sys.Date()), ". **", num_replicates,
         " replicates per cell**, seeds 1-", num_replicates,
         " in every cell."),
  "",
  paste0("Each row is that change **neutralised on its own**, against the ",
         "otherwise-current policy, so the rows do not add up to the total ",
         "movement and are not meant to. A negative number is a change that ",
         "COSTS points and is kept anyway, because it is a ruling rather than ",
         "an optimisation and the documents are the specification."),
  "",
  paste0("Every patch is an exact line-block substitution asserted to have ",
         "matched exactly once, so a patch that matches nothing stops the ",
         "script rather than reporting 0.0. **A row is measured on the list ",
         "that runs the card**, since a rule about Gwynn measures exactly zero ",
         "on a list with no Gwynn -- and a zero meaning *not exercised* looks ",
         "identical to a zero meaning *worth nothing*."),
  "",
  paste0("**Read the noise floor before reading the rows.** At ",
         num_replicates, " paired replicates the standard error on one of ",
         "these differences is roughly **0.2 to 0.4 points**, so a row under ",
         "about 0.6 is not distinguishable from zero and should be read as ",
         "*this change did not move the metric* rather than as a measured ",
         "small gain."),
  "",
  if(patch_set == "alignment"){
    paste0("**Most of these rows are supposed to be zero.** They are ",
           "**correctness** fixes found by auditing the code against the ",
           "documents, not optimisations: a rule that stops the policy making ",
           "a play the documents forbid has done its job whether or not the ",
           "rate moves, and several of them govern the board the window closes ",
           "on rather than whether the attack happens. Read a 0.0 here as ",
           "*the code now does what the document says, at no cost*.")
  } else {
    paste0("Several rows below are honestly zero, and two of them are supposed ",
           "to be: S-18 and S-19 change the **board the window closes on**, ",
           "not whether the attack happens, so a 0.0 there is the answer ",
           "rather than a disappointment.")
  },
  "")
for(one_name in name_vec){
  base_vec <- base_list[[one_name]]
  line_vec <- c(
    line_vec,
    paste0("## ", one_name),
    "",
    paste0("Current policy: **", .pts(100 * base_vec[["second"]]),
           "%** going second, **", .pts(100 * base_vec[["first"]]),
           "%** going first, **", .pts(100 * base_vec[["lock"]]),
           "%** going first under `item_lock`."),
    "",
    "| change | going second | going first | `item_lock` first |",
    "|---|---|---|---|")
  sub_df <- delta_df[delta_df$decklist == one_name, ]
  for(i in seq_len(nrow(sub_df))){
    line_vec <- c(line_vec,
                  paste0("| ", sub_df$label[i], " | ", .pts(sub_df$second[i]),
                         " | ", .pts(sub_df$first[i]), " | ",
                         .pts(sub_df$lock[i]), " |"))
  }
  line_vec <- c(line_vec, "")
}

writeLines(line_vec, out_path)
print(paste0("wrote ", out_path))
