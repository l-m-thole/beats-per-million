# Sourced automatically by testthat before the tests run. This is not an
# installed package, so load the project code here, resolving the R/ directory
# from the common places tests get invoked from (project root or tests/testthat).
if (!exists("co2_to_bpm")) {
  candidates <- c(file.path("..", "..", "R"), "R", file.path("..", "R"))
  r_dir <- candidates[dir.exists(candidates)][1]
  if (is.na(r_dir)) stop("Could not locate the R/ directory for tests.")
  for (f in c("config.R", "functions.R", "period_context.R", "load_data.R", "spotify.R")) {
    source(file.path(r_dir, f))
  }
}
