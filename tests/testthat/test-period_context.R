# Tests for the period context text and key-event timeline (R/period_context.R)

test_that("every period has context text and key events", {
  for (id in names(TIME_PERIODS)) {
    expect_true(length(period_context_text(id)) >= 1, info = id)
    expect_true(nrow(period_key_events(id)) >= 3, info = id)
  }
})

test_that("key events have all fields filled in", {
  for (id in names(TIME_PERIODS)) {
    ev <- period_key_events(id)
    expect_named(ev, c("age", "when", "title", "detail"))
    expect_false(anyNA(ev$age), info = id)
    expect_true(all(nzchar(ev$when) & nzchar(ev$title) & nzchar(ev$detail)), info = id)
  }
})

test_that("key events fall inside their period's age window", {
  for (id in names(TIME_PERIODS)) {
    per <- TIME_PERIODS[[id]]
    ev  <- period_key_events(id)
    if (id == "modern") {
      # years 1958-present -> ages from 1950 - 1958 = -8 down to "now"
      expect_true(all(ev$age <= REFERENCE_YEAR - 1958), info = id)
      expect_true(all(ev$age >= REFERENCE_YEAR - as.numeric(format(Sys.Date(), "%Y"))), info = id)
    } else {
      expect_true(all(ev$age >= per$filter_min_age & ev$age <= per$filter_max_age), info = id)
    }
  }
})

test_that("events are ordered oldest -> youngest (playback order)", {
  for (id in names(TIME_PERIODS)) {
    expect_false(is.unsorted(rev(period_key_events(id)$age)), info = id)
  }
})

test_that("modern events convert CE years to (negative) ages", {
  ev <- period_key_events("modern")
  expect_equal(ev$age[ev$when == "2015"], REFERENCE_YEAR - 2015)
})

test_that("events_in_window finds events regardless of age order", {
  # Younger Dryas starts ~12,900 years ago
  a <- events_in_window("lgm", 12000, 13000)
  b <- events_in_window("lgm", 13000, 12000)
  expect_true("Younger Dryas" %in% a$title)
  expect_equal(a, b)
  expect_equal(nrow(events_in_window("lgm", 1, 2)), 0)
  # Modern: negative ages (2015 CE = -65)
  expect_true("Paris Agreement" %in% events_in_window("modern", -66, -64)$title)
})

test_that("unknown periods return empty results, not errors", {
  expect_equal(nrow(period_key_events("nope")), 0)
  expect_length(period_context_text("nope"), 0)
})
