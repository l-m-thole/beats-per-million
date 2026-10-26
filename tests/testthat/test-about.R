# About & privacy window: content renders, cites the data, keeps the backlink.

test_that("About text renders with citations, backlink and privacy notes", {
  skip_if_not_installed("shiny")
  library(shiny)
  html <- as.character(about_content(list(contact = "me@example.org")))
  expect_match(html, "doi.org/10.1002/2014GL061957", fixed = TRUE)            # Bereiter 2015
  expect_match(html, "doi.org/10.1146/annurev-earth-082420-063026", fixed = TRUE)  # Rae 2021
  expect_match(html, "gml.noaa.gov/ccgg/trends", fixed = TRUE)
  expect_match(html, "https://getsongbpm.com", fixed = TRUE)
  expect_match(html, "Privacy", fixed = TRUE)
  expect_match(html, "mailto:me@example.org", fixed = TRUE)
  expect_match(html, "logged in to Spotify in this browser", fixed = TRUE)   # whole songs need a login
  expect_no_match(as.character(about_content(list(contact = ""))), "mailto:")
})

test_that("Privacy: players only after Play, YouTube's required lines, rights", {
  skip_if_not_installed("shiny")
  library(shiny)
  html <- as.character(about_content(list(contact = "me@example.org")))
  expect_match(html, if (isTRUE(SHOW_SOUNDCLOUD)) "Nothing from Spotify, YouTube (Google) or SoundCloud loads until"
                     else "Nothing from Spotify or YouTube (Google) loads until", fixed = TRUE)
  expect_match(html, "YouTube API Services", fixed = TRUE)          # YouTube policy III.A.2
  expect_match(html, YOUTUBE_TERMS_URL, fixed = TRUE)              # III.A.1
  expect_match(html, GOOGLE_PRIVACY_URL, fixed = TRUE)
  expect_match(html, "imy.se", fixed = TRUE)                        # right to complain
  expect_match(html, "one service per playlist", fixed = TRUE)
  expect_no_match(html, "Google Fonts", fixed = TRUE)               # fonts are self-hosted now
})

test_that("the Play gate says who gets what before any player loads", {
  skip_if_not_installed("shiny")
  library(shiny)
  yt <- as.character(player_gate("youtube"))
  expect_match(yt, "▶ Play via YouTube", fixed = TRUE)
  expect_match(yt, 'data-service="youtube"', fixed = TRUE)
  expect_match(yt, "Google then gets your IP address", fixed = TRUE)
  expect_match(yt, YOUTUBE_TERMS_URL, fixed = TRUE)
  expect_match(yt, GOOGLE_PRIVACY_URL, fixed = TRUE)
  expect_match(yt, 'id="about_gate"', fixed = TRUE)

  sp <- as.character(player_gate("spotify"))
  expect_match(sp, "▶ Play via Spotify", fixed = TRUE)
  expect_match(sp, "spotify.com/legal/privacy-policy", fixed = TRUE)
  expect_no_match(sp, "youtube", fixed = TRUE)
  expect_match(sp, "Whole songs need a Spotify login in this browser", fixed = TRUE)
  expect_no_match(yt, "Spotify login", fixed = TRUE)

  expect_null(player_gate("winamp"))
})

test_that("Suggest a song: the link, plus the tempos the library is short of", {
  skip_if_not_installed("shiny")
  library(shiny)
  me <- list(contact = "me@example.org")
  wanted <- tibble::tibble(lo = c(60, 140), hi = c(69, 150), add = c(3L, 1L))

  html <- as.character(about_content(me, wanted = wanted))
  expect_match(html, "<h4>Suggest a song</h4>", fixed = TRUE)
  expect_match(html, "mailto:me@example.org?subject=Song%20suggestion", fixed = TRUE)
  expect_match(html, "60–69 BPM (slow), 140–150 BPM (fast)</b>.", fixed = TRUE)

  covered <- as.character(about_content(me, wanted = wanted[0, ]))
  expect_match(covered, "Every tempo is covered", fixed = TRUE)

  unknown <- as.character(about_content(me))                  # no data/wanted_bpm.csv yet
  expect_match(unknown, "Suggest a song", fixed = TRUE)
  expect_no_match(unknown, "short of songs", fixed = TRUE)
  expect_no_match(unknown, "Every tempo", fixed = TRUE)

  expect_no_match(as.character(about_content(list(contact = ""))), "Suggest a song", fixed = TRUE)
})

test_that("Modern data end date comes from the last data point", {
  modern <- tibble::tibble(year = c(1958, 2024), age = c(-8.2, -74.875), co2 = c(316, 424))
  expect_equal(modern_data_through(modern), "November 2024")
  expect_null(modern_data_through(NULL))
})

test_that("SHOW_SOUNDCLOUD hides SoundCloud in About & privacy", {
  skip_if_not_installed("shiny")
  library(shiny)
  old <- SHOW_SOUNDCLOUD
  on.exit(assign("SHOW_SOUNDCLOUD", old, envir = globalenv()))
  assign("SHOW_SOUNDCLOUD", FALSE, envir = globalenv())
  expect_false(grepl("SoundCloud", as.character(about_content(list(contact = "me@example.org")))))
  assign("SHOW_SOUNDCLOUD", TRUE, envir = globalenv())
  expect_match(as.character(about_content(list(contact = "me@example.org"))), "SoundCloud", fixed = TRUE)
})
