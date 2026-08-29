# Smoke test for the base simulator. Loads the engine, reads and validates every
# decklist, runs a setup, and hand-plays the turn-1 Salvatore kill going second.
#
# This is NOT a Monte Carlo and not the policy -- it only checks that the engine
# is wired together correctly and that the target event can be reached at all.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/smoke_test_claude.R

rm(list = ls())

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

card_df <- build_card_database()
print(paste0("card database: ", nrow(card_df), " printings"))

# --- every decklist parses and is legal -----------------------------------

decklist_list <- read_decklist_dir("decklists", card_df, verbose = 1)
for(one_name in names(decklist_list)){
  validate_decklist(decklist_list[[one_name]], card_df)
  print(paste0(one_name, ": ", length(decklist_list[[one_name]]$card_id_vec),
               " cards, id ", decklist_list[[one_name]]$decklist_id))
}

# --- setup conserves cards -------------------------------------------------

set.seed(10)
pair <- setup_game(decklist = decklist_list[["decklist2"]],
                   card_df = card_df,
                   bool_going_first = FALSE,
                   scenario = "clear",
                   verbose = 1)

num_in_play <- length(unlist(lapply(all_in_play(pair$state),
                                    function(x) x$stack_vec)))
num_total <- length(pair$state$deck_vec) + length(pair$state$hand_vec) +
  length(pair$state$prize_vec) + length(pair$state$discard_vec) + num_in_play
print(paste0("cards accounted for after setup: ", num_total))
stopifnot(num_total == 60)

print(pair$state)

# --- the first player cannot Supporter or attack on turn 1 -----------------

first_pair <- setup_game(decklist = decklist_list[["decklist2"]],
                         card_df = card_df,
                         bool_going_first = TRUE)
first_pair$state <- begin_turn(first_pair$state)
stopifnot(!can_play_supporter(first_pair$state),
          !can_attack(first_pair$state))
print("going first, turn 1: no Supporter, no attack -- as expected")

# Items are locked on OUR turn 2 only in the item_lock scenario, and only when
# we went first (Itchy Pollen is an attack, so the opponent needed to go second).
lock_pair <- setup_game(decklist = decklist_list[["decklist2"]],
                        card_df = card_df,
                        bool_going_first = TRUE,
                        scenario = "item_lock")
lock_pair$state <- begin_turn(lock_pair$state)
stopifnot(can_play_item(lock_pair$state))
lock_pair$state <- begin_turn(lock_pair$state)
stopifnot(!can_play_item(lock_pair$state))
print("item_lock: Items live on turn 1, locked on turn 2 -- as expected")

# --- ADR 0003: no peeking at prizes ----------------------------------------

# Find a card that IS prized in this game, then assert the player does not know
# it before searching and does know it after. This is the central guarantee of
# ADR 0003, so it is asserted rather than eyeballed.
peek <- setup_game(decklist = decklist_list[["decklist2"]],
                   card_df = card_df,
                   bool_going_first = FALSE)
prized_id <- peek$state$prize_vec[1]
copies_elsewhere <- sum(peek$state$hand_vec == prized_id) +
  sum(sapply(all_in_play(peek$state),
             function(x) sum(x$stack_vec == prized_id)))

# Before any search the player must still believe a prized card is findable,
# unless they can already see every copy of it.
if(copies_elsewhere == 0){
  stopifnot(believes_findable(peek$knowledge, peek$state, prized_id))
}
stopifnot(!peek$knowledge$bool_deck_seen,
          all(peek$knowledge$known_unavailable_vec == 0))
print(paste0("before searching, ", prized_id,
             " is prized but the player does not know it"))

peek$knowledge <- knowledge_after_search(peek$knowledge, peek$state)
stopifnot(peek$knowledge$bool_deck_seen,
          sum(peek$knowledge$known_unavailable_vec) == 6)
print("after searching, exactly 6 cards are deduced unavailable")

# A shuffle destroys ordering knowledge but NOT contents knowledge.
peek$knowledge <- knowledge_after_stacking(peek$knowledge, c("TEF-069"))
stopifnot(length(peek$knowledge$top_known_vec) == 1)
peek$knowledge <- knowledge_after_shuffle(peek$knowledge)
stopifnot(length(peek$knowledge$top_known_vec) == 0,
          peek$knowledge$bool_deck_seen,
          sum(peek$knowledge$known_unavailable_vec) == 6)
print("shuffle clears deck ORDER knowledge but keeps CONTENTS knowledge")

# --- evolution timing ------------------------------------------------------

# A setup Bronzor cannot evolve on turn 1 by the normal route, but Salvatore
# may (ADR 0001). Build the position by hand rather than trusting a shuffle.
demo <- setup_game(decklist = decklist_list[["decklist2"]],
                   card_df = card_df,
                   bool_going_first = FALSE)
demo$state$active <- new_in_play("TEF-068", turn_played = 0L)
demo$state <- begin_turn(demo$state)

stopifnot(!can_evolve(demo$state, demo$state$active, "TEF-069"))
stopifnot(can_evolve(demo$state, demo$state$active, "TEF-069",
                     bool_via_salvatore = TRUE))
print("turn 1: normal evolution blocked, Salvatore evolution allowed")

# Dusknoir has Cursed Blast, so Salvatore may never fetch it; Bronzong has no
# Ability, so it may.
demo$state$bench_list <- list(new_in_play("PRE-035", turn_played = 0L))
stopifnot(is_salvatore_target(demo$state, "TEF-069"))
stopifnot(!is_salvatore_target(demo$state, "PRE-036"))
print("Salvatore targets: Bronzong yes, Dusclops no")

# --- hand-play the turn-1 kill ---------------------------------------------

kill <- setup_game(decklist = decklist_list[["decklist2"]],
                   card_df = card_df,
                   bool_going_first = FALSE)
kill$state$active <- new_in_play("TEF-068", turn_played = 0L)
kill$state <- begin_turn(kill$state)

# Force the pieces into hand so the line is reachable deterministically. A real
# replicate would have to find them; that is part 5's job.
for(one_id in c("TEF-160", "POR-088")){
  if(!one_id %in% kill$state$hand_vec){
    kill$state <- move_cards(kill$state, one_id, from = "deck", to = "hand")
  }
}

kill <- play_salvatore(kill, target_id = "TEF-069", target_is_active = TRUE)
stopifnot(top_card(kill$state$active) == "TEF-069")

kill <- attach_energy(kill, "POR-088", target_is_active = TRUE,
                      search_id_vec = "PRE-035")
stopifnot(can_use_evolution_jammer(kill$state))

kill <- attack_evolution_jammer(kill)
print("TURN-1 EVOLUTION JAMMER reached going second")

# The belief state must have learned what is prized -- but only because a search
# happened, never from the prize pile itself.
print(kill$knowledge)
stopifnot(kill$knowledge$bool_deck_seen)

cat("\n--- event log ---\n")
cat(paste0(kill$state$event_log, collapse = "\n"), "\n")

print("ALL SMOKE TESTS PASSED")
