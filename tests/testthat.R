library(testthat)

# This project is a set of scripts rather than an installed package, so load the
# code before running the tests. (The helper in tests/testthat/ also loads it,
# which makes `testthat::test_dir("tests/testthat")` work on its own.)
source("R/config.R")
source("R/functions.R")
source("R/load_data.R")

test_dir("tests/testthat")
