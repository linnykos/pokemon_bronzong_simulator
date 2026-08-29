# Produce a real trace file, so the format can be judged by reading it.
#
# This is NOT the Monte Carlo (part 6) and NOT the policy (part 5). It runs a
# small number of replicates with a deliberately crude placeholder policy, purely
# to exercise the trace machinery end to end and emit results/demo_traces.txt.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/demo_traces_claude.R

rm(list = ls())

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

card_df <- build_card_database()
decklist <- read_decklist("decklists/decklist2.txt", card_df)

# A crude stand-in for part 5. It plays the obvious line and nothing clever, so
# the traces show plenty of misses -- which is exactly what makes the format
# worth judging. Do NOT mistake this for the policy.
.demo_turn <- function(pair){
  state <- pair$state

  ## Bench any Basic we are holding, while there is room.
  basic_vec <- state$hand_vec[is_basic_pokemon(state$card_df, state$hand_vec)]
  for(one_id in basic_vec){
    if(!has_bench_space(pair$state)) break
    pair <- play_basic_to_bench(pair, one_id)
  }

  ## Free search for a Bronzor if we have none in play.
  in_play_name_vec <- sapply(all_in_play(pair$state), function(one){
    lookup_card(pair$state$card_df, top_card(one))$name
  })
  if(!"Bronzor" %in% in_play_name_vec && "POR-081" %in% pair$state$hand_vec &&
     can_play_item(pair$state)){
    target_id <- if(believes_findable(pair$knowledge, pair$state, "TEF-068"))
      "TEF-068" else NULL
    pair <- play_poke_pad(pair, target_id = target_id)
    if("TEF-068" %in% pair$state$hand_vec && has_bench_space(pair$state)){
      pair <- play_basic_to_bench(pair, "TEF-068")
    }
  }

  ## Supporter: Salvatore on turn 1 if the kill is live, else Hilda.
  bool_bronzor_active <- !is.null(pair$state$active) &&
    lookup_card(pair$state$card_df, top_card(pair$state$active))$name == "Bronzor"
  if(can_play_supporter(pair$state)){
    if("TEF-160" %in% pair$state$hand_vec && bool_bronzor_active &&
       is_salvatore_target(pair$state, "TEF-069")){
      pair <- play_salvatore(pair, target_id = "TEF-069",
                             target_is_active = TRUE)
    } else if("WHT-084" %in% pair$state$hand_vec){
      energy_id <- if(believes_findable(pair$knowledge, pair$state, "POR-088"))
        "POR-088" else NULL
      evo_id <- if(believes_findable(pair$knowledge, pair$state, "TEF-069"))
        "TEF-069" else NULL
      pair <- play_hilda(pair, evolution_id = evo_id, energy_id = energy_id)
    }
  }

  ## Switch a benched Bronzor into the Active spot.
  if(!bool_bronzor_active && "MEG-130" %in% pair$state$hand_vec &&
     can_play_item(pair$state)){
    bench_name_vec <- sapply(pair$state$bench_list, function(one){
      lookup_card(pair$state$card_df, top_card(one))$name
    })
    idx_vec <- which(bench_name_vec == "Bronzor")
    if(length(idx_vec) > 0) pair <- play_switch(pair, bench_idx = idx_vec[1])
  }

  ## Evolve an Active Bronzor.
  if(!is.null(pair$state$active) && "TEF-069" %in% pair$state$hand_vec &&
     can_evolve(pair$state, pair$state$active, "TEF-069")){
    pair <- evolve_pokemon(pair, "TEF-069", target_is_active = TRUE)
  }

  ## Attach a [P] source to the Active.
  energy_vec <- intersect(pair$state$hand_vec, c("SVE-005", "POR-088"))
  if(length(energy_vec) > 0 && can_attach_energy(pair$state) &&
     !is.null(pair$state$active)){
    pair <- attach_energy(pair, energy_vec[1], target_is_active = TRUE)
  }

  if(can_use_evolution_jammer(pair$state)) pair <- attack_evolution_jammer(pair)

  pair
}

.run_replicate <- function(seed_number, bool_going_first){
  set.seed(seed_number)
  pair <- setup_game(decklist, card_df, bool_going_first = bool_going_first)

  for(one_turn in 1:2){
    pair$state <- begin_turn(pair$state)
    pair <- draw_to_hand(pair, num_cards = 1L)
    pair$state <- log_hand_snapshot(pair$state, "hand")
    if(can_act(pair$state)) pair <- .demo_turn(pair)
  }

  pair
}

# --- run, sampling traces stratified toward misses --------------------------

num_replicates <- 400L
sampler <- new_trace_sampler(max_miss = 12L, max_hit = 4L)

result_list <- vector("list", num_replicates)
trace_list <- list()

for(i in seq_len(num_replicates)){
  pair <- .run_replicate(seed_number = i, bool_going_first = FALSE)
  result <- summarise_replicate(pair, decklist_id = decklist$decklist_id,
                                seed_number = i,
                                bool_keep_trace = !sampler_is_full(sampler))

  take_list <- sampler_take(sampler, result$bool_hit)
  sampler <- take_list$sampler
  if(take_list$bool_keep) trace_list[[length(trace_list) + 1]] <- result

  ## The aggregate must never carry traces: 400 of them is already unwieldy and
  ## 10,000 would be unusable.
  result$trace_vec <- NULL
  result_list[[i]] <- result
}

summary_list <- summarise_run(result_list)

dir.create("results", showWarnings = FALSE)
write_trace_file(trace_list, file.path("results", "demo_traces.txt"),
                 summary_list, decklist = decklist)

print(paste0("hit rate: ", round(100 * summary_list$hit_rate, 2), "%"))
print(paste0("mulligan rate: ", round(100 * summary_list$mulligan_rate, 2),
             "%  mean: ", round(summary_list$mean_mulligans, 3),
             "  max: ", summary_list$max_mulligans))
print("unmet sub-goal tally (as a SET, over misses):")
print(summary_list$unmet_tally_vec)
print("play motifs:")
print(summary_list$motif_tally_vec)
print(paste0("misses with an unused out in hand: ", summary_list$num_unused_out))
print(paste0("traces written: ", length(trace_list),
             " -> results/demo_traces.txt"))
