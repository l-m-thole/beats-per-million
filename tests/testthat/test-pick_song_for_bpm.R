# Tests for the BPM song matcher (pick_song_for_bpm / pick_song_widening /
# assign_songs_to_playlist). A small fixture library keeps the cases readable.

make_lib <- function() {
  tibble::tibble(
    song_title     = c("A", "B", "C", "D", "E"),
    artist         = c("a", "b", "c", "d", "e"),
    spotify_uri    = c("", "", "", "", ""),
    soundcloud_url = c("", "", "", "", ""),
    bpm            = c(60, 95, 100, 103, 140),
    notes          = c("", "", "", "", "")
  )
}

test_that("a song inside the tolerance is returned, and it really is in range", {
  lib <- make_lib()
  set.seed(1)
  hit <- pick_song_for_bpm(lib, target_bpm = 100, tol = 5)   # B/C/D qualify
  expect_false(is.null(hit))
  expect_equal(nrow(hit), 1)
  expect_lte(abs(hit$bpm - 100), 5)
})

test_that("nothing within tolerance returns NULL", {
  lib <- make_lib()
  # window [116,120] contains no song (103 and 140 are the nearest)
  expect_null(pick_song_for_bpm(lib, target_bpm = 118, tol = 2))
})

test_that("the widening wrapper falls back to the single nearest song", {
  lib <- make_lib()
  set.seed(1)
  # tol 5 -> none; tol 10 -> none; nearest to 118 is 103 (dist 15) < 140 (dist 22)
  w <- pick_song_widening(lib, target_bpm = 118)
  expect_equal(w$song_title, "D")
})

test_that("the widening wrapper prefers a tolerance hit over the nearest fallback", {
  lib <- make_lib()
  set.seed(3)
  w <- pick_song_widening(lib, target_bpm = 100)   # B/C/D are all within tol 5
  expect_lte(abs(w$bpm - 100), 5)
})

test_that("excluded titles are never picked", {
  lib <- make_lib()
  set.seed(1)
  # candidates for 100 +/-5 are B, C, D; exclude two -> must return the third
  hit <- pick_song_for_bpm(lib, target_bpm = 100, tol = 5, exclude = c("B", "C"))
  expect_equal(hit$song_title, "D")
  # excluding every candidate -> NULL
  expect_null(pick_song_for_bpm(lib, target_bpm = 100, tol = 5,
                                exclude = c("B", "C", "D")))
})

test_that("an empty or NULL library yields NULL, not an error", {
  lib <- make_lib()
  expect_null(pick_song_for_bpm(lib[0, ], target_bpm = 100, tol = 5))
  expect_null(pick_song_for_bpm(NULL,     target_bpm = 100, tol = 5))
  expect_null(pick_song_widening(lib[0, ], target_bpm = 100))
  expect_null(pick_song_widening(NULL,     target_bpm = 100))
})

test_that("a missing target BPM yields NULL", {
  lib <- make_lib()
  expect_null(pick_song_for_bpm(lib, target_bpm = NA_real_, tol = 5))
  expect_null(pick_song_widening(lib, target_bpm = NA_real_))
})

test_that("the random pick is reproducible under the same seed", {
  lib <- make_lib()
  set.seed(42); a <- pick_song_for_bpm(lib, target_bpm = 100, tol = 40)
  set.seed(42); b <- pick_song_for_bpm(lib, target_bpm = 100, tol = 40)
  expect_identical(a, b)
})

test_that("assign_songs_to_playlist is reproducible and never repeats a title", {
  lib   <- make_lib()
  songs <- tibble::tibble(song_number = 1:4, bpm = c(60, 100, 103, 140))

  p1 <- assign_songs_to_playlist(songs, lib, period = "roman", shuffle_counter = 0)
  p2 <- assign_songs_to_playlist(songs, lib, period = "roman", shuffle_counter = 0)
  expect_identical(p1, p2)                              # seeded reproducibility

  # one row per matched slot, canonical columns, no duplicate titles in a period
  expect_true(all(c("song_number", "song_title", "bpm") %in% names(p1)))
  expect_equal(length(p1$song_title), length(unique(p1$song_title)))
})

test_that("assign_songs_to_playlist reseeds per period + shuffle counter", {
  lib   <- make_lib()
  songs <- tibble::tibble(song_number = 1:5, bpm = c(60, 95, 100, 103, 140))

  base    <- assign_songs_to_playlist(songs, lib, "roman", shuffle_counter = 0)
  shuffled <- assign_songs_to_playlist(songs, lib, "roman", shuffle_counter = 1)
  other   <- assign_songs_to_playlist(songs, lib, "lgm",   shuffle_counter = 0)

  # Same shape, but the seed differs, so the mapping is allowed to differ.
  expect_equal(names(base), names(shuffled))
  expect_equal(names(base), names(other))
  expect_identical(
    assign_songs_to_playlist(songs, lib, "roman", 1),
    shuffled
  )
})

test_that("an empty library gives an empty, correctly-shaped assignment", {
  lib   <- make_lib()[0, ]
  songs <- tibble::tibble(song_number = 1:3, bpm = c(70, 100, 130))
  out <- assign_songs_to_playlist(songs, lib, period = "roman")
  expect_equal(nrow(out), 0)
  expect_true(all(c("song_number", "song_title", "artist", "spotify_uri",
                    "soundcloud_url", "bpm", "notes") %in% names(out)))
})
