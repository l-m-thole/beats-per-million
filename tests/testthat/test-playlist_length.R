# Playlist length: Standard or Long (every time slice cut in two).

ice_period <- function() {
  list(id = "x", name = "X", years_span = 2000, years_per_minute = 20,
       data_source = "icecore", filter_min_age = 0, filter_max_age = 2000)
}
ice_data <- function() {
  list(icecore = tibble::tibble(age = seq(0, 2000, by = 5),
                                co2 = 275 + 10 * sin(seq(0, 2000, by = 5) / 300)))
}
modern_data <- function() {
  t <- seq(1958.2, 2026.7, by = 1 / 12)
  list(modern = tibble::tibble(age = REFERENCE_YEAR - t, co2 = 315 + 0.012 * (t - 1958)^2))
}

test_that("the lengths are Standard (1 song per slice) and Long (2)", {
  expect_equal(PLAYLIST_LENGTHS, c(standard = 1, long = 2))
})

test_that("Long has exactly twice the songs, each for half as many years", {
  std  <- generate_playlist(ice_period(), ice_data())
  long <- generate_playlist(ice_period(), ice_data(), length_factor = 2)
  expect_equal(std$stats$num_songs, ceiling(2000 / 20 / AVG_SONG_LENGTH))
  expect_equal(nrow(long$songs), 2 * nrow(std$songs))
  expect_equal(long$stats$num_songs, 2 * std$stats$num_songs)
  expect_equal(long$stats$length_factor, 2)
  expect_equal(std$stats$length_factor, 1)
  expect_equal(long$stats$years_per_minute, std$stats$years_per_minute / 2)
  expect_equal(long$stats$playlist_minutes, 2 * std$stats$playlist_minutes)
  # same record, same span, same BPM scale
  expect_equal(long$stats$years_span, std$stats$years_span)
  expect_equal(c(long$stats$scale_min, long$stats$scale_max),
               c(std$stats$scale_min, std$stats$scale_max))
  expect_equal(long$songs$song_number, seq_len(nrow(long$songs)))
})

test_that("Long slices line up with the standard ones (songs 2k-1 + 2k = song k)", {
  for (case in list(list(per = ice_period(), data = ice_data()),
                    list(per = TIME_PERIODS$modern, data = modern_data()))) {
    std  <- generate_playlist(case$per, case$data)$songs
    long <- generate_playlist(case$per, case$data, length_factor = 2)$songs
    k <- seq_len(nrow(std))
    expect_equal(long$end_age[2 * k - 1], std$end_age, tolerance = 1e-9)     # older edge
    expect_equal(long$start_age[2 * k], std$start_age, tolerance = 1e-9)     # younger edge
    expect_equal(long$start_age[2 * k - 1], long$end_age[2 * k], tolerance = 1e-9)
    # still oldest -> youngest
    expect_true(all(diff(long$end_age) < 0))
  }
})

test_that("Standard is unchanged by the new argument", {
  expect_identical(generate_playlist(ice_period(), ice_data()),
                   generate_playlist(ice_period(), ice_data(), length_factor = 1))
  invisible(utils::capture.output({
    a <- generate_all_playlists(ice_data(), period_ids = "roman")
    b <- generate_all_playlists(ice_data(), period_ids = "roman", length_factor = 2)
  }))
  expect_equal(nrow(b$roman$songs), 2 * nrow(a$roman$songs))
})

test_that("only whole length factors are allowed", {
  for (bad in list(1.5, 0, NA, c(1, 2))) {
    expect_error(generate_playlist(ice_period(), ice_data(), length_factor = bad),
                 "whole number")
  }
})

test_that("the CSV name says which length was downloaded", {
  expect_equal(playlist_csv_name("modern", "standard", as.Date("2026-10-27")),
               "playlist_modern_2026-10-27.csv")
  expect_equal(playlist_csv_name("modern", "long", as.Date("2026-10-27")),
               "playlist_modern_long_2026-10-27.csv")
})

test_that("How it works and About this era use the long numbers", {
  skip_if_not_installed("shiny")
  library(shiny)
  long <- list(num_songs = 46, scale_min = 312, scale_max = 432, length_factor = 2,
               years_span = 68, co2_min = 312, co2_max = 432)
  html <- gsub("\\s+", " ", as.character(how_it_works_content("modern", long)))
  expect_match(html, "46 songs (long playlist), each standing for about 1.5 years", fixed = TRUE)
  expect_match(html, "Playlist length: Long", fixed = TRUE)
  expect_match(html, "twice the songs", fixed = TRUE)
  expect_match(html, "preferring songs that move with the curve", fixed = TRUE)
  info <- gsub("\\s+", " ", as.character(era_info_content("modern", long)))
  expect_match(info, "1.5 years", fixed = TRUE)
  expect_equal(years_per_song_of(TIME_PERIODS$cenozoic, long), 375000)
  expect_equal(years_per_song_of(TIME_PERIODS$modern), 3)
  expect_equal(.years_txt(1.5), "1.5 years")
  expect_equal(.years_txt(3), "3 years")
  expect_equal(.years_txt(750000), "750,000 years")
  expect_equal(.years_txt(1), "1 year")
})

test_that("the library check can simulate the Long playlists", {
  pool <- tibble::tibble(song_title = paste("S", 1:182), artist = "x",
                         spotify_uri = "", soundcloud_url = "", youtube_url = "",
                         bpm = rep(60:150, each = 2), notes = "")
  pls <- list(long = list(x = generate_playlist(ice_period(), ice_data(), length_factor = 2)))
  cov <- library_coverage(pls, list(spotify = pool), shuffles = 0:1)
  expect_equal(unique(cov$mode), "long")
  expect_equal(nrow(cov), 2 * ceiling(2000 / 20 / AVG_SONG_LENGTH))
  summ <- coverage_summary(cov)
  expect_equal(summ$slots, nrow(cov))
  gaps <- library_gaps(cov, list(spotify = pool), modes = "long")
  expect_true(all(c("bin", "add_at_least") %in% names(gaps)))
})
