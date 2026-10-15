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
  # tol 3, 5, 10 -> none; nearest to 118 is 103 (dist 15) < 140 (dist 22)
  w <- pick_song_widening(lib, target_bpm = 118)
  expect_equal(w$song_title, "D")
})

test_that("the widening wrapper prefers a tolerance hit over the nearest fallback", {
  lib <- make_lib()
  set.seed(3)
  w <- pick_song_widening(lib, target_bpm = 100)   # C/D within ±3 (B only within ±5)
  expect_lte(abs(w$bpm - 100), 3)
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

test_that("service_songs: each service only gets its own songs (no mixing)", {
  lib <- tibble::tibble(
    song_title     = c("yt", "sc", "sp", "sp+yt"),
    artist         = "a",
    spotify_uri    = c(NA, NA, "spotify:track:4uLU6hMCjMI75M1A2tKUQC",
                       "spotify:track:4uLU6hMCjMI75M1A2tKUQC"),
    soundcloud_url = c(NA, "https://soundcloud.com/artist/track", NA, NA),
    youtube_url    = c("https://www.youtube.com/watch?v=dQw4w9WgXcQ", NA, NA,
                       "https://youtu.be/qDneDYFM3fk"),
    bpm            = 100,
    notes          = NA
  )
  expect_setequal(service_songs(lib, "spotify")$song_title, c("sp", "sp+yt"))
  expect_setequal(service_songs(lib, "youtube")$song_title, c("yt", "sp+yt"))
  expect_equal(service_songs(lib, "soundcloud")$song_title, "sc")
  # a service without songs gets none - never another service's songs
  expect_equal(nrow(service_songs(lib[3, ], "youtube")), 0)
  expect_equal(nrow(service_songs(lib[0, ], "spotify")), 0)
  expect_error(service_songs(lib, "auto"))
})

test_that("service_songs skips known-blocked YouTube videos", {
  lib <- tibble::tibble(
    song_title = c("ok", "blocked"), artist = "a",
    spotify_uri = NA_character_, soundcloud_url = NA_character_,
    youtube_url = c("https://youtu.be/dQw4w9WgXcQ", "https://youtu.be/qDneDYFM3fk"),
    bpm = 100, notes = NA
  )
  expect_equal(service_songs(lib, "youtube", bad_youtube = "qDneDYFM3fk")$song_title, "ok")
})

test_that("spotify_songs keeps only songs with a Spotify track id", {
  lib <- tibble::tibble(
    song_title = c("sp", "yt"), artist = "a",
    spotify_uri = c("https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC", NA),
    soundcloud_url = NA_character_,
    youtube_url = c(NA, "https://youtu.be/dQw4w9WgXcQ"),
    bpm = 100, notes = NA
  )
  expect_equal(spotify_songs(lib)$song_title, "sp")
})

test_that("the widening matcher reports how it found the song", {
  lib <- make_lib()
  set.seed(1)
  w <- pick_song_widening(lib, target_bpm = 100)        # C (100) and D (103) within ±3
  expect_equal(w$match_tol, 3)
  expect_equal(w$n_candidates, 2)

  w <- pick_song_widening(lib, target_bpm = 107)        # none within ±3, D (103) within ±5
  expect_equal(w$match_tol, 5)
  expect_equal(w$n_candidates, 1)
  expect_equal(w$song_title, "D")

  w <- pick_song_widening(lib, target_bpm = 110)        # C (100) and D (103) within ±10
  expect_equal(w$match_tol, 10)
  expect_equal(w$n_candidates, 2)

  w <- pick_song_widening(lib, target_bpm = 118)        # nothing within ±10 -> nearest
  expect_true(is.na(w$match_tol))
  expect_equal(w$song_title, "D")

  # used titles don't count as candidates
  w <- pick_song_widening(lib, target_bpm = 100, exclude = c("B", "C"))
  expect_equal(w$n_candidates, 1)
})

test_that("reporting the match doesn't change which song is picked", {
  lib <- make_lib()
  set.seed(7); a <- pick_song_for_bpm(lib, target_bpm = 100, tol = MATCH_TOLS[1])
  set.seed(7); b <- pick_song_widening(lib, target_bpm = 100)
  expect_equal(a$song_title, b$song_title)
})

test_that("assign_songs_to_playlist carries the match info", {
  lib   <- make_lib()
  songs <- tibble::tibble(song_number = 1:3, bpm = c(60, 100, 118))
  out <- assign_songs_to_playlist(songs, lib, period = "roman")
  expect_true(all(c("match_tol", "n_candidates") %in% names(out)))
  expect_equal(out$match_tol[out$song_number == 1], 3)   # 60 BPM: A is on target
  expect_type(out$n_candidates, "integer")
})

test_that("match_explanation says how far off the song is and how it was chosen", {
  expect_equal(match_explanation(66, 63, 5, 8),
               "+3 BPM from the target · picked at random from 8 songs within ±5 BPM")
  expect_equal(match_explanation(73, 73, 5, 21),
               "exactly on target · picked at random from 21 songs within ±5 BPM")
  expect_match(match_explanation(95, 100, 10, 1),
               "−5 BPM from the target · the only unused song within ±10 BPM", fixed = TRUE)
  expect_match(match_explanation(80, 66, NA, 1), "closest one was taken", fixed = TRUE)
  expect_equal(match_explanation(66, 64, 3, 6),
               "+2 BPM from the target · picked at random from 6 songs within ±3 BPM")
  expect_match(match_explanation(80, 66, NA, 1),
               "no unused song within ±10 BPM was left", fixed = TRUE)   # the widest window
})

test_that("the matcher tries ±3, then ±5, then ±10 BPM, then the nearest song", {
  expect_equal(MATCH_TOLS, c(3, 5, 10))
  expect_identical(formals(pick_song_widening)$tols, quote(MATCH_TOLS))
  expect_identical(formals(assign_songs_to_playlist)$tols, quote(MATCH_TOLS))

  lib <- tibble::tibble(song_title = c("near", "mid", "far"), artist = "x",
                        spotify_uri = "", soundcloud_url = "",
                        bpm = c(103, 105, 110), notes = "")
  set.seed(1)
  w <- pick_song_widening(lib, target_bpm = 100)          # +3 beats +5: ±3 comes first
  expect_equal(w$song_title, "near")
  expect_equal(w$match_tol, 3)
  w <- pick_song_widening(lib, target_bpm = 100, exclude = "near")
  expect_equal(w$song_title, "mid")
  expect_equal(w$match_tol, 5)
  w <- pick_song_widening(lib, target_bpm = 100, exclude = c("near", "mid"))
  expect_equal(w$song_title, "far")
  expect_equal(w$match_tol, 10)
  # the old ladder (±5 first) drew from 'near' and 'mid' alike
  expect_equal(pick_song_widening(lib, target_bpm = 100, tols = c(5, 10))$n_candidates, 2)
})

test_that("a song within ±3 BPM is always preferred, for every shuffle", {
  lib <- tibble::tibble(song_title = paste("S", 1:6), artist = "x",
                        spotify_uri = "", soundcloud_url = "",
                        bpm = c(81, 85, 101, 105, 121, 125), notes = "")
  slots <- tibble::tibble(song_number = 1:3, bpm = c(80, 100, 120))
  for (sh in 0:4) {
    out <- assign_songs_to_playlist(slots, lib, period = "modern", shuffle_counter = sh)
    expect_equal(out$bpm, c(81, 101, 121))
    expect_equal(out$match_tol, c(3, 3, 3))
  }
})
