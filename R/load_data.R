# =============================================================================
# CLIMATE PLAYLISTS - DATA LOADING
# =============================================================================
#
# This file handles loading and normalizing all CO2 datasets.
# All data is converted to a standard format with columns:
#   - age_bp: Age in years before present (1950), positive values
#   - co2: CO2 concentration in ppm
#
# Requires: config.R to be sourced first
#
# =============================================================================

library(readxl)
library(dplyr)

# -----------------------------------------------------------------------------
# MAIN DATA LOADING FUNCTION
# -----------------------------------------------------------------------------

#' Load all CO2 datasets
#' 
#' @param data_dir Path to the data directory
#' @return Named list with 'modern', 'icecore', and 'cenozoic' dataframes
#' 
load_co2_data <- function(data_dir = "data") {
  
  cat("Loading CO₂ data...\n")
  
  # Initialize results
  co2_data <- list()
  
  # -------------------------------------------------------------------------
  # Load Modern (Mauna Loa) data
  # -------------------------------------------------------------------------
  modern_file <- file.path(data_dir, "co2_data.xlsx")
  
  if (file.exists(modern_file)) {
    modern <- read_excel(modern_file, sheet = "maunaloa") %>%
      select(year, age, co2) %>%
      mutate(
        # Keep original age (negative = years after 1950)
        # Add year_ce for display
        year_ce = round(REFERENCE_YEAR - age)
      ) %>%
      arrange(age)  # Sort by age (most negative = most recent)
    
    co2_data$modern <- modern
    cat("  ✓ Modern (Mauna Loa):", nrow(modern), "records,",
        min(modern$year_ce), "–", max(modern$year_ce), "CE\n")
  } else {
    warning("Modern data file not found: ", modern_file)
  }
  
  # -------------------------------------------------------------------------
  # Load Ice Core (Bereiter et al. 2015) data
  # -------------------------------------------------------------------------
  icecore_file <- file.path(data_dir, "co2_data.xlsx")

  if (file.exists(icecore_file)) {
    # NB: sheet name "bereiter2014" is retained for data compatibility;
    # the underlying source is Bereiter et al. 2015 (GRL).
    icecore <- read_excel(icecore_file, sheet = "bereiter2014") %>%
      select(age, co2) %>%
      arrange(age)  # Sort by age (smallest = most recent)

    co2_data$icecore <- icecore
    cat("  ✓ Ice Core (Bereiter 2015):", nrow(icecore), "records,",
        round(min(icecore$age)), "–", format(round(max(icecore$age)), big.mark = ","), "years BP\n")
  } else {
    warning("Ice core data file not found: ", icecore_file)
  }
  
  # -------------------------------------------------------------------------
  # Load Cenozoic (Rae 2021) data
  # -------------------------------------------------------------------------
  cenozoic_file <- file.path(data_dir, "raw", "rae2021co2.xlsx")
  
  # Also check rawData for backward compatibility
  if (!file.exists(cenozoic_file)) {
    cenozoic_file <- file.path(data_dir, "rawData", "rae2021co2.xlsx")
  }
  
  if (file.exists(cenozoic_file)) {
    cenozoic <- load_rae2021_data(cenozoic_file)
    co2_data$cenozoic <- cenozoic
    cat("  ✓ Cenozoic (Rae 2021):", nrow(cenozoic), "records,",
        "0 –", round(max(cenozoic$age) / 1e6, 1), "Ma\n")
  } else {
    warning("Cenozoic data file not found. Looked in: ", cenozoic_file)
  }
  
  cat("\n")
  return(co2_data)
}

# -----------------------------------------------------------------------------
# SONG LIBRARY LOADING
# -----------------------------------------------------------------------------

#' Load the persistent song library
#'
#' Reads `data/song_library.csv` (your hand-entered songs). Everything is read as
#' text so re-saving the file in Excel can't corrupt types; `bpm` is then coerced
#' to numeric for matching. Missing expected columns are backfilled as blank, and
#' a missing file returns an empty (but correctly-shaped) tibble so the app runs
#' fine before the library is seeded.
#'
#' @param data_dir Path to the data directory (default: "data").
#' @return Tibble with columns song_title, artist, spotify_uri, soundcloud_url,
#'   bpm, notes.
load_song_library <- function(data_dir = "data") {

  needed <- c("song_title", "artist", "spotify_uri",
              "soundcloud_url", "bpm", "notes")

  empty <- tibble::tibble(
    song_title = character(),  artist = character(),        spotify_uri = character(),
    soundcloud_url = character(), bpm = double(),           notes = character()
  )

  library_file <- file.path(data_dir, "song_library.csv")
  if (!file.exists(library_file)) {
    cat("  • Song library: none yet (", library_file, " not found) — ",
        "run run_generator.R to seed it, or add it by hand.\n", sep = "")
    return(empty)
  }

  # Read every column as character so Excel re-saves can't mangle types.
  df <- readr::read_csv(
    library_file,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  # Backfill any missing expected columns as blank.
  for (col in needed) {
    if (!col %in% names(df)) df[[col]] <- NA_character_
  }

  # Coerce the match key to numeric.
  df$bpm <- suppressWarnings(as.numeric(df$bpm))

  n_playable <- sum(
    !is.na(df$bpm) & (
      (!is.na(df$spotify_uri)    & nzchar(trimws(df$spotify_uri))) |
      (!is.na(df$soundcloud_url) & nzchar(trimws(df$soundcloud_url)))
    )
  )
  cat("  ✓ Song library:", nrow(df), "songs,", n_playable,
      "playable (BPM + a Spotify/SoundCloud link)\n")

  df[, needed]
}

# -----------------------------------------------------------------------------
# RAE 2021 DATA LOADING
# -----------------------------------------------------------------------------

#' Load and combine Rae et al. 2021 CO2 proxy data
#' 
#' Combines alkenone δ13C and boron isotope (δ11B) reconstructions.
#' Ages in the original file are in ka (thousands of years).
#' 
#' @param file_path Path to rae2021co2.xlsx
#' @return Dataframe with age_bp (years) and co2 (ppm)
#' 
load_rae2021_data <- function(file_path) {
  
  # Load alkenone data
  alkenone <- read_excel(file_path, sheet = "alkenone_d13C") %>%
    select(age, co2) %>%
    filter(!is.na(co2)) %>%
    mutate(
      # Age is in ka (thousands of years), convert to years
      age = age * 1000,
      source = "alkenone"
    )
  
  # Load boron isotope data
  boron <- read_excel(file_path, sheet = "d11B_pH") %>%
    select(age, xco2) %>%
    rename(co2 = xco2) %>%
    filter(!is.na(co2)) %>%
    mutate(
      # Age is in ka (thousands of years), convert to years
      age = age * 1000,
      source = "boron"
    )
  
  # Combine both proxy records
  combined <- bind_rows(alkenone, boron) %>%
    select(age, co2, source) %>%
    arrange(age)
  
  # For each time bin, take the mean if multiple measurements
  # This smooths the record while preserving the overall signal
  binned <- combined %>%
    mutate(
      # Create age bins (every 100 ka for deep time)
      age_bin = floor(age / 100000) * 100000
    ) %>%
    group_by(age_bin) %>%
    summarise(
      age = mean(age),
      co2 = mean(co2, na.rm = TRUE),
      n_records = n(),
      .groups = "drop"
    ) %>%
    select(age, co2) %>%
    arrange(age)
  
  return(binned)
}

# -----------------------------------------------------------------------------
# DATA VALIDATION
# -----------------------------------------------------------------------------

#' Validate loaded CO2 data
#' 
#' @param co2_data List of CO2 dataframes
#' @return TRUE if valid, stops with error if not
#' 
validate_co2_data <- function(co2_data) {
  
  for (name in names(co2_data)) {
    df <- co2_data[[name]]
    
    # Check required columns
    if (!"age" %in% names(df)) {
      stop("Dataset '", name, "' missing required column 'age'")
    }
    if (!"co2" %in% names(df)) {
      stop("Dataset '", name, "' missing required column 'co2'")
    }
    
    # Check for valid values
    if (any(is.na(df$co2))) {
      warning("Dataset '", name, "' contains ", sum(is.na(df$co2)), " NA values in 'co2'")
    }
    
    # Check CO2 is in reasonable range
    co2_range <- range(df$co2, na.rm = TRUE)
    if (co2_range[1] < 100 || co2_range[2] > 10000) {
      warning("Dataset '", name, "' has unusual CO2 range: ", 
              co2_range[1], " – ", co2_range[2], " ppm")
    }
  }
  
  return(TRUE)
}

# -----------------------------------------------------------------------------
# QUICK SUMMARY
# -----------------------------------------------------------------------------

#' Print a summary of loaded CO2 data
#' 
#' @param co2_data List of CO2 dataframes
#' 
summarize_co2_data <- function(co2_data) {
  
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  CO₂ DATA SUMMARY\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("\n")
  
  for (name in names(co2_data)) {
    df <- co2_data[[name]]
    age_range <- range(df$age, na.rm = TRUE)
    co2_range <- range(df$co2, na.rm = TRUE)
    
    cat(sprintf("%-12s  %6d records  |  Age: %12s – %-12s  |  CO₂: %4.0f – %4.0f ppm\n",
                name,
                nrow(df),
                format_age(age_range[1]),
                format_age(age_range[2]),
                co2_range[1],
                co2_range[2]))
  }
  
  cat("\n")
}
