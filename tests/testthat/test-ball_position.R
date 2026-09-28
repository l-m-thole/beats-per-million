# Tests for ball_position(): the "now playing" marker on the CO2 curve.

raw <- tibble::tibble(age = c(0, 100, 200), co2 = c(200, 300, 400))
song <- tibble::tibble(start_age = 100, end_age = 200, avg_co2 = 350)

test_that("the ball starts at the OLDER edge and ends at the younger edge", {
  expect_equal(ball_position(song, raw, 0)$age, 200)
  expect_equal(ball_position(song, raw, 1)$age, 100)
  expect_equal(ball_position(song, raw, 0.5)$age, 150)
})

test_that("the ball rides on the curve (interpolated CO2)", {
  expect_equal(ball_position(song, raw, 0)$co2, 400)
  expect_equal(ball_position(song, raw, 0.5)$co2, 350)
  expect_equal(ball_position(song, raw, 1)$co2, 300)
})

test_that("progress is clamped and NA-safe", {
  expect_equal(ball_position(song, raw, -1)$age, 200)
  expect_equal(ball_position(song, raw, 5)$age, 100)
  expect_equal(ball_position(song, raw, NA)$age, 200)
  expect_equal(ball_position(song, raw, NULL)$age, 200)
})

test_that("modern (negative) ages still run past -> present", {
  modern_song <- tibble::tibble(start_age = -75, end_age = -60, avg_co2 = 420)
  expect_equal(ball_position(modern_song, raw, 0)$age, -60)   # older year
  expect_equal(ball_position(modern_song, raw, 1)$age, -75)   # younger year
})

test_that("too little data falls back to the window average", {
  expect_equal(ball_position(song, raw[1, ], 0.5)$co2, 350)
})

test_that("playable_songs keeps only rows with a BPM and a usable link", {
  lib <- tibble::tibble(
    song_title     = c("sp", "sc", "nolink", "nobpm", "badsp"),
    artist         = "x",
    spotify_uri    = c("spotify:track:abc123", NA, "", "spotify:track:def", "not a uri!"),
    soundcloud_url = c(NA, "https://soundcloud.com/a/b", NA, NA, ""),
    bpm            = c(100, 110, 120, NA, 90),
    notes          = ""
  )
  expect_equal(playable_songs(lib)$song_title, c("sp", "sc"))
  expect_equal(nrow(playable_songs(lib[0, ])), 0)
})
