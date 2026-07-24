test_that("endpoints map to the BPM range", {
  expect_equal(co2_to_bpm(180, 180, 380), 60)
  expect_equal(co2_to_bpm(380, 180, 380), 150)
})

test_that("linear interpolation with rounding", {
  expect_equal(co2_to_bpm(280, 180, 380), 105)  # 60 + 90 * (100/200)
  expect_equal(co2_to_bpm(200, 180, 380), 69)   # 60 + 90 * ( 20/200)
  expect_equal(co2_to_bpm(300, 180, 380), 114)  # 60 + 90 * (120/200)
})

test_that("values outside the range are clamped", {
  expect_equal(co2_to_bpm(50,   180, 380), 60)
  expect_equal(co2_to_bpm(9999, 180, 380), 150)
})

test_that("a zero-width range returns the midpoint BPM", {
  expect_equal(co2_to_bpm(200, 200, 200), 105)  # round((60 + 150) / 2)
})

test_that("the conversion is vectorised", {
  expect_equal(co2_to_bpm(c(180, 280, 380), 180, 380), c(60, 105, 150))
})

test_that("higher CO2 never maps to lower BPM (monotonic)", {
  b <- co2_to_bpm(seq(180, 380, by = 5), 180, 380)
  expect_true(all(diff(b) >= 0))
})
