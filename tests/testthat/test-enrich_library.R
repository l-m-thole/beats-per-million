# Offline tests: no API keys or network needed (lookups are faked).
source(test_path("..", "..", "R", "enrich_library.R"))

test_that("normalise_str strips versions, features and punctuation", {
  expect_equal(normalise_str("Bring Me To Life (Remastered 2011)"), "bring me to life")
  expect_equal(normalise_str("Don't Stop Me Now - 2011 Remaster"), "dont stop me now")
  expect_equal(normalise_str("Joker & The Thief"), "joker and the thief")
  expect_equal(normalise_str("The Weeknd ft. Daft Punk"), "weeknd")
  expect_match(normalise_str("Händerna Mot Himlen"), "anderna mot himlen")
  expect_equal(normalise_str(NA), "")
})

test_that("primary_artist takes the first credited artist", {
  expect_equal(primary_artist_raw("Jay-Z & Kanye West ft. Otis Redding"), "Jay-Z")
  expect_equal(primary_artist_raw("Run DMC vs. Jason Nevins"), "Run DMC")
  expect_equal(primary_artist("Wyclef Jean Feat. Mary J. Blige"), "wyclef jean")
})

test_that("original beats karaoke; remix only penalised when not asked for", {
  orig    <- match_score("Zombie", "The Cranberries", "Zombie", "The Cranberries")
  karaoke <- match_score("Zombie", "The Cranberries", "Zombie (Karaoke Version)", "The Cranberries")
  expect_gt(orig, karaoke)
  expect_gte(match_score("Or Nah (Remix)", "Ty Dolla $ign",
                         "Or Nah (feat. The Weeknd) - Remix", "Ty Dolla $ign, The Weeknd"), 3)
  expect_lt(match_score("Or Nah", "Ty Dolla $ign",
                        "Or Nah - Remix", "Ty Dolla $ign"), 3)
})

test_that("pick_best needs title AND artist", {
  cands <- data.frame(
    title  = c("Zombie", "Zombie (Karaoke)", "Zombie"),
    artist = c("Some Tribute Band", "Karaoke Hits", "The Cranberries"),
    value  = c("x", "y", "z"), stringsAsFactors = FALSE
  )
  expect_equal(pick_best(cands, "Zombie", "The Cranberries")$value, "z")
  expect_null(pick_best(cands[1:2, ], "Zombie", "The Cranberries"))
  expect_null(pick_best(NULL, "Zombie", "The Cranberries"))
})

test_that("SoundCloud-style 'Artist - Title' uploads still match", {
  expect_gte(match_score("Bring Me To Life", "Evanescence",
                         "Evanescence - Bring Me To Life", "some_fan_account"), 3)
})

test_that("enrich_song_library fills blanks only, skips keyless steps, logs, backs up", {
  dir  <- withr::local_tempdir()
  path <- file.path(dir, "song_library.csv")
  writeLines(c(
    "song_title,artist,spotify_uri,soundcloud_url,bpm,notes",
    "Song A,Artist A,,,95,",
    "Song B,Artist B,,,,",
    ",Artist C,,,,"
  ), path)

  fakes <- list(
    bpm        = function(t, a) list(value = "172", matched_title = t, matched_artist = a, score = 4),
    spotify    = function(t, a) .stop_step("no keys"),
    soundcloud = function(t, a) NULL
  )
  log <- suppressMessages(enrich_song_library(path, lookups = fakes))
  lib <- readr::read_csv(path, col_types = readr::cols(.default = "c"),
                         na = character(), show_col_types = FALSE)

  expect_equal(lib$bpm, c("95", "172", ""))          # hand value kept, title-less row untouched
  expect_equal(lib$spotify_uri, c("", "", ""))        # step skipped, no crash
  expect_equal(nrow(log), 3)                          # 1 bpm + 2 soundcloud
  expect_match(log$flag[log$field == "bpm"], "outside 60-150")
  expect_true(all(log$flag[log$field == "soundcloud_url"] == "no confident match - fill by hand"))
  expect_length(list.files(file.path(dir, "backups")), 1)
  expect_true(file.exists(file.path(dir, "song_library_enrich_log.csv")))
})
