# Tests for seeding and loading the persistent song library, including an
# Excel-style re-save (columns reordered + an extra column) round-trip.

LIB_COLS <- c("song_title", "artist", "spotify_uri",
              "soundcloud_url", "bpm", "notes")

test_that("load_song_library returns an empty, correctly-shaped tibble when absent", {
  dir <- tempfile("songlib-empty-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  lib <- load_song_library(data_dir = dir)
  expect_equal(nrow(lib), 0)
  expect_equal(names(lib), LIB_COLS)
  expect_type(lib$bpm, "double")
})

test_that("seed_song_library writes a header + example rows, and never overwrites", {
  dir <- tempfile("songlib-seed-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  f <- file.path(dir, "song_library.csv")

  seed_song_library(data_dir = dir)
  expect_true(file.exists(f))

  lib0 <- load_song_library(data_dir = dir)
  expect_equal(names(lib0), LIB_COLS)
  expect_equal(nrow(lib0), 2)
  expect_type(lib0$bpm, "double")
  expect_false(any(is.na(lib0$bpm)))

  # Re-seeding must leave a user-edited file untouched.
  df <- readr::read_csv(f, show_col_types = FALSE)
  df$notes[1] <- "SENTINEL"
  readr::write_csv(df, f)
  seed_song_library(data_dir = dir)
  again <- readr::read_csv(f, show_col_types = FALSE)
  expect_true(any(again$notes == "SENTINEL"))
})

test_that("an Excel-style re-save (reordered + extra column) still loads cleanly", {
  dir <- tempfile("songlib-resave-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  f <- file.path(dir, "song_library.csv")

  seed_song_library(data_dir = dir)
  original <- readr::read_csv(f, show_col_types = FALSE)

  # Simulate opening in Excel and saving: columns reordered, a stray column added.
  reordered <- original[, c("bpm", "notes", "artist",
                            "song_title", "soundcloud_url", "spotify_uri")]
  reordered$excel_helper <- "ignore me"
  readr::write_csv(reordered, f)

  lib <- load_song_library(data_dir = dir)
  expect_equal(names(lib), LIB_COLS)                 # canonical order restored
  expect_false("excel_helper" %in% names(lib))       # stray column dropped
  expect_type(lib$bpm, "double")                     # bpm coerced back to numeric
  expect_equal(sort(lib$bpm), sort(original$bpm))    # values survive the trip
})
