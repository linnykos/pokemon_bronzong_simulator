# Reading and validating decklists.
#
# Decklists are stored in decklists/*.txt in the Pokemon TCG Live export format:
# section headers, then one "<count> <name> <SET> <number>" line per entry.
# A decklist is identified by its CONTENTS, not its filename -- two files whose
# card multisets agree are one decklist. See CONTEXT.md.

#' Read a decklist file
#'
#' Parses a PTCG-Live style export into a canonical 60-card multiset.
#'
#' Section headers (`Pokemon: 24`) are ignored entirely: in the files we were
#' given they count distinct *lines* rather than cards, so trusting them would
#' produce wrong totals. The count comes from summing the entries.
#'
#' @param file_path path to a `.txt` decklist.
#' @param card_df the card database from \code{build_card_database()}.
#' @param verbose numeric verbosity; 0 is silent.
#'
#' @returns An object of class `"bronzong_decklist"`: a list with
#'   \describe{
#'     \item{card_id_vec}{character vector of length 60, canonical card ids,
#'       one element per physical card, sorted.}
#'     \item{count_vec}{named integer vector, canonical card id to count.}
#'     \item{decklist_id}{character, a content hash. Two files with the same
#'       cards share a `decklist_id`.}
#'     \item{source_file}{character, the path this was read from.}
#'   }
#' @export
read_decklist <- function(file_path,
                          card_df,
                          verbose = 0){
  # Deliberately does NOT assert `verbose >= 0`. read_decklist_dir() passes
  # `verbose - 1` so that a caller asking for level-0 output does not get
  # per-file chatter, which makes -1 a normal value on the default path. A
  # helper that re-checks its caller's decremented verbosity rejects exactly the
  # calls it is supposed to serve.
  stopifnot(is.character(file_path), length(file_path) == 1,
            is.data.frame(card_df))

  if(!file.exists(file_path)) stop("no such decklist file: ", file_path)

  line_vec <- readLines(file_path, warn = FALSE)
  entry_df <- .parse_decklist_lines(line_vec)

  if(nrow(entry_df) == 0) stop("`file_path` contained no card lines: ", file_path)

  # lookup_card() errors on an unknown id, which is what we want: a decklist
  # citing a card we have never transcribed must fail loudly rather than be
  # silently dropped and produce a 57-card deck.
  lookup_card(card_df, entry_df$card_id)

  canonical_vec <- canonical_card_id(entry_df$card_id)
  card_id_vec <- sort(rep(canonical_vec, times = entry_df$count))

  count_vec <- table(card_id_vec)
  count_vec <- stats::setNames(as.integer(count_vec), names(count_vec))

  if(verbose > 0){
    print(paste0("Read ", length(card_id_vec), " cards from ", file_path))
  }

  structure(list(card_id_vec = card_id_vec,
                 count_vec = count_vec,
                 decklist_id = .decklist_hash(count_vec),
                 source_file = file_path),
            class = "bronzong_decklist")
}

#' Validate a decklist against the deck-construction rules
#'
#' Checks the rules from docs/01_rules_standard.md section 2 that a simulator
#' can actually get wrong: the 60-card total, the 4-copy limit with its basic
#' Energy exemption, and the presence of at least one Basic Pokemon.
#'
#' Does NOT check the ACE SPEC limit. None of the six decklists runs an ACE SPEC
#' and the card table has no column marking one, so the check would be vacuous;
#' adding an ACE SPEC card to any list means adding that column first.
#'
#' @param decklist a `"bronzong_decklist"` from \code{read_decklist()}.
#' @param card_df the card database.
#' @param bool_stop_on_error whether to `stop()` on a violation rather than
#'   returning it.
#'
#' @returns A character vector of violations, empty if the decklist is legal.
#'   Returned invisibly when there are none.
#' @export
validate_decklist <- function(decklist,
                              card_df,
                              bool_stop_on_error = TRUE){
  stopifnot(inherits(decklist, "bronzong_decklist"), is.data.frame(card_df))

  problem_vec <- character(0)

  num_cards <- length(decklist$card_id_vec)
  if(num_cards != 60){
    problem_vec <- c(problem_vec,
                     paste0("deck has ", num_cards, " cards, not 60"))
  }

  row_df <- lookup_card(card_df, names(decklist$count_vec))

  # Basic Energy is exempt from the 4-copy limit; Special Energy is not.
  is_exempt_vec <- row_df$category == "energy" & row_df$subtype == "basic"
  over_vec <- decklist$count_vec > 4 & !is_exempt_vec
  if(any(over_vec)){
    problem_vec <- c(problem_vec,
                     paste0("more than 4 copies of ",
                            paste0(names(decklist$count_vec)[over_vec],
                                   collapse = ", ")))
  }

  num_basics <- sum(decklist$count_vec[is_basic_pokemon(card_df,
                                                        names(decklist$count_vec))])
  if(num_basics == 0){
    problem_vec <- c(problem_vec, "deck contains no Basic Pokemon")
  }

  if(length(problem_vec) > 0 && bool_stop_on_error){
    stop("illegal decklist (", decklist$source_file, "): ",
         paste0(problem_vec, collapse = "; "))
  }

  if(length(problem_vec) == 0) return(invisible(problem_vec))
  problem_vec
}

#' Read every decklist in a directory
#'
#' @param decklist_dir directory holding `.txt` decklists.
#' @param card_df the card database.
#' @param bool_drop_duplicates whether to keep only the first file of each set
#'   of files sharing a `decklist_id`.
#' @param verbose numeric verbosity; 0 is silent.
#'
#' @returns A named list of `"bronzong_decklist"` objects, named by the file's
#'   basename without extension.
#' @export
read_decklist_dir <- function(decklist_dir,
                              card_df,
                              bool_drop_duplicates = TRUE,
                              verbose = 0){
  stopifnot(is.character(decklist_dir), length(decklist_dir) == 1)
  if(!dir.exists(decklist_dir)) stop("no such directory: ", decklist_dir)

  file_vec <- sort(list.files(decklist_dir, pattern = "\\.txt$",
                              full.names = TRUE))
  if(length(file_vec) == 0) stop("no .txt decklists in ", decklist_dir)

  decklist_list <- lapply(file_vec, function(one_file){
    read_decklist(file_path = one_file, card_df = card_df, verbose = verbose - 1)
  })
  names(decklist_list) <- tools::file_path_sans_ext(basename(file_vec))

  if(bool_drop_duplicates){
    id_vec <- sapply(decklist_list, function(x) x$decklist_id)
    keep_vec <- !duplicated(id_vec)

    if(verbose > 0 && any(!keep_vec)){
      print(paste0("Dropping ", sum(!keep_vec), " duplicate decklist(s): ",
                   paste0(names(decklist_list)[!keep_vec], collapse = ", ")))
    }
    decklist_list <- decklist_list[keep_vec]
  }

  decklist_list
}

#' @export
print.bronzong_decklist <- function(x, ...){
  cat("<bronzong_decklist>", x$decklist_id, "\n")
  cat("  source:", x$source_file, "\n")
  cat("  cards :", length(x$card_id_vec), "in", length(x$count_vec), "entries\n")
  invisible(x)
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

#' Parse the card lines of a decklist export
#'
#' @param line_vec character vector of raw lines.
#'
#' @returns A data frame with `count` (integer) and `card_id` (character).
#' @noRd
.parse_decklist_lines <- function(line_vec){
  # Files were authored on Windows and may carry CR; a trailing CR would end up
  # inside the card number and break the id.
  line_vec <- gsub("\r", "", line_vec, fixed = TRUE)
  line_vec <- trimws(line_vec)

  # "<count> <name...> <SET> <number>". The name is skipped: it is not unique
  # (three cards are named "Bronzor"), so set + number is the only safe key.
  pattern <- "^([0-9]+) +.* +([A-Z]{3}) +([0-9]+)$"
  keep_vec <- grepl(pattern, line_vec)

  if(!any(keep_vec)) return(data.frame(count = integer(0), card_id = character(0)))

  matched_vec <- line_vec[keep_vec]
  count_vec <- as.integer(sub(pattern, "\\1", matched_vec))
  set_vec <- sub(pattern, "\\2", matched_vec)
  num_vec <- as.integer(sub(pattern, "\\3", matched_vec))

  data.frame(count = count_vec,
             card_id = sprintf("%s-%03d", set_vec, num_vec),
             stringsAsFactors = FALSE)
}

#' Content hash identifying a decklist
#'
#' Two files whose card multisets agree must produce the same value, whatever
#' order their lines are in -- this is what makes a decklist identified by
#' contents rather than by filename.
#'
#' @param count_vec named integer vector of canonical card id to count.
#'
#' @returns A short character hash.
#' @noRd
.decklist_hash <- function(count_vec){
  ordered_vec <- count_vec[order(names(count_vec))]
  key_str <- paste0(names(ordered_vec), ":", ordered_vec, collapse = "|")

  # No digest package is available (base R only), so fold the string into a
  # polynomial rolling hash. Deliberately NOT FNV-1a: that needs bitwXor over a
  # 32-bit accumulator, and R's bitwXor coerces to integer, so any value above
  # .Machine$integer.max silently becomes NA and every decklist hashes alike.
  # Here the accumulator stays below 2^31 and the widest intermediate is
  # 2^31 * 31 < 2^53, so double arithmetic is exact throughout.
  # Collisions are irrelevant: this labels a handful of decklists, it is not a
  # security primitive.
  modulus_val <- 2147483647
  hash_val <- 0
  for(one_byte in utf8ToInt(key_str)){
    hash_val <- (hash_val * 31 + one_byte) %% modulus_val
  }

  stopifnot(!is.na(hash_val), hash_val >= 0, hash_val < modulus_val)

  paste0("dl_", format(as.hexmode(as.integer(hash_val)), width = 8))
}
