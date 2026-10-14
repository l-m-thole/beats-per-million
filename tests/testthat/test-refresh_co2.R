# Mauna Loa refresh: reading NOAA's file, sanity checks, replace only on change.
# Offline: the download is faked.

mlo_rows <- function(to_year = 2024, to_month = 11) {
  ym <- expand.grid(month = 1:12, year = 1958:to_year)[, c("year", "month")]
  ym <- ym[!(ym$year == 1958 & ym$month < 3) & !(ym$year == to_year & ym$month > to_month), ]
  tibble::tibble(year = ym$year, month = ym$month,
                 decimal_date = ym$year + (ym$month - 0.5) / 12,
                 co2 = round(315 + seq_len(nrow(ym)) * 0.14, 2))
}

write_mlo <- function(path, rows, stamp = "2026-10-01") {
  writeLines(c(paste("# File Creation:", stamp),
               "# NOAA header lines start with #",
               "year,month,decimal date,average,deseasonalized,ndays,sdev,unc",
               sprintf("%d,%d,%.4f,%.2f,%.2f,20,0.30,0.10", rows$year, rows$month,
                       rows$decimal_date, rows$co2, rows$co2)),
             path)
  invisible(path)
}

test_that("NOAA's file is read into the columns the app uses", {
  path <- withr::local_tempfile(fileext = ".csv")
  write_mlo(path, mlo_rows())
  x <- read_maunaloa_raw(path)
  expect_named(x, c("year", "month", "decimal_date", "co2"))
  expect_equal(nrow(x), nrow(mlo_rows()))
  expect_equal(x$year[1], 1958L)

  writeLines(c("year,month,value", "1958,3,315"), path)
  expect_error(read_maunaloa_raw(path), "missing column")
})

test_that("a good update is accepted and summarised", {
  old <- mlo_rows(2024, 11)
  chk <- check_maunaloa_update(mlo_rows(2026, 9), old)
  expect_true(chk$ok)
  expect_true(chk$changed)
  expect_equal(chk$new_months, 22L)
  expect_equal(chk$through, "September 2026")
  expect_equal(chk$was, "November 2024")

  same <- check_maunaloa_update(old, old)
  expect_true(same$ok)
  expect_false(same$changed)

  gap <- old
  gap$co2[5] <- -99.99                                # NOAA's "no data" month
  expect_true(check_maunaloa_update(gap, gap)$ok)
})

test_that("small revisions pass; broken downloads are refused", {
  old <- mlo_rows(2024, 11)
  rev <- old
  rev$co2[nrow(rev)] <- rev$co2[nrow(rev)] + 0.2
  chk <- check_maunaloa_update(rev, old)
  expect_true(chk$ok)
  expect_equal(chk$revised, 1L)
  expect_true(chk$changed)

  problems <- function(new) paste(check_maunaloa_update(new, old)$problems, collapse = " | ")
  expect_match(problems(old[1:100, ]), "only 100 rows")
  expect_match(problems(old[1:100, ]), "ends earlier")
  big <- old
  big$co2[10] <- big$co2[10] + 5
  expect_match(problems(big), "changed by more than")
  odd <- old
  odd$co2[20] <- 900
  expect_match(problems(odd), "outside")
  expect_match(problems(old[nrow(old):1, ]), "not in order")
  late <- old[old$year > 1960, ]
  expect_match(problems(late), "doesn't start in 1958")
})

test_that("download_maunaloa replaces the file only when the numbers changed", {
  dir  <- withr::local_tempdir()
  dest <- write_mlo(file.path(dir, "co2_mm_mlo.csv"), mlo_rows(2024, 11))
  fake <- function(src) function(url, path) file.copy(src, path, overwrite = TRUE)

  newer <- write_mlo(file.path(dir, "newer.csv"), mlo_rows(2026, 9))
  chk <- download_maunaloa(dest, fetch = fake(newer))
  expect_true(chk$changed)
  expect_equal(nrow(read_maunaloa_raw(dest)), nrow(mlo_rows(2026, 9)))

  # same numbers, only a new date stamp in the header: file left alone
  before <- readLines(dest)
  restamp <- write_mlo(file.path(dir, "restamp.csv"), mlo_rows(2026, 9), stamp = "2026-11-01")
  expect_false(download_maunaloa(dest, fetch = fake(restamp))$changed)
  expect_identical(readLines(dest), before)

  # a broken download is refused and the current file kept
  broken <- write_mlo(file.path(dir, "broken.csv"), mlo_rows(1960, 1))
  expect_error(download_maunaloa(dest, fetch = fake(broken)), "Kept the current file")
  expect_identical(readLines(dest), before)

  # no network / NOAA moved the file: a clear message, file kept
  expect_error(download_maunaloa(dest, fetch = function(url, path) stop("timeout")),
               "Could not download")
  expect_identical(readLines(dest), before)
})
