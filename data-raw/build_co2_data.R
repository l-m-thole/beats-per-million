# =============================================================================
# CLIMATE PLAYLISTS - BUILD PROCESSED DATA FROM RAW SOURCES
# =============================================================================
#
# Rebuilds data/co2_data.xlsx from the raw files in data/rawData/.
# Run from the project root:
#
#   source("data-raw/build_co2_data.R")
#
# To fetch NOAA's newest Mauna Loa months first, run
# data-raw/update_maunaloa.R instead (it calls this script).
#
# Sheets produced:
#   maunaloa      Modern monthly CO2 (NOAA Mauna Loa)
#   bereiter2014  Ice-core 800 kyr composite (Bereiter et al. 2015; name kept
#                 for backwards compatibility with load_data.R)
#
# The Cenozoic (Rae et al. 2021) record is NOT cached here: the app and
# run_generator.R derive it directly from data/rawData/rae2021co2.xlsx via
# load_rae2021_data(), so a cached copy would only risk drifting out of sync.
#
# =============================================================================

library(readr)
library(readxl)
library(dplyr)
library(writexl)

# --- Resolve project root whether run from root or from data-raw/ ------------
root <- if (file.exists("R/config.R")) "." else
  if (file.exists("../R/config.R")) ".." else
    stop("Run this script from the project root (or data-raw/).")

source(file.path(root, "R", "config.R"))       # REFERENCE_YEAR
source(file.path(root, "R", "refresh_co2.R"))  # read_maunaloa_raw()

raw_dir  <- file.path(root, "data", "rawData")
out_file <- file.path(root, "data", "co2_data.xlsx")

# -----------------------------------------------------------------------------
# 1) MODERN - NOAA Mauna Loa monthly mean CO2 ("Keeling Curve")
#    Source:  https://gml.noaa.gov/ccgg/trends/data.html  (co2_mm_mlo.csv)
#    Cite:    Lan, Tans & Thoning, NOAA GML; Keeling, Scripps (SIO).
#    Columns: year, month, `decimal date`, average, deseasonalized, ...
#    age = REFERENCE_YEAR - decimal_date  (negative = years after 1950)
# -----------------------------------------------------------------------------
build_maunaloa <- function() {
  message("- Mauna Loa (modern) ...")
  read_maunaloa_raw(file.path(raw_dir, "co2_mm_mlo.csv")) %>%   # co2 = monthly mean, ppm
    mutate(age = REFERENCE_YEAR - decimal_date) %>%
    filter(co2 > 0) %>%                        # guard against any -99.99 fills
    select(year, month, decimal_date, age, co2) %>%
    arrange(decimal_date)                      # oldest first, as in the committed sheet
}

# -----------------------------------------------------------------------------
# 2) ICE CORE - Bereiter et al. (2015) 800 kyr Antarctic composite
#    Source:  https://www.ncei.noaa.gov/access/paleo-search/study/17975
#    Expected raw file: data/rawData/bereiter*.{txt,csv,xlsx} with an age
#    column (years BP, gas age) and a CO2 column (ppm).
#    NOTE: the raw composite is not yet committed to this repo. Until it is,
#    the existing 'bereiter2014' sheet is preserved and a warning is issued,
#    so the pipeline still runs end to end.
# -----------------------------------------------------------------------------
build_bereiter <- function() {
  message("- Bereiter (ice core) ...")
  hits <- list.files(raw_dir, pattern = "bereiter.*\\.(txt|csv|xlsx)$",
                     full.names = TRUE, ignore.case = TRUE)

  if (length(hits) == 0) {
    warning("No raw Bereiter file in ", raw_dir,
            " - preserving the existing 'bereiter2014' sheet. ",
            "Download the composite (see script header) and re-run for full provenance.")
    return(read_excel(out_file, sheet = "bereiter2014"))
  }

  f <- hits[1]
  message("    using ", basename(f))
  raw <- if (grepl("\\.xlsx$", f, ignore.case = TRUE)) read_excel(f)
         else read_table(f, comment = "#", show_col_types = FALSE)

  names(raw) <- tolower(names(raw))
  age_col <- grep("age", names(raw), value = TRUE)[1]
  co2_col <- grep("co2|ppm", names(raw), value = TRUE)[1]
  if (is.na(age_col) || is.na(co2_col)) {
    stop("Could not find age/co2 columns in ", basename(f),
         " (saw: ", paste(names(raw), collapse = ", "), ")")
  }

  raw %>%
    transmute(age = as.numeric(.data[[age_col]]),
              co2 = as.numeric(.data[[co2_col]])) %>%
    filter(!is.na(age), !is.na(co2)) %>%
    arrange(age)
}

# -----------------------------------------------------------------------------
# Assemble & write
# -----------------------------------------------------------------------------
message("Building ", out_file, " ...")
sheets <- list(
  maunaloa     = build_maunaloa(),
  bereiter2014 = build_bereiter()
)

write_xlsx(sheets, out_file)
message("Done. Wrote ", normalizePath(out_file),
        " (sheets: ", paste(names(sheets), collapse = ", "), ")")
