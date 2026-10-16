# =============================================================================
# MAUNA LOA REFRESH - fetch NOAA's newest monthly CO2 file, check it, keep it
# =============================================================================
#
#   read_maunaloa_raw()      NOAA's co2_mm_mlo.csv -> year, month, decimal_date, co2
#   check_maunaloa_update()  is a new file sane, and what does it add?
#   download_maunaloa()      fetch -> check -> replace data/rawData/co2_mm_mlo.csv,
#                            but only when the numbers changed
#   read_cmip7_raw()         CMIP7 annual global-mean CO2 (data/rawData/co2_1750-2022.csv)
#   splice_cmip7_maunaloa()  CMIP7 to 2022 + Mauna Loa after (offset-matched)
#                            -> the Industrial era's 'cmip7' sheet
#
# Used by data-raw/update_maunaloa.R, which the monthly GitHub Action
# (.github/workflows/refresh-co2.yml) runs too. The app itself never downloads.
# =============================================================================

MAUNALOA_URL <- "https://gml.noaa.gov/webdata/ccgg/trends/co2/co2_mm_mlo.csv"

#' Read NOAA's monthly Mauna Loa file
#'
#' @param path co2_mm_mlo.csv (header lines start with #)
#' @return tibble: year, month, decimal_date, co2 (monthly mean, ppm; NOAA
#'   marks missing months with negative fill values)
read_maunaloa_raw <- function(path) {
  raw  <- readr::read_csv(path, comment = "#", show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_double()))
  need <- c("year", "month", "decimal date", "average")
  miss <- setdiff(need, names(raw))
  if (length(miss)) {
    stop(basename(path), " is missing column(s) ", paste(miss, collapse = ", "),
         " - has NOAA changed the file format?", call. = FALSE)
  }
  tibble::tibble(year = as.integer(raw$year), month = as.integer(raw$month),
                 decimal_date = raw$`decimal date`, co2 = raw$average)
}

# "September 2026"
.month_label <- function(df) {
  if (is.null(df) || !nrow(df)) return(NA_character_)
  i <- which.max(df$decimal_date)
  paste(month.name[df$month[i]], df$year[i])
}

#' Is a newly downloaded file sane, and what does it change?
#'
#' @param new read_maunaloa_raw() of the download
#' @param old read_maunaloa_raw() of the current file (NULL if none)
#' @param min_rows Fewer rows means a truncated download
#' @param co2_range Plausible monthly means (ppm)
#' @param max_revision NOAA revises recent months by a few tenths of a ppm;
#'   a bigger change to a month we already have is flagged
#' @return list(ok, problems, through (new last month), was (old last month),
#'   new_months, revised (months whose value changed), changed)
check_maunaloa_update <- function(new, old = NULL, min_rows = 600,
                                  co2_range = c(300, 600), max_revision = 1) {
  problems <- character(0)
  flag <- function(...) problems <<- c(problems, paste0(...))

  if (nrow(new) < min_rows) flag("only ", nrow(new), " rows (expected at least ", min_rows, ")")
  if (anyNA(new$decimal_date) || anyNA(new$co2)) flag("empty dates or CO2 values")
  if (nrow(new) && min(new$year, na.rm = TRUE) != 1958) flag("the record doesn't start in 1958")
  if (is.unsorted(new$decimal_date, na.rm = TRUE, strictly = TRUE)) flag("dates are not in order")
  measured <- new$co2[!is.na(new$co2) & new$co2 > 0]           # skip -99.99 fills
  if (any(measured < co2_range[1] | measured > co2_range[2])) {
    flag("CO2 values outside ", co2_range[1], "-", co2_range[2], " ppm")
  }

  new_months <- nrow(new)
  revised <- 0L
  if (!is.null(old) && nrow(old)) {
    if (max(new$decimal_date, na.rm = TRUE) < max(old$decimal_date, na.rm = TRUE)) {
      flag("the new file ends earlier (", .month_label(new), ") than the current one (",
           .month_label(old), ")")
    }
    both <- merge(old, new, by = c("year", "month"), suffixes = c(".old", ".new"))
    delta <- abs(both$co2.new - both$co2.old)
    revised <- sum(delta > 0, na.rm = TRUE)
    big <- both[!is.na(delta) & delta > max_revision & both$co2.old > 0 & both$co2.new > 0, ]
    if (nrow(big)) {
      flag(nrow(big), " month(s) we already had changed by more than ", max_revision,
           " ppm (e.g. ", month.name[big$month[1]], " ", big$year[1], ")")
    }
    new_months <- nrow(new) - nrow(both)
  }

  list(ok = !length(problems), problems = problems,
       through = .month_label(new), was = .month_label(old),
       new_months = as.integer(new_months), revised = as.integer(revised),
       changed = new_months > 0 || revised > 0)
}

# Download a URL to a file (swapped for a fake in the tests)
.fetch_to_file <- function(url, path) {
  httr2::request(url) |>
    httr2::req_user_agent("Beats per Million data refresh (R/httr2)") |>
    httr2::req_timeout(60) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform(path = path)
  invisible(path)
}

#' Fetch the newest file and replace `dest` if it passes the checks
#'
#' The file is only replaced when the numbers changed (a new month or a
#' revision): NOAA re-stamps the header every day, which alone isn't news.
#'
#' @param dest data/rawData/co2_mm_mlo.csv
#' @param fetch function(url, path) that downloads url to path
#' @return check_maunaloa_update() result (invisibly); stops if the checks fail
download_maunaloa <- function(dest, url = MAUNALOA_URL, fetch = .fetch_to_file) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  tryCatch(fetch(url, tmp), error = function(e) {
    stop("Could not download ", url, " (", conditionMessage(e), "). If NOAA has moved ",
         "the file, download it by hand from https://gml.noaa.gov/ccgg/trends/data.html, ",
         "save it as ", dest, " and run data-raw/build_co2_data.R.", call. = FALSE)
  })
  new <- read_maunaloa_raw(tmp)
  old <- if (file.exists(dest)) read_maunaloa_raw(dest) else NULL
  chk <- check_maunaloa_update(new, old)
  if (!chk$ok) {
    stop("Kept the current file - the download looks wrong: ",
         paste(chk$problems, collapse = "; "), call. = FALSE)
  }
  if (chk$changed) {
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(tmp, dest, overwrite = TRUE)) stop("Could not write ", dest, call. = FALSE)
  }
  invisible(chk)
}

# =============================================================================
# CMIP7 HISTORICAL CO2 + MAUNA LOA  ->  the Industrial era
# =============================================================================

#' Read the CMIP7 annual global-mean CO2 file
#'
#' @param path data/rawData/co2_1750-2022.csv (columns year, co2_ppm)
#' @return tibble: year (integer), co2 (ppm)
read_cmip7_raw <- function(path) {
  raw  <- readr::read_csv(path, show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_double()))
  miss <- setdiff(c("year", "co2_ppm"), names(raw))
  if (length(miss)) {
    stop(basename(path), " is missing column(s) ", paste(miss, collapse = ", "),
         call. = FALSE)
  }
  out <- tibble::tibble(year = as.integer(raw$year), co2 = raw$co2_ppm)
  out <- out[!is.na(out$year) & !is.na(out$co2), ]
  out[order(out$year), ]
}

#' Extend the CMIP7 record with Mauna Loa
#'
#' CMIP7 gives annual global means up to 2022. Later years are Mauna Loa annual
#' means (the running year only once it is complete - a part year would carry
#' the seasonal cycle),
#' shifted down by Mauna Loa's mean offset over the last `overlap_years` years
#' both records share (Mauna Loa reads ~1 ppm above the global mean), so the
#' curve has no step where the two records meet.
#'
#' @param cmip read_cmip7_raw()
#' @param mlo read_maunaloa_raw() (monthly)
#' @param start_year First year to keep
#' @param overlap_years Shared years used for the offset
#' @return list(data = tibble(year, decimal_date, age, co2, source), offset,
#'   overlap = c(first, last) year used, last_cmip, last_year)
splice_cmip7_maunaloa <- function(cmip, mlo, start_year = CMIP7_START_YEAR,
                                  overlap_years = CMIP7_OVERLAP_YEARS) {
  mlo <- mlo[!is.na(mlo$co2) & mlo$co2 > 0, ]                  # skip -99.99 fills
  n_month <- tapply(mlo$co2, mlo$year, length)
  ann <- tapply(mlo$co2, mlo$year, mean)
  yrs <- as.integer(names(n_month))
  # the running year counts only once all 12 months are in (a part year would
  # carry the seasonal cycle); a missing month inside the record is no reason
  # to drop the year
  full <- yrs[yrs < max(yrs) | n_month[as.character(yrs)] == 12]
  mlo_ann <- tibble::tibble(year = full, co2 = unname(ann[as.character(full)]))

  shared <- intersect(cmip$year, mlo_ann$year)
  if (!length(shared)) stop("CMIP7 and Mauna Loa share no complete year.", call. = FALSE)
  shared <- utils::tail(sort(shared), overlap_years)
  offset <- mean(mlo_ann$co2[match(shared, mlo_ann$year)] -
                   cmip$co2[match(shared, cmip$year)])

  last_cmip <- max(cmip$year)
  after <- mlo_ann[mlo_ann$year > last_cmip, ]
  data <- rbind(
    data.frame(year = cmip$year, co2 = cmip$co2, source = "CMIP7"),
    data.frame(year = after$year, co2 = after$co2 - offset,
               source = rep("Mauna Loa (adjusted)", nrow(after)))
  )
  data <- data[data$year >= start_year, ]
  # Each annual mean sits at the start of its year (age = 1950 - year), so the
  # era runs 1850 -> last year exactly and song edges read as whole years
  # (half a year off the mid-year centre - invisible at 7 years per song).
  data$decimal_date <- as.numeric(data$year)
  data$age <- REFERENCE_YEAR - data$decimal_date
  data <- tibble::as_tibble(data[order(data$year), c("year", "decimal_date", "age", "co2", "source")])

  list(data = data, offset = offset, overlap = range(shared),
       last_cmip = last_cmip, last_year = max(data$year))
}
