# "How it works" and "About this era" windows.

test_that("How it works explains the method, matching, shuffle, feel and the makers", {
  skip_if_not_installed("shiny")
  library(shiny)
  stats <- list(num_songs = 23, scale_min = 312, scale_max = 432)
  html <- as.character(how_it_works_content("modern", stats, scaling = "per_period",
                                            global_range = c(174, 1963), n_library = 220))
  html <- gsub("\\s+", " ", html)                     # text as the browser shows it
  expect_match(html, "±5 BPM", fixed = TRUE)
  expect_match(html, "±10 BPM", fixed = TRUE)
  expect_match(html, "Shuffle songs", fixed = TRUE)
  expect_match(html, "oldest slice to the youngest", fixed = TRUE)
  expect_match(html, "Glacial (under 70 BPM)", fixed = TRUE)
  expect_match(html, "220 hand-picked songs", fixed = TRUE)
  expect_match(html, "(174–1,963 ppm)", fixed = TRUE)
  expect_match(html, "23 songs, each standing for about 3 years", fixed = TRUE)
  expect_match(html, "per-era scale", fixed = TRUE)
  expect_match(html, "750,000 years in the Cenozoic", fixed = TRUE)
  for (x in c(APP_STORY, APP_MAKERS)) expect_match(html, htmltools::htmlEscape(x), fixed = TRUE)
  # without an era: no era box, still renders
  expect_no_match(as.character(how_it_works_content()), "In the era you have open", fixed = TRUE)
})

test_that("years_per_song_table follows the period config", {
  t <- years_per_song_table()
  expect_equal(t$id, names(TIME_PERIODS))
  expect_equal(t$years_per_song[t$id == "modern"], 3)
  expect_equal(t$years_per_song[t$id == "cenozoic"], 750000)
})

test_that("About this era shows the story, events and how CO2 was measured", {
  skip_if_not_installed("shiny")
  library(shiny)
  for (pid in names(TIME_PERIODS)) {
    html <- as.character(era_info_content(pid, list(years_span = 1, num_songs = 2,
                                                    co2_min = 3, co2_max = 4)))
    m <- period_measurement(pid)
    expect_match(html, "How the CO₂ was measured", fixed = TRUE)
    expect_match(html, htmltools::htmlEscape(m$title), fixed = TRUE)
    expect_match(html, m$url, fixed = TRUE)
    expect_match(html, "The story", fixed = TRUE)
  }
  expect_match(as.character(era_info_content("roman")), "Law Dome", fixed = TRUE)
  expect_length(era_info_content("nope"), 0)
})
