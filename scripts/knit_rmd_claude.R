# A stand-in for knitr, because knitr is not installable here.
#
# R_BIN on this machine has base R plus the recommended packages and no CRAN
# access, so `rmarkdown::render()` does not exist. The same problem as testthat,
# solved the same way (tests/testthat_shim_claude.R): the SOURCE stays standard
# -- demo/*.Rmd is ordinary R Markdown, chunk options and all -- and this script
# stands in for the renderer until the real one is available. When it is,
# `rmarkdown::render()` should produce the same document from the same file, and
# this script can be deleted rather than migrated.
#
# What it supports, which is what the demo uses and no more:
#   - YAML front matter, read for `title`, `author` and `date`
#   - ```{r label, opt = value} chunks, with echo / eval / include / fig.width /
#     fig.height / fig.cap
#   - inline `r expr` substitution in prose
#   - base graphics, captured through grDevices::png()
#
# What it deliberately does not support: caching, child documents, non-R
# engines, ggplot2 print semantics, and every other thing knitr does. If the
# demo starts needing one of those, that is the signal to stop extending this.
#
# Run with:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/knit_rmd_claude.R \
#     demo/demo_simulator_claude.Rmd

rm(list = ls())

# --- the one external location this script needs ----------------------------

# PANDOC: see CLAUDE.md -> External Locations. The path is per-machine and lives
# in CLAUDE_kevin.md; this is Kevin's Windows desktop. Missing pandoc is not
# fatal -- the .md is the artefact that matters, the .html is a convenience.
PANDOC_PATH <- file.path("C:", "Program Files", "RStudio", "resources", "app",
                         "bin", "quarto", "bin", "tools", "pandoc.exe")

# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

#' Split YAML front matter from the body
#'
#' @param line_vec the whole file, one element per line.
#'
#' @returns A list with `meta_list` (title/author/date, possibly empty) and
#'   `body_vec`.
#' @noRd
.split_front_matter <- function(line_vec){
  if(length(line_vec) == 0 || !grepl("^---\\s*$", line_vec[1])){
    return(list(meta_list = list(), body_vec = line_vec))
  }

  close_idx <- which(grepl("^---\\s*$", line_vec))[2]
  if(is.na(close_idx)) stop("YAML front matter is opened but never closed")

  yaml_vec <- line_vec[2:(close_idx - 1)]
  meta_list <- list()
  for(one_key in c("title", "author", "date")){
    hit_vec <- grep(paste0("^", one_key, ":"), yaml_vec, value = TRUE)
    if(length(hit_vec) > 0){
      value_str <- sub(paste0("^", one_key, ":\\s*"), "", hit_vec[1])
      meta_list[[one_key]] <- gsub('^"|"$', "", trimws(value_str))
    }
  }

  list(meta_list = meta_list,
       body_vec = if(close_idx == length(line_vec)) character(0) else
         line_vec[(close_idx + 1):length(line_vec)])
}

#' Split on commas that are not inside a quoted string
#'
#' `strsplit(x, ",")` cuts `fig.cap = "rate by lead, going second"` in half, and
#' the half then parses as a chunk label -- which is how a chunk came to be
#' logged as `going second"`. Walks characters instead, which is more code and
#' the only correct answer short of a real parser.
#' @noRd
.split_outside_quotes <- function(text_str){
  char_vec <- strsplit(text_str, "")[[1]]
  bool_in_quote <- FALSE
  quote_chr <- ""
  part_vec <- character(0)
  buffer_str <- ""

  for(one_char in char_vec){
    if(bool_in_quote){
      if(one_char == quote_chr) bool_in_quote <- FALSE
      buffer_str <- paste0(buffer_str, one_char)
      next
    }
    if(one_char %in% c('"', "'")){
      bool_in_quote <- TRUE
      quote_chr <- one_char
      buffer_str <- paste0(buffer_str, one_char)
      next
    }
    if(one_char == ","){
      part_vec <- c(part_vec, buffer_str)
      buffer_str <- ""
      next
    }
    buffer_str <- paste0(buffer_str, one_char)
  }

  c(part_vec, buffer_str)
}

#' Parse a chunk header into its options
#'
#' `{r label, echo = FALSE, fig.width = 7}` -> list(label = ..., echo = FALSE).
#' Values are parsed as R, so TRUE/FALSE/numbers arrive as themselves rather
#' than as strings.
#' @noRd
.parse_chunk_header <- function(header_str){
  inner_str <- sub("^```\\{r\\s*", "", header_str)
  inner_str <- sub("\\}\\s*$", "", inner_str)
  if(nchar(trimws(inner_str)) == 0) return(list())

  part_vec <- trimws(.split_outside_quotes(inner_str))
  opt_list <- list()
  for(one_part in part_vec){
    if(!grepl("=", one_part)){
      opt_list$label <- one_part
      next
    }
    key_str <- trimws(sub("=.*$", "", one_part))
    value_str <- trimws(sub("^[^=]*=", "", one_part))
    opt_list[[key_str]] <- tryCatch(eval(parse(text = value_str)),
                                    error = function(e) value_str)
  }

  opt_list
}

# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

#' Evaluate one chunk and format it as markdown
#'
#' Errors are NOT swallowed. A demo that renders around a broken chunk is worse
#' than one that fails, because the document then looks finished and is quietly
#' wrong -- the same failure mode the trace file's warnings exist to prevent.
#'
#' @param code_vec the chunk's source lines.
#' @param opt_list its options.
#' @param env the environment every chunk shares.
#' @param fig_dir where plots are written.
#' @param fig_idx a counter, so figure filenames are unique.
#'
#' @returns A character vector of markdown lines.
#' @noRd
.eval_chunk <- function(code_vec, opt_list, env, fig_dir, fig_idx){
  bool_eval <- !identical(opt_list$eval, FALSE)
  bool_echo <- !identical(opt_list$echo, FALSE)
  bool_include <- !identical(opt_list$include, FALSE)

  out_vec <- character(0)
  if(bool_echo && bool_include){
    out_vec <- c(out_vec, "``` r", code_vec, "```")
  }
  if(!bool_eval) return(out_vec)

  bool_fig <- !is.null(opt_list$fig.width) || !is.null(opt_list$fig.height)
  fig_path <- NULL
  if(bool_fig){
    dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
    fig_path <- file.path(fig_dir, paste0("fig-", fig_idx, ".png"))
    width_val <- if(is.null(opt_list$fig.width)) 7 else opt_list$fig.width
    height_val <- if(is.null(opt_list$fig.height)) 5 else opt_list$fig.height
    grDevices::png(fig_path, width = width_val * 100, height = height_val * 100,
                   res = 100)
    on.exit(if(grDevices::dev.cur() > 1) grDevices::dev.off(), add = TRUE)
  }

  # `knitr::opts_chunk$set(...)` is standard in a setup chunk and must not stop
  # the knit here. It cannot be shimmed with a variable -- `::` bypasses the
  # search path and loads the namespace -- so the calls are dropped instead.
  # They are directives to the renderer, and this renderer's defaults (echo on,
  # messages through) already match what the demo asks for.
  eval_vec <- code_vec[!grepl("^\\s*knitr::", code_vec)]
  if(length(eval_vec) == 0 || all(!nzchar(trimws(eval_vec)))) return(out_vec)

  expr_list <- parse(text = paste0(eval_vec, collapse = "\n"))
  printed_vec <- utils::capture.output({
    for(one_expr in expr_list){
      result_list <- withVisible(eval(one_expr, envir = env))
      if(result_list$visible) print(result_list$value)
    }
  })

  if(bool_fig){
    grDevices::dev.off()
    on.exit()
  }
  if(!bool_include) return(character(0))

  if(length(printed_vec) > 0){
    out_vec <- c(out_vec, "", "```", printed_vec, "```")
  }
  if(bool_fig && file.exists(fig_path)){
    cap_str <- if(is.null(opt_list$fig.cap)) "" else opt_list$fig.cap
    out_vec <- c(out_vec, "",
                 paste0("![", cap_str, "](", basename(fig_dir), "/",
                        basename(fig_path), ")"))
  }

  out_vec
}

#' Substitute inline `r expr` in a prose line
#' @noRd
.eval_inline <- function(line_str, env){
  match_list <- gregexpr("`r [^`]+`", line_str)
  hit_vec <- regmatches(line_str, match_list)[[1]]
  if(length(hit_vec) == 0) return(line_str)

  value_vec <- sapply(hit_vec, function(one_hit){
    code_str <- sub("^`r\\s*", "", sub("`$", "", one_hit))
    paste0(format(eval(parse(text = code_str), envir = env)), collapse = ", ")
  })
  regmatches(line_str, match_list) <- list(value_vec)

  line_str
}

# ---------------------------------------------------------------------------
# The knit
# ---------------------------------------------------------------------------

#' Render one .Rmd to .md, and to .html when pandoc is available
#'
#' @param rmd_path the source document.
#' @param verbose numeric verbosity; 1 reports each chunk.
#'
#' @returns The path of the .md, invisibly.
#' @noRd
knit_rmd <- function(rmd_path, verbose = 1){
  stopifnot(file.exists(rmd_path))

  split_list <- .split_front_matter(readLines(rmd_path, warn = FALSE))
  body_vec <- split_list$body_vec
  out_dir <- dirname(rmd_path)
  fig_dir <- file.path(out_dir, "figure")

  # One environment for the whole document, so a chunk sees what earlier chunks
  # made -- the property that makes a narrative document possible at all.
  env <- new.env(parent = globalenv())

  md_vec <- character(0)
  if(!is.null(split_list$meta_list$title)){
    md_vec <- c(md_vec, paste0("# ", split_list$meta_list$title), "")
    byline_vec <- unlist(split_list$meta_list[c("author", "date")])
    if(length(byline_vec) > 0){
      byline_str <- paste0(byline_vec, collapse = " &mdash; ")
      md_vec <- c(md_vec, paste0("*", byline_str, "*"), "")
    }
  }

  idx <- 1L
  num_chunks <- 0L
  while(idx <= length(body_vec)){
    one_line <- body_vec[idx]

    if(!grepl("^```\\{r", one_line)){
      md_vec <- c(md_vec, .eval_inline(one_line, env))
      idx <- idx + 1L
      next
    }

    # Guarded because `(idx + 1):length(body_vec)` counts BACKWARDS when the
    # chunk header is the last line of the file, so an unclosed final chunk
    # would rescan the document and silently match an earlier fence instead of
    # reporting the error below.
    if(idx >= length(body_vec)){
      stop("chunk opened at line ", idx, " is never closed")
    }
    tail_vec <- body_vec[(idx + 1):length(body_vec)]
    close_idx <- idx + which(grepl("^```\\s*$", tail_vec))[1]
    if(is.na(close_idx)) stop("chunk opened at line ", idx, " is never closed")

    opt_list <- .parse_chunk_header(one_line)
    num_chunks <- num_chunks + 1L
    if(verbose > 0){
      label_str <- if(is.null(opt_list$label)) "(unlabelled)" else
        opt_list$label
      print(paste0("chunk ", num_chunks, ": ", label_str))
    }

    code_vec <- if(close_idx > idx + 1) body_vec[(idx + 1):(close_idx - 1)] else
      character(0)
    md_vec <- c(md_vec, .eval_chunk(code_vec, opt_list, env, fig_dir,
                                    num_chunks))
    idx <- close_idx + 1L
  }

  md_path <- sub("[.][Rr]md$", ".md", rmd_path)
  writeLines(md_vec, md_path)
  if(verbose > 0) print(paste0("wrote ", md_path))

  .render_html(md_path, split_list$meta_list, verbose = verbose)

  invisible(md_path)
}

#' Convert the .md to a standalone .html with pandoc
#' @noRd
.render_html <- function(md_path, meta_list, verbose = 1){
  if(!file.exists(PANDOC_PATH)){
    print("pandoc not found; skipping the .html (the .md is the artefact)")
    return(invisible(NULL))
  }

  html_path <- sub("[.]md$", ".html", md_path)
  title_str <- if(is.null(meta_list$title)) basename(md_path) else
    meta_list$title
  status_val <- system2(PANDOC_PATH,
                        args = c(shQuote(md_path),
                                 "-o", shQuote(html_path),
                                 "--standalone", "--toc", "--toc-depth=2",
                                 "--metadata", shQuote(paste0("title=",
                                                              title_str))))
  if(status_val != 0) stop("pandoc failed with status ", status_val)
  if(verbose > 0) print(paste0("wrote ", html_path))

  invisible(html_path)
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

arg_vec <- commandArgs(trailingOnly = TRUE)
if(length(arg_vec) == 0){
  stop("usage: Rscript scripts/knit_rmd_claude.R <path to .Rmd>")
}

knit_rmd(arg_vec[1])
