# Settle the section 3 lead order from the logs (DT-03).
#
# docs/03_decision_tree.md section 3 ranks the no-Bronzor leads and says so as a
# DEFAULT: "it is to be optimized from the simulation logs". This script is the
# optimisation.
#
# WHY NOT `lead_hit_df`. The demo's per-lead table is confounded and cannot
# answer this. The hand that contains a Mega Kangaskhan ex is not the hand that
# contains a Duskull, so the table compares leads across different hands and
# reports a property of the hands as if it were a property of the order. The
# clean experiment varies the ORDER and measures the cell rate, which is what
# the policy actually controls.
#
# Two facts make it cheap. On decklist2, C(58,7)/C(60,7) = 78% of opening hands
# hold no Bronzor at all, so the order binds on most games and the signal is
# large. And a full permutation search over six names is 720 orders, while a
# GREEDY POSITIONAL search -- pick rank 1 from six, then rank 2 from the
# remaining five, and so on -- is 20 evaluations for the same answer whenever
# the ranking is transitive, which it is here because only the top-ranked Basic
# actually present in the hand is ever used.
#
# Common random numbers throughout: every candidate order is evaluated on the
# SAME seeds, so a difference between two orders is a difference in play rather
# than a difference in shuffles.
#
# The winner is then confirmed OUT OF SAMPLE against the incumbent on a
# disjoint seed block, because a greedy search that picks the maximum of twenty
# noisy numbers is exactly the procedure that reports a winner when there is
# none.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" \
#     scripts/tune_lead_order_claude.R

rm(list = ls())

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

card_df <- build_card_database()
decklist <- read_decklist(file.path("decklists", "decklist2.txt"), card_df)

num_search <- 2000L
num_confirm <- 5000L
confirm_offset <- 100000L
out_path <- file.path("results", "lead_order_tuning.md")

# Meowth ex is absent on purpose and is not a candidate: section 3 rules that
# leading it wastes Last-Ditch Catch outright, which is a ruling rather than a
# default and so is not this script's to overturn. Bronzor is pinned at rank 1
# for the same reason -- it satisfies sub-goal C outright and costs nothing.
CANDIDATE_VEC <- c("Mega Kangaskhan ex", "Buneary", "Duskull", "Budew",
                   "Flutter Mane", "Latias ex")

#' Hit rate for one lead order in one cell
#'
#' @param name_vec the no-Bronzor order, best first. Bronzor is prepended here
#'   rather than by the caller, so a candidate vector can never accidentally
#'   demote it.
#' @param bool_going_first the coin flip.
#' @param num_replicates how many replicates.
#' @param scenario the opponent model.
#' @param seed_offset added to every seed, so the search block and the
#'   confirmation block are disjoint.
#'
#' @returns A single hit rate.
#' @noRd
.rate_of <- function(name_vec,
                     bool_going_first,
                     num_replicates,
                     scenario = "clear",
                     seed_offset = 0L){
  order_vec <- c("Bronzor", name_vec)
  lead_order_list <- list(going_first = order_vec, going_second = order_vec)

  hit_vec <- sapply(seq_len(num_replicates), function(i){
    one_pair <- play_replicate(decklist, card_df,
                               bool_going_first = bool_going_first,
                               lead_order_list = lead_order_list,
                               scenario = scenario,
                               seed_number = i + seed_offset)
    result <- summarise_replicate(one_pair, decklist$decklist_id,
                                  i + seed_offset)
    result$bool_hit
  })

  mean(hit_vec)
}

#' Greedy positional search over the no-Bronzor order
#'
#' Fills rank 1 first, then rank 2 from what is left, and so on. The final rank
#' is forced, so the last round is skipped rather than evaluated.
#'
#' @param bool_going_first the coin flip.
#' @param verbose numeric; 1 prints each round's winner.
#'
#' @returns A list with `order_vec` and `round_df`, the per-round table of every
#'   candidate tried and its rate.
#' @noRd
.greedy_order <- function(bool_going_first, verbose = 1){
  chosen_vec <- character(0)
  remaining_vec <- CANDIDATE_VEC
  round_df <- data.frame(rank = integer(0), candidate = character(0),
                         hit_rate = numeric(0), stringsAsFactors = FALSE)

  while(length(remaining_vec) > 1){
    rate_vec <- sapply(remaining_vec, function(one_name){
      # The untried names keep their section 3 order behind the candidate, so
      # the only thing varying within a round is which name is promoted.
      trial_vec <- c(chosen_vec, one_name, setdiff(remaining_vec, one_name))
      .rate_of(trial_vec, bool_going_first, num_search)
    })

    round_df <- rbind(round_df,
                      data.frame(rank = length(chosen_vec) + 1L,
                                 candidate = remaining_vec,
                                 hit_rate = as.numeric(rate_vec),
                                 stringsAsFactors = FALSE))
    best_name <- remaining_vec[which.max(rate_vec)]
    if(verbose > 0){
      print(paste0("rank ", length(chosen_vec) + 1L, ": ", best_name, " (",
                   format(round(100 * max(rate_vec), 1), nsmall = 1), "%)"))
    }

    chosen_vec <- c(chosen_vec, best_name)
    remaining_vec <- setdiff(remaining_vec, best_name)
  }

  list(order_vec = c(chosen_vec, remaining_vec), round_df = round_df)
}

# ---------------------------------------------------------------------------
# The search
# ---------------------------------------------------------------------------

print("searching, going second")
second_list <- .greedy_order(bool_going_first = FALSE)

print("searching, going first")
first_list <- .greedy_order(bool_going_first = TRUE)

# ---------------------------------------------------------------------------
# Out-of-sample confirmation against the incumbent
# ---------------------------------------------------------------------------

incumbent_list <- list(going_first = LEAD_ORDER_LIST$going_first[-1],
                       going_second = LEAD_ORDER_LIST$going_second[-1])

print("confirming out of sample")
confirm_df <- data.frame(
  cell = c("going second", "going second", "going first", "going first"),
  order_str = c(paste0(incumbent_list$going_second, collapse = " > "),
                paste0(second_list$order_vec, collapse = " > "),
                paste0(incumbent_list$going_first, collapse = " > "),
                paste0(first_list$order_vec, collapse = " > ")),
  which_str = c("incumbent", "search", "incumbent", "search"),
  hit_rate = c(
    .rate_of(incumbent_list$going_second, FALSE, num_confirm,
             seed_offset = confirm_offset),
    .rate_of(second_list$order_vec, FALSE, num_confirm,
             seed_offset = confirm_offset),
    .rate_of(incumbent_list$going_first, TRUE, num_confirm,
             seed_offset = confirm_offset),
    .rate_of(first_list$order_vec, TRUE, num_confirm,
             seed_offset = confirm_offset)),
  stringsAsFactors = FALSE)

# And the cell the search never optimised, so a gain going first that is paid
# for under the Item lock is visible rather than assumed.
lock_df <- data.frame(
  which_str = c("incumbent", "search"),
  hit_rate = c(.rate_of(incumbent_list$going_first, TRUE, num_confirm,
                        scenario = "item_lock", seed_offset = confirm_offset),
               .rate_of(first_list$order_vec, TRUE, num_confirm,
                        scenario = "item_lock", seed_offset = confirm_offset)),
  stringsAsFactors = FALSE)

# ---------------------------------------------------------------------------
# Write it down
# ---------------------------------------------------------------------------

.pct <- function(x) paste0(format(round(100 * x, 1), nsmall = 1), "%")

.round_block <- function(round_df, title_str){
  line_vec <- c(paste0("### ", title_str), "",
                "| rank | candidate | hit rate |", "|---|---|---|")
  for(i in seq_len(nrow(round_df))){
    line_vec <- c(line_vec,
                  paste0("| ", round_df$rank[i], " | ", round_df$candidate[i],
                         " | ", .pct(round_df$hit_rate[i]), " |"))
  }

  c(line_vec, "")
}

line_vec <- c(
  "# The section 3 lead order, settled from the logs (DT-03)",
  "",
  paste0("Written by `scripts/tune_lead_order_claude.R` on ",
         format(Sys.Date()), ". decklist2, scenario `clear` unless stated."),
  "",
  paste0("Greedy positional search, **", num_search,
         " replicates per evaluation**, common random numbers within a round. ",
         "Bronzor is pinned at rank 1 and Meowth ex is excluded: both are ",
         "rulings in section 3, not defaults for this search to overturn."),
  "",
  paste0("**78% of decklist2 opening hands hold no Bronzor** ",
         "(`C(58,7)/C(60,7)`), so this order binds on most games rather than ",
         "on the 3% of hands the S-24 position described."),
  "",
  .round_block(second_list$round_df, "Going second"),
  .round_block(first_list$round_df, "Going first"),
  "## Out-of-sample confirmation",
  "",
  paste0("A greedy search picks the maximum of twenty noisy numbers, which is ",
         "the procedure that reports a winner when there is none. So the ",
         "winner is re-run against the incumbent on **", num_confirm,
         " replicates from a disjoint seed block** (seeds ",
         confirm_offset + 1L, "-", confirm_offset + num_confirm, ")."),
  "",
  "| cell | order | which | hit rate |",
  "|---|---|---|---|")
for(i in seq_len(nrow(confirm_df))){
  line_vec <- c(line_vec,
                paste0("| ", confirm_df$cell[i], " | ", confirm_df$order_str[i],
                       " | ", confirm_df$which_str[i], " | ",
                       .pct(confirm_df$hit_rate[i]), " |"))
}
line_vec <- c(
  line_vec, "",
  paste0("Going first under `item_lock`, which the search never optimised: ",
         "incumbent ", .pct(lock_df$hit_rate[1]), ", search ",
         .pct(lock_df$hit_rate[2]), "."),
  "")

writeLines(line_vec, out_path)
print(paste0("wrote ", out_path))
