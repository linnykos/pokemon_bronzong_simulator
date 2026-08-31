# Score every decklist in decklists/ across every cell (part 6, first piece).
#
# The registry answers the project's actual question: WHICH DECKLIST IS BETTER.
# One rate per cell, never pooled across cells (ADR 0002), with the two mulligan
# metrics reported beside the rate and never folded into it (ADR 0005).
#
# THE CELLS. Six decklists crossed with the coin flip and the scenario, minus
# the one combination the game cannot produce: `item_lock` models the opponent
# leading Budew and attacking with Itchy Pollen, and Itchy Pollen is an ATTACK,
# so it is only available to a player who went second. There is therefore no
# going-second `item_lock` cell -- 6 x 3 = 18 rather than 6 x 4 = 24
# (CLAUDE.md -> Scenarios).
#
# COMMON RANDOM NUMBERS. Every cell uses seeds 1..num_replicates, so a
# difference between two decklists in the same cell is a difference in the
# sixty cards rather than in the shuffles. Seeds are NOT comparable across
# cells, because the deck differs and so the same seed deals a different game.
#
# The traces are a separate output answering a separate question (ADR 0006) and
# are deliberately over-weighted toward misses. NEVER compute a rate from one.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" \
#     scripts/score_decklists_claude.R

rm(list = ls())

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

num_replicates <- 1000L
max_miss <- 12L
max_hit <- 3L
results_dir <- "results"
csv_path <- file.path(results_dir, "decklist_registry.csv")
md_path <- file.path(results_dir, "registry.md")

card_df <- build_card_database()
path_vec <- sort(list.files("decklists", pattern = "[.]txt$",
                            full.names = TRUE))
name_vec <- sub("[.]txt$", "", basename(path_vec))
decklist_list <- stats::setNames(lapply(path_vec, function(one_path){
  read_decklist(one_path, card_df)
}), name_vec)

# One row per cell. `item_lock` is absent going second on purpose; see the
# header. Ordered so the reading table groups by scenario then by coin flip.
cell_df <- data.frame(
  scenario = c("clear", "clear", "item_lock"),
  bool_going_first = c(FALSE, TRUE, TRUE),
  label = c("second / clear", "first / clear", "first / item_lock"),
  stringsAsFactors = FALSE)

#' Run one whole cell and keep a stratified trace sample alongside
#'
#' The sample is drawn in the SAME pass as the rates rather than by replaying
#' selected seeds afterwards, which halves the work and removes the chance of
#' the two passes disagreeing.
#'
#' @param decklist a `"bronzong_decklist"`.
#' @param bool_going_first the coin flip.
#' @param scenario the opponent model.
#'
#' @returns A list with `summary` (a `"bronzong_summary"` over EVERY replicate,
#'   which is what \code{write_trace_file()} requires) and `trace_list` (the
#'   ADR 0006 sample).
#' @noRd
.run_cell <- function(decklist, bool_going_first, scenario){
  sampler <- new_trace_sampler(max_miss = max_miss, max_hit = max_hit)
  result_list <- vector("list", num_replicates)
  trace_list <- list()

  for(i in seq_len(num_replicates)){
    one_pair <- play_replicate(decklist, card_df,
                               bool_going_first = bool_going_first,
                               scenario = scenario,
                               seed_number = i)
    # Asked BEFORE the trace is formatted, because the sampler's quota is what
    # decides whether formatting is worth doing at all.
    bool_hit <- !is.na(one_pair$state$jammer_turn) &&
      one_pair$state$jammer_turn <= 2L
    take_list <- sampler_take(sampler, bool_hit)
    sampler <- take_list$sampler

    result_list[[i]] <- summarise_replicate(one_pair, decklist$decklist_id, i,
                                            bool_keep_trace =
                                              take_list$bool_keep)
    if(take_list$bool_keep){
      trace_list[[length(trace_list) + 1]] <- result_list[[i]]
    }
  }

  list(summary = summarise_run(result_list), trace_list = trace_list)
}

# ---------------------------------------------------------------------------
# Every cell
# ---------------------------------------------------------------------------

row_list <- list()
for(one_name in name_vec){
  for(j in seq_len(nrow(cell_df))){
    print(paste0(one_name, "  ", cell_df$label[j]))
    cell_list <- .run_cell(decklist_list[[one_name]],
                           bool_going_first = cell_df$bool_going_first[j],
                           scenario = cell_df$scenario[j])
    one_summary <- cell_list$summary

    row_list[[length(row_list) + 1]] <- data.frame(
      decklist = one_name,
      decklist_id = one_summary$decklist_id,
      scenario = cell_df$scenario[j],
      bool_going_first = cell_df$bool_going_first[j],
      num_replicates = one_summary$num_replicates,
      hit_rate = one_summary$hit_rate,
      turn1_rate = one_summary$turn1_rate,
      num_turn1 = as.integer(one_summary$turn_tally_vec[["t1"]]),
      num_turn2 = as.integer(one_summary$turn_tally_vec[["t2"]]),
      num_never = as.integer(one_summary$turn_tally_vec[["never"]]),
      mulligan_rate = one_summary$mulligan_rate,
      mean_mulligans = one_summary$mean_mulligans,
      unmet_a = as.integer(one_summary$unmet_tally_vec[["A"]]),
      unmet_b = as.integer(one_summary$unmet_tally_vec[["B"]]),
      unmet_c = as.integer(one_summary$unmet_tally_vec[["C"]]),
      unmet_d = as.integer(one_summary$unmet_tally_vec[["D"]]),
      num_unused_out = one_summary$num_unused_out,
      stringsAsFactors = FALSE)

    # One trace file per decklist, from the cell the project reads first.
    if(!cell_df$bool_going_first[j] && cell_df$scenario[j] == "clear"){
      write_trace_file(cell_list$trace_list,
                       file.path(results_dir, paste0(one_name, "_traces.txt")),
                       one_summary, decklist = decklist_list[[one_name]])
    }
  }
}

registry_df <- do.call(rbind, row_list)
utils::write.csv(registry_df, csv_path, row.names = FALSE)
print(paste0("wrote ", csv_path))

# ---------------------------------------------------------------------------
# The reading copy
# ---------------------------------------------------------------------------

.pct <- function(x) paste0(format(round(100 * x, 1), nsmall = 1), "%")

#' One markdown table per cell, decklists ranked within it
#'
#' Ranked WITHIN a cell and never across cells: ADR 0002 forbids pooling, and a
#' single ranked list over all 18 rows is the shape that invites it.
#' @noRd
.cell_block <- function(registry_df, scenario_str, bool_going_first, title_str){
  sub_df <- registry_df[registry_df$scenario == scenario_str &
                          registry_df$bool_going_first == bool_going_first, ]
  sub_df <- sub_df[order(-sub_df$hit_rate), ]

  line_vec <- c(paste0("### ", title_str), "",
                paste0("| decklist | hit rate | on turn 1 | mulligan rate | ",
                       "unmet A / B / C / D |"),
                "|---|---|---|---|---|")
  for(i in seq_len(nrow(sub_df))){
    line_vec <- c(line_vec,
                  paste0("| ", sub_df$decklist[i], " | **",
                         .pct(sub_df$hit_rate[i]), "** | ",
                         sub_df$num_turn1[i], " | ",
                         .pct(sub_df$mulligan_rate[i]), " | ",
                         sub_df$unmet_a[i], " / ", sub_df$unmet_b[i], " / ",
                         sub_df$unmet_c[i], " / ", sub_df$unmet_d[i], " |"))
  }

  c(line_vec, "")
}

line_vec <- c(
  "# The decklist registry",
  "",
  paste0("Written by `scripts/score_decklists_claude.R` on ",
         format(Sys.Date()), ". **", num_replicates,
         " replicates per cell**, seeds 1-", num_replicates,
         " in every cell, so a difference between two decklists in the same ",
         "row is a difference in the sixty cards rather than in the shuffles."),
  "",
  paste0("**The primary outcome is one fixed bar: Evolution Jammer on or ",
         "before the player's own turn 2** (ADR 0004), identical going first ",
         "and going second. Going first and going second are separate numbers ",
         "and are never pooled (ADR 0002), which is why there are three tables ",
         "below and not one."),
  "",
  paste0("**Mulligans are never a miss** (ADR 0005); the mulligan rate is ",
         "beside the hit rate, not inside it. The **on turn 1** column is the ",
         "only place Salvatore's speed appears, because the primary outcome ",
         "deliberately prices a turn-1 kill and a turn-2 conventional line the ",
         "same."),
  "",
  paste0("There is no going-second `item_lock` cell: Itchy Pollen is an attack ",
         "and only a player who went second can use it, so the lock can only ",
         "ever land on us when **we** went first."),
  "",
  "The unmet counts are over the SET of open sub-goals, so a miss appears in",
  "every column it belongs to and the columns sum to more than the miss count.",
  "",
  paste0("**Read the noise floor before ranking anything.** At ", num_replicates,
         " replicates the standard error on a single rate near 75% is about ",
         "**1.4 points**, and on the difference between two decklists about ",
         "**2.0** — the seeds are shared but the decks are not, so the shuffles ",
         "are effectively independent and the pairing buys little. **A gap ",
         "under about 4 points is not resolved by this run.** The tables below ",
         "are ordered by rate because they have to be ordered by something; ",
         "the order inside a 4-point band is noise, and separating that band is ",
         "exactly what raising the replicate count is for."),
  "",
  paste0("`results/registry_notes.md` is the hand-written reading of these ",
         "tables. It is not regenerated by this script and will not be ",
         "overwritten by it."),
  "",
  .cell_block(registry_df, "clear", FALSE, "Going second, `clear`"),
  .cell_block(registry_df, "clear", TRUE, "Going first, `clear`"),
  .cell_block(registry_df, "item_lock", TRUE, "Going first, `item_lock`"),
  "## The decklists",
  "",
  "| decklist | Salvatore | `[P]` base | Bronzor | Switch | Ciphermaniac's |",
  "|---|---|---|---|---|---|")
for(one_name in name_vec){
  count_vec <- decklist_list[[one_name]]$count_vec
  .count_of <- function(card_id){
    if(card_id %in% names(count_vec)) as.integer(count_vec[[card_id]]) else 0L
  }
  energy_str <- paste0(.count_of("POR-088"), " Telepathic",
                       if(.count_of("SVE-005") > 0){
                         paste0(" + ", .count_of("SVE-005"), " basic")
                       } else "")
  line_vec <- c(line_vec,
                paste0("| ", one_name, " | ", .count_of("TEF-160"), " | ",
                       energy_str, " | ", .count_of("TEF-068"), " | ",
                       .count_of("MEG-130"), " | ", .count_of("TEF-145"),
                       " |"))
}
line_vec <- c(
  line_vec, "",
  paste0("Full counts are in `decklists/`; `docs/02_cards.md` carries the ",
         "cross-decklist matrix."),
  "",
  "## The traces",
  "",
  paste0("One file per decklist, `results/<decklist>_traces.txt`, from the ",
         "going-second `clear` cell. **Never compute a rate from one** ",
         "(ADR 0006): the sample is roughly ", max_miss, ":", max_hit,
         " misses to hits by construction, because a hit teaches nothing about ",
         "what to change. Each file leads with the true rates for that reason."),
  "")

writeLines(line_vec, md_path)
print(paste0("wrote ", md_path))
