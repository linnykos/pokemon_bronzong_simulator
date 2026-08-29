# Test runner.
#
# Uses the testthat shim in tests/testthat_shim_claude.R because testthat is not
# installable in this environment. The test files themselves are written against
# testthat's real API, so once testthat is available this runner can be replaced
# by `devtools::test()` and the tests are unchanged.
#
# Run from the project root:
#   "/c/Program Files/R/R-4.6.1/bin/Rscript.exe" tests/run_tests_claude.R

rm(list = ls())

if(!file.exists("R") || !dir.exists("tests/testthat")){
  stop("run this from the project root, not from tests/")
}

for(one_file in list.files("R", pattern = "[.]R$", full.names = TRUE)){
  source(one_file)
}

source("tests/testthat_shim_claude.R")

# Helpers first, matching testthat's own ^helper convention.
helper_vec <- list.files("tests/testthat", pattern = "^helper.*[.]R$",
                         full.names = TRUE)
for(one_file in helper_vec) source(one_file)

test_vec <- sort(list.files("tests/testthat", pattern = "^test_.*[.]R$",
                            full.names = TRUE))
for(one_file in test_vec){
  source(one_file)
}

num_fail <- test_summary()

# A non-zero exit status is what makes this usable from a hook or CI.
if(num_fail > 0) quit(status = 1)
