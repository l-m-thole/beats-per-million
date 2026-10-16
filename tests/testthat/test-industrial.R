# Industrial era (1850-today): CMIP7 historical CO2 + Mauna Loa after 2022.
# Splice logic (R/refresh_co2.R), playlist on a calendar-year axis, texts.

cmip_rows <- function(from = 1750, to = 2022) {
  tibble::tibble(year = from:to, co2 = 278 + pmax(0, (from:to) - 1800)^2 / 400)
}
mlo_monthly <- function(years, offset = 1.2, cmip = cmip_rows(1750, max(years))) {
  ym <- expand.grid(month = 1:12, year = years)[, c("year", "month")]
  base <- cmip$co2[match(ym$year, cmip$year)]
  base[is.na(base)] <- max(cmip$co2) + (ym$year[is.na(base)] - max(cmip$year)) * 2.5
  tibble::tibble(year = ym$year, month = ym$month,
                 decimal_date = ym$year + (ym$month - 0.5) / 12,
                 co2 = base + offset + sin(ym$month / 12 * 2 * pi) * 3)   # seasonal cycle
}

test_that("CMIP7 file is read into year + co2, sorted", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("year,co2_ppm", "1751,278.1", "1750,278.0"), path)
  x <- read_cmip7_raw(path)
  expect_named(x, c("year", "co2"))
  expect_equal(x$year, c(1750L, 1751L))
  writeLines(c("year,ppm", "1750,278"), path)
  expect_error(read_cmip7_raw(path), "co2_ppm")
})

test_that("Mauna Loa extends CMIP7, shifted by the overlap offset", {
  cmip <- cmip_rows()
  mlo  <- mlo_monthly(1959:2025, offset = 1.2, cmip = cmip)
  sp <- splice_cmip7_maunaloa(cmip, mlo, start_year = 1850, overlap_years = 10)

  expect_equal(sp$offset, 1.2, tolerance = 1e-9)
  expect_equal(sp$overlap, c(2013, 2022))
  expect_equal(sp$last_cmip, 2022L)
  expect_equal(range(sp$data$year), c(1850, 2025))
  expect_equal(nrow(sp$data), 2025 - 1850 + 1)                # one value per year, no gap
  expect_equal(sp$data$source[sp$data$year <= 2022], rep("CMIP7", 2022 - 1850 + 1))
  expect_equal(unique(sp$data$source[sp$data$year > 2022]), "Mauna Loa (adjusted)")
  expect_equal(sp$data$co2[sp$data$year == 2010], cmip$co2[cmip$year == 2010])
  # no step at the join: 2023 sits on the trend
  y <- sp$data$co2[sp$data$year %in% 2022:2023]
  expect_equal(diff(y), 2.5, tolerance = 1e-6)
  # ages: years before 1950 at the start of each year
  expect_equal(sp$data$age, REFERENCE_YEAR - sp$data$year)
  expect_false(is.unsorted(sp$data$year))
})

test_that("the running Mauna Loa year waits until it is complete", {
  cmip <- cmip_rows()
  mlo  <- mlo_monthly(1959:2026, cmip = cmip)
  mlo  <- mlo[!(mlo$year == 2026 & mlo$month > 9), ]           # data through September
  mlo$co2[mlo$year == 2024 & mlo$month == 5] <- -99.99         # NOAA fill value
  sp <- splice_cmip7_maunaloa(cmip, mlo)
  expect_equal(sp$last_year, 2025L)
  expect_true(2024 %in% sp$data$year)                           # one missing month: kept
  expect_false(any(sp$data$co2 < 0))
})

test_that("no shared year is an error", {
  expect_error(splice_cmip7_maunaloa(cmip_rows(1750, 1900), mlo_monthly(1959:1965)),
               "share no complete year")
})

test_that("Industrial era is configured as a calendar-year era from 1850", {
  per <- get_period("industrial")
  expect_equal(per$data_source, DATA_SOURCE_CMIP7)
  expect_true(is_calendar_source(per$data_source))
  expect_true(is_calendar_source("modern"))
  expect_false(is_calendar_source("icecore"))
  expect_equal(per$filter_max_age, REFERENCE_YEAR - 1850)
  expect_equal(names(TIME_PERIODS)[1:3], c("modern", "industrial", "roman"))
  ax <- axis_for_period(per)
  expect_equal(ax$title, "Year (CE)")
  expect_equal(ax$scale(-75), 2025)
  expect_false(ax$reversed)
})

test_that("Industrial playlist runs 1850 -> last year in CE, tempo rising", {
  cmip <- splice_cmip7_maunaloa(cmip_rows(), mlo_monthly(1959:2025))$data
  # a pre-1850 row must be dropped by the era's age bound
  cmip <- rbind(tibble::tibble(year = 1800, decimal_date = 1800, age = 150, co2 = 200,
                               source = "CMIP7"), cmip)
  pl <- generate_playlist(get_period("industrial"), list(cmip7 = cmip))
  s <- pl$songs
  expect_equal(pl$stats$years_span, 175)
  expect_equal(pl$stats$num_songs, ceiling(175 / 2.5 / AVG_SONG_LENGTH))
  expect_equal(pl$stats$co2_min, round(min(cmip$co2[cmip$year >= 1850])))
  expect_equal(s$display_start[1], "1850 CE")
  expect_equal(s$display_end[nrow(s)], "2025 CE")
  expect_false(is.unsorted(s$bpm))                               # monotonic test data
  expect_equal(max(s$bpm), max(s$bpm[nrow(s)]))
  expect_false(anyNA(s$avg_co2))
  # 1850 itself is in song 1 (the oldest window keeps its edge point)
  one <- cmip[cmip$year >= 1850 & cmip$age >= s$start_age[1], ]
  expect_equal(s$avg_co2[1], round(mean(one$co2)))
})

test_that("real data: the cmip7 sheet loads and makes a playlist", {
  candidates <- c(file.path("..", "..", "data"), "data")
  d <- candidates[file.exists(file.path(candidates, "co2_data.xlsx"))][1]
  skip_if(is.na(d), "co2_data.xlsx not available")
  skip_if_not("cmip7" %in% readxl::excel_sheets(file.path(d, "co2_data.xlsx")))
  co2 <- suppressMessages(capture.output(x <- load_co2_data(d)))
  expect_true("cmip7" %in% names(x))
  expect_equal(min(x$cmip7$year), 1850)
  expect_gte(max(x$cmip7$year), 2025)
  expect_equal(x$cmip7$year_ce, x$cmip7$year)
  expect_true(all(x$cmip7$co2 > 280 & x$cmip7$co2 < 600))
  expect_false(any(diff(x$cmip7$year[order(x$cmip7$year)]) != 1))   # no missing year
  pl <- generate_playlist(get_period("industrial"), x)
  expect_gte(pl$stats$num_songs, 20)
  expect_equal(pl$songs$display_start[1], "1850 CE")
})

test_that("measurement box and About name the CMIP7 source", {
  m <- period_measurement("industrial")
  expect_match(m$title, "climate models")
  expect_match(m$url, "zenodo.14892947")
  expect_null(m$note)
  html <- as.character(about_content(co2_data = list(cmip7 = tibble::tibble(year = 1850:2025))))
  expect_match(html, "Industrial \\(1850–2025\\)")
  expect_match(html, "CR-CMIP-1-0-0")
  expect_equal(industrial_data_through(NULL), NULL)
})
