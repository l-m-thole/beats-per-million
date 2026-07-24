test_that("recent ages become CE years", {
  expect_equal(format_age(-8),  "1958 CE")   # 1950 - (-8)
  expect_equal(format_age(0),   "1950 CE")
  expect_equal(format_age(100), "1850 CE")
})

test_that("sub-millennial ages are plain years BP", {
  expect_equal(format_age(299), "299 BP")
  expect_equal(format_age(500), "500 BP")
})

test_that("thousands use adaptive precision so neighbours stay distinct", {
  expect_equal(format_age(20000),  "20.0k BP")
  expect_equal(format_age(19701),  "19.7k BP")
  expect_equal(format_age(1941),   "1.94k BP")
  expect_equal(format_age(800000), "800k BP")
})

test_that("millions of years format as Ma", {
  expect_equal(format_age(66000000), "66.0 Ma")
  expect_equal(format_age(2250000),  "2.25 Ma")
})

test_that("adjacent tight windows never collide", {
  expect_false(format_age(20000) == format_age(19701))
})

test_that("format_age is vectorised", {
  expect_equal(format_age(c(-8, 20000)), c("1958 CE", "20.0k BP"))
})
