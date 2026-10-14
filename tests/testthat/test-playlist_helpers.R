# Small helpers behind the playlist table, the plot and the CSV download.

test_that("tempo_feel gives the tempo word without genres", {
  expect_equal(tempo_feel(c(60, 69, 70, 84, 85, 100, 115, 130, 145, 150)),
               c("Glacial", "Glacial", "Slow", "Slow", "Relaxed", "Moderate",
                 "Upbeat", "Energetic", "Intense", "Intense"))
  expect_false(any(grepl("/|Ambient|Pop|Rock", tempo_feel(60:150))))
})

test_that("TEMPO_FEELS lists the same bands as tempo_feel()", {
  for (i in seq_len(nrow(TEMPO_FEELS))) {
    lo <- if (is.na(TEMPO_FEELS$from[i])) 60 else TEMPO_FEELS$from[i]
    hi <- if (is.na(TEMPO_FEELS$to[i])) 150 else TEMPO_FEELS$to[i]
    expect_equal(unique(tempo_feel(lo:hi)), TEMPO_FEELS$feel[i])
  }
})

test_that("playlists carry a feel per song", {
  pl <- generate_playlist(
    list(id = "x", name = "X", years_span = 100, years_per_minute = 10,
         data_source = "icecore", filter_min_age = 0, filter_max_age = 100),
    list(icecore = tibble::tibble(age = 0:100, co2 = seq(180, 280, length.out = 101)))
  )
  expect_equal(pl$songs$feel, tempo_feel(pl$songs$bpm))
})

test_that("song_at_age finds the song whose slice contains an age", {
  songs <- tibble::tibble(song_number = 1:3,                  # oldest first
                          start_age = c(20, 10, 0), end_age = c(30, 20, 10))
  expect_equal(song_at_age(c(0, 5, 10, 19.9, 20, 29, 30), songs),
               c(3L, 3L, 2L, 2L, 1L, 1L, 1L))
  expect_true(all(is.na(song_at_age(1:3, songs[0, ]))))
  # Modern: negative ages (most negative = most recent)
  modern <- tibble::tibble(song_number = 1:2, start_age = c(-40, -75), end_age = c(-8, -40))
  expect_equal(song_at_age(c(-74, -41, -40, -8), modern), c(2L, 2L, 1L, 1L))
})

test_that("hex_to_rgba converts colours", {
  expect_equal(hex_to_rgba("#3b82f6", 0.25), "rgba(59,130,246,0.25)")
  expect_equal(hex_to_rgba(c("#000000", "#ffffff"), 1), c("rgba(0,0,0,1)", "rgba(255,255,255,1)"))
})

test_that("axis_for_period gives a hover format for every timescale", {
  for (p in TIME_PERIODS) expect_match(axis_for_period(p)$hover, "%{x", fixed = TRUE)
})

test_that("the CSV download is the playlist with its songs and links", {
  pl <- list(songs = tibble::tibble(song_number = 1:3, age_range = c("a", "b", "c"),
                                    avg_co2 = c(280, 290, 300), bpm = c(60, 100, 150)))
  picks <- tibble::tibble(song_number = c(1L, 3L), song_title = c("One", "Three"),
                          artist = c("A", "C"), bpm = c(62, 148),
                          spotify_uri = c("spotify:track:abc123", NA),
                          youtube_url = c(NA, "https://youtu.be/dQw4w9WgXcQ"),
                          soundcloud_url = c(NA, ""))
  out <- playlist_export(pl, picks)
  expect_equal(nrow(out), 3)
  expect_equal(out$feel, c("Glacial", "Moderate", "Intense"))
  expect_equal(out$song_title, c("One", NA, "Three"))
  expect_equal(out$song_bpm, c(62, NA, 148))
  expect_equal(out$spotify_url, c("https://open.spotify.com/track/abc123", NA, NA))
  expect_equal(out$youtube_url, c(NA, NA, "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
  expect_true(all(is.na(out$soundcloud_url)))
  # no songs matched at all
  expect_true(all(is.na(playlist_export(pl, NULL)$song_title)))
})
