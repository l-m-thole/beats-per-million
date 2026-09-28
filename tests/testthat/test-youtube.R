# YouTube link parsing + playability

test_that("parse_youtube_id handles the common URL shapes", {
  id <- "dQw4w9WgXcQ"
  expect_equal(parse_youtube_id(paste0("https://www.youtube.com/watch?v=", id)), id)
  expect_equal(parse_youtube_id(paste0("https://www.youtube.com/watch?list=x&v=", id, "&t=3")), id)
  expect_equal(parse_youtube_id(paste0("https://music.youtube.com/watch?v=", id, "&si=abc")), id)
  expect_equal(parse_youtube_id(paste0("https://youtu.be/", id, "?si=abc")), id)
  expect_equal(parse_youtube_id(paste0("https://www.youtube.com/embed/", id)), id)
  expect_equal(parse_youtube_id(paste0("https://www.youtube.com/shorts/", id)), id)
  expect_equal(parse_youtube_id(id), id)
  expect_true(is.na(parse_youtube_id("")))
  expect_true(is.na(parse_youtube_id(NA)))
  expect_true(is.na(parse_youtube_id(NULL)))
  expect_true(is.na(parse_youtube_id("https://example.com/video")))
})

test_that("a song with only a YouTube link is playable", {
  lib <- tibble::tibble(
    song_title = c("yt", "none"), artist = "x",
    spotify_uri = NA_character_, soundcloud_url = NA_character_,
    youtube_url = c("https://youtu.be/dQw4w9WgXcQ", NA),
    bpm = c(100, 100), notes = ""
  )
  expect_equal(playable_songs(lib)$song_title, "yt")
})

test_that("matched picks carry the youtube_url through", {
  lib <- tibble::tibble(
    song_title = "yt", artist = "x", spotify_uri = NA_character_,
    soundcloud_url = NA_character_, youtube_url = "https://youtu.be/dQw4w9WgXcQ",
    bpm = 100, notes = ""
  )
  picks <- assign_songs_to_playlist(tibble::tibble(song_number = 1L, bpm = 100),
                                    lib, period = "p")
  expect_equal(picks$youtube_url, "https://youtu.be/dQw4w9WgXcQ")
})
