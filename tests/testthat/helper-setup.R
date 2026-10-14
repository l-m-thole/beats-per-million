# Sourced automatically by testthat before the tests run. This is not an
# installed package, so load the project code here, resolving the R/ directory
# from the common places tests get invoked from (project root or tests/testthat).
# Always (re)source everything, so tests/testthat.R and test_dir() both get
# the full set of functions.
local({
  candidates <- c(file.path("..", "..", "R"), "R", file.path("..", "R"))
  r_dir <- candidates[dir.exists(candidates)][1]
  if (is.na(r_dir)) stop("Could not locate the R/ directory for tests.")
  for (f in c("config.R", "functions.R", "period_context.R", "load_data.R",
              "settings.R", "spotify.R", "about.R", "library_check.R", "share.R",
              "refresh_co2.R")) {
    sys.source(file.path(r_dir, f), envir = globalenv())
  }
})
