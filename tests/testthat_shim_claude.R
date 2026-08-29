# A minimal, testthat-compatible test harness in base R.
#
# testthat is not installable in this environment (no CRAN access from R), so
# this shim provides the subset of its API the test files use. The test files
# are written against testthat's real signatures and call it BARE, per the house
# style, so when testthat becomes available this file can simply be deleted and
# `devtools::test()` will run tests/testthat/ unchanged. That is the whole point
# of the shim: the tests are not written to a bespoke framework.
#
# Deliberately NOT implemented: mocking, snapshots, edition-3 behaviours. If a
# test needs one of those, install testthat rather than extending this.

.test_env <- new.env(parent = emptyenv())
.test_env$num_pass <- 0L
.test_env$num_fail <- 0L
.test_env$failure_vec <- character(0)
.test_env$context_str <- ""
.test_env$current_test <- ""

context <- function(desc){
  .test_env$context_str <- desc
  cat("\n", desc, "\n", sep = "")
  invisible(desc)
}

test_that <- function(desc, code){
  .test_env$current_test <- desc
  num_fail_before <- .test_env$num_fail

  result <- try(force(code), silent = TRUE)
  if(inherits(result, "try-error")){
    .record_failure(paste0("unexpected error: ",
                           conditionMessage(attr(result, "condition"))))
  }

  bool_passed <- .test_env$num_fail == num_fail_before
  cat(if(bool_passed) "  [PASS] " else "  [FAIL] ", desc, "\n", sep = "")

  invisible(bool_passed)
}

expect_true <- function(object, info = NULL){
  if(!isTRUE(object)) .record_failure(paste0("expected TRUE", .info_suffix(info)))
  invisible(object)
}

expect_false <- function(object, info = NULL){
  if(!identical(object, FALSE)){
    .record_failure(paste0("expected FALSE", .info_suffix(info)))
  }
  invisible(object)
}

expect_equal <- function(object, expected, info = NULL, tolerance = 1e-8){
  bool_ok <- isTRUE(all.equal(object, expected, tolerance = tolerance))
  if(!bool_ok){
    .record_failure(paste0("expected ", .deparse_short(expected),
                           " but got ", .deparse_short(object),
                           .info_suffix(info)))
  }
  invisible(object)
}

expect_identical <- function(object, expected, info = NULL){
  if(!identical(object, expected)){
    .record_failure(paste0("not identical: expected ", .deparse_short(expected),
                           " but got ", .deparse_short(object),
                           .info_suffix(info)))
  }
  invisible(object)
}

expect_length <- function(object, n, info = NULL){
  if(length(object) != n){
    .record_failure(paste0("expected length ", n, " but got ", length(object),
                           .info_suffix(info)))
  }
  invisible(object)
}

expect_error <- function(object, regexp = NULL, info = NULL){
  result <- try(force(object), silent = TRUE)
  if(!inherits(result, "try-error")){
    .record_failure(paste0("expected an error but none was raised",
                           .info_suffix(info)))
    return(invisible(NULL))
  }
  if(!is.null(regexp)){
    message_str <- conditionMessage(attr(result, "condition"))
    if(!grepl(regexp, message_str)){
      .record_failure(paste0("error message '", message_str,
                             "' did not match '", regexp, "'",
                             .info_suffix(info)))
    }
  }
  invisible(NULL)
}

expect_silent <- function(object, info = NULL){
  result <- try(force(object), silent = TRUE)
  if(inherits(result, "try-error")){
    .record_failure(paste0("expected no error, got: ",
                           conditionMessage(attr(result, "condition")),
                           .info_suffix(info)))
  }
  invisible(NULL)
}

#' Print the run summary and return the number of failures
#' @noRd
test_summary <- function(){
  cat("\n========================================\n")
  cat("passed: ", .test_env$num_pass, "   failed: ", .test_env$num_fail, "\n",
      sep = "")
  if(.test_env$num_fail > 0){
    cat("\nfailures:\n")
    cat(paste0("  - ", .test_env$failure_vec, collapse = "\n"), "\n")
  }
  cat("========================================\n")

  invisible(.test_env$num_fail)
}

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

.record_failure <- function(message_str){
  .test_env$num_fail <- .test_env$num_fail + 1L
  .test_env$failure_vec <- c(.test_env$failure_vec,
                             paste0("[", .test_env$context_str, "] ",
                                    .test_env$current_test, ": ", message_str))
  invisible(NULL)
}

.info_suffix <- function(info){
  if(is.null(info)) return("")
  paste0("  (", info, ")")
}

.deparse_short <- function(x){
  str_vec <- utils::capture.output(utils::str(x, give.attr = FALSE))
  paste0(substr(paste0(str_vec, collapse = " "), 1, 120))
}

# Every expectation that does not fail counts as a pass. Wrapping each public
# expectation would be tidier, but this keeps the shim short and the count is
# only used for the summary line.
local({
  for(one_name in c("expect_true", "expect_false", "expect_equal",
                    "expect_identical", "expect_length", "expect_error",
                    "expect_silent")){
    original_fn <- get(one_name, envir = globalenv())
    wrapped_fn <- local({
      inner_fn <- original_fn
      function(...){
        num_fail_before <- .test_env$num_fail
        out <- inner_fn(...)
        if(.test_env$num_fail == num_fail_before){
          .test_env$num_pass <- .test_env$num_pass + 1L
        }
        out
      }
    })
    assign(one_name, wrapped_fn, envir = globalenv())
  }
})
