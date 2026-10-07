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
  expect_no_match(as.character(about_content(list(contact = ""))), "mailto:")
})

test_that("Modern data end date comes from the last data point", {
  modern <- tibble::tibble(year = c(1958, 2024), age = c(-8.2, -74.875), co2 = c(316, 424))
  expect_equal(modern_data_through(modern), "November 2024")
  expect_null(modern_data_through(NULL))
})
