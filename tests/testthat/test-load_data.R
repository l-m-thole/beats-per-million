test_that("load_rae2021_data returns clean age/co2 in years", {
  candidates <- c(
    file.path("..", "..", "data", "rawData", "rae2021co2.xlsx"),
    file.path("data", "rawData", "rae2021co2.xlsx")
  )
  f <- candidates[file.exists(candidates)][1]
  skip_if(is.na(f), "rae2021co2.xlsx not available")

  d <- load_rae2021_data(f)
  expect_true(all(c("age", "co2") %in% names(d)))
  expect_false(any(is.na(d$co2)))
  expect_true(all(diff(d$age) >= 0))             # sorted ascending
  expect_gt(max(d$age), 6e7)                     # ages in years (~66 Ma)
  expect_true(all(d$co2 > 100 & d$co2 < 3000))   # plausible ppm
})

test_that("validate_co2_data rejects a dataset missing 'co2'", {
  bad <- list(icecore = data.frame(age = 1:3))
  expect_error(validate_co2_data(bad), "co2")
})
