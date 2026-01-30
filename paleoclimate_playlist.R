# =============================================================================
# PALEOCLIMATE PLAYLIST GENERATOR
# =============================================================================
# 
# Description:
#   This script translates atmospheric CO2 concentrations through geological
#   time into "beats per minute" (BPM) values for creating music playlists.
#   Lower CO2 = slower/sadder songs; Higher CO2 = faster/happier songs.
#
# Author: [Your Name]
# Date: 2024
# Version: 2.0
#
# Data Sources:
#   - Mauna Loa Observatory: Direct atmospheric CO2 measurements (1958-present)
#     https://gml.noaa.gov/ccgg/trends/data.html
#   - Bereiter et al. (2014): Ice core CO2 reconstruction (0-800,000 years BP)
#     https://www.ncei.noaa.gov/access/paleo-search/
#
# =============================================================================

# -----------------------------------------------------------------------------
# 1. SETUP & CONFIGURATION
# -----------------------------------------------------------------------------

# 1.1 Load Required Packages ----
library(readxl)      # Reading Excel files
library(tidyverse)   # Data manipulation and visualization
library(writexl)     # Writing Excel output files

# 1.2 Global Constants ----

# BPM range for music mapping
# 60 BPM = very slow/sad music (e.g., funeral march)
# 150 BPM = very fast/energetic music (e.g., dance music)
LOWEST_BPM <- 60
HIGHEST_BPM <- 150

# Average song length in minutes
AVERAGE_SONG_LENGTH <- 3

# Reference year for age calculations
REFERENCE_YEAR <- 1950

# -----------------------------------------------------------------------------
# 2. TIME PERIOD CONFIGURATIONS
# -----------------------------------------------------------------------------
# Each time period has:
#   - name: Display name
#   - description: Scientific context
#   - filter_max_age: Maximum age in years BP to include
#   - years_per_minute: How many years = 1 minute of music (compression ratio)
#   - data_source: Which dataset to use ("modern" or "icecore")

time_periods <- list(
  
  modern_observations = list(
    name = "Modern Era (1958-Present)",
    description = paste(
      "Direct atmospheric CO2 measurements from Mauna Loa Observatory, Hawaii.",
      "This period captures the dramatic rise in CO2 from ~315 ppm to over 420 ppm,",
      "known as the 'Keeling Curve'. Each song represents approximately 1 year."
    ),
    filter_max_age = Inf,
    years_per_minute = 1,
    data_source = "modern"
  ),
  
  roman_empire = list(
    name = "Since the Roman Empire (~2,000 years)",
    description = paste(
      "CO2 levels from ice cores spanning human civilization's major eras:",
      "the Roman Empire, Medieval Period, Little Ice Age, and Industrial Revolution.",
      "For most of this period, CO2 remained relatively stable around 280 ppm until the 1800s."
    ),
    filter_max_age = 2000,
    years_per_minute = 20,
    data_source = "icecore"
  ),
  
  last_glacial_maximum = list(
    name = "Since the Last Glacial Maximum (~20,000 years)",
    description = paste(
      "Captures the transition from the Last Ice Age (LGM, ~20,000 years ago)",
      "to the current warm interglacial period. CO2 rose from ~180 ppm during",
      "peak glaciation to ~280 ppm in the pre-industrial Holocene."
    ),
    filter_max_age = 20000,
    years_per_minute = 100,
    data_source = "icecore"
  ),
  
  early_humans = list(
    name = "Since Early Modern Humans (~250,000 years)",
    description = paste(
      "Covers the entire existence of anatomically modern Homo sapiens.",
      "Shows multiple glacial-interglacial cycles with CO2 oscillating between",
      "~180 ppm (ice ages) and ~280 ppm (warm periods)."
    ),
    filter_max_age = 250000,
    years_per_minute = 1000,
    data_source = "icecore"
  ),
  
  ice_core_record = list(
    name = "Full Ice Core Record (~800,000 years)",
    description = paste(
      "The complete ice core record showing 8 major glacial-interglacial cycles.",
      "CO2 never exceeded 300 ppm during this entire period until the modern era.",
      "Each cycle lasted approximately 100,000 years."
    ),
    filter_max_age = 800000,
    years_per_minute = 3000,
    data_source = "icecore"
  )
)

# -----------------------------------------------------------------------------
# 3. DATA LOADING FUNCTIONS
# -----------------------------------------------------------------------------

#' Load CO2 data from Excel file
#' 
#' @param data_dir Path to the data directory
#' @return List containing modern and ice core dataframes
load_co2_data <- function(data_dir = "data") {
  
  data_file <- file.path(data_dir, "co2_data.xlsx")
  
  if (!file.exists(data_file)) {
    stop("Data file not found: ", data_file)
  }
  
  # Load modern observations (Mauna Loa)
  co2_modern <- read_excel(data_file, sheet = "maunaloa") %>%
    select(age, co2) %>%
    mutate(
      # Convert age to years before present (positive values)
      age_bp = -age,
      year_ce = REFERENCE_YEAR - age
    ) %>%
    arrange(age)
  
  # Load ice core reconstruction
  co2_icecore <- read_excel(data_file, sheet = "bereiter2014") %>%
    select(age, co2) %>%
    mutate(
      age_bp = age,
      year_ce = REFERENCE_YEAR - age
    ) %>%
    arrange(age)
  
  return(list(
    modern = co2_modern,
    icecore = co2_icecore
  ))
}

# -----------------------------------------------------------------------------
# 4. CORE CALCULATION FUNCTIONS
# -----------------------------------------------------------------------------

#' Calculate the total time span covered by a dataset
#' 
#' @param data Dataframe with 'age' column
#' @return Numeric: total years in dataset
calculate_data_timespan <- function(data) {
  first_age <- min(data$age, na.rm = TRUE)
  last_age <- max(data$age, na.rm = TRUE)
  return(abs(last_age - first_age))
}


#' Calculate playlist length in minutes
#' 
#' @param total_years Total years in the time period
#' @param years_per_minute Compression ratio (years per minute of music)
#' @return Numeric: playlist length in minutes
calculate_playlist_length <- function(total_years, years_per_minute) {
  return(total_years / years_per_minute)
}


#' Calculate the number of songs needed for a playlist
#' 
#' @param playlist_length_minutes Total playlist length in minutes
#' @param avg_song_length Average song length in minutes (default: 3)
#' @return Numeric: number of songs (rounded up)
calculate_number_of_songs <- function(playlist_length_minutes, 
                                       avg_song_length = AVERAGE_SONG_LENGTH) {
  return(ceiling(playlist_length_minutes / avg_song_length))
}


#' Convert CO2 concentration to beats per minute
#' 
#' Uses linear interpolation to map CO2 values to BPM:
#'   - Lowest CO2 in dataset -> LOWEST_BPM (60)
#'   - Highest CO2 in dataset -> HIGHEST_BPM (150)
#' 
#' @param co2_value CO2 concentration in ppm
#' @param co2_min Minimum CO2 in the dataset
#' @param co2_max Maximum CO2 in the dataset
#' @param bpm_min Minimum BPM (default: 60)
#' @param bpm_max Maximum BPM (default: 150)
#' @return Numeric: calculated BPM value
co2_to_bpm <- function(co2_value, co2_min, co2_max, 
                       bpm_min = LOWEST_BPM, bpm_max = HIGHEST_BPM) {
  
  # Linear interpolation formula
  bpm <- bpm_min + ((bpm_max - bpm_min) / (co2_max - co2_min)) * (co2_value - co2_min)
  
  return(round(bpm, 1))
}


#' Calculate average BPM for each song segment
#' 
#' Divides the data into segments (one per song) and calculates
#' the average CO2/BPM for each segment.
#' 
#' @param data Dataframe with age, co2, and bpm columns
#' @param num_songs Number of songs to divide the data into
#' @return Dataframe with one row per song
calculate_song_bpm <- function(data, num_songs) {
  
  n_rows <- nrow(data)
  window_size <- max(1, floor(n_rows / num_songs))
  
  song_data <- data.frame(
    song_number = integer(),
    start_age = numeric(),
    end_age = numeric(),
    avg_co2 = numeric(),
    avg_bpm = numeric(),
    min_bpm = numeric(),
    max_bpm = numeric()
  )
  
  for (i in 1:num_songs) {
    start_idx <- (i - 1) * window_size + 1
    end_idx <- min(i * window_size, n_rows)
    
    if (start_idx > n_rows) break
    
    segment <- data[start_idx:end_idx, ]
    
    song_data <- rbind(song_data, data.frame(
      song_number = i,
      start_age = min(segment$age, na.rm = TRUE),
      end_age = max(segment$age, na.rm = TRUE),
      avg_co2 = round(mean(segment$co2, na.rm = TRUE), 1),
      avg_bpm = round(mean(segment$bpm, na.rm = TRUE), 0),
      min_bpm = round(min(segment$bpm, na.rm = TRUE), 0),
      max_bpm = round(max(segment$bpm, na.rm = TRUE), 0)
    ))
  }
  
  return(song_data)
}

# -----------------------------------------------------------------------------
# 5. MAIN PLAYLIST GENERATION FUNCTION
# -----------------------------------------------------------------------------

#' Generate a complete paleoclimate playlist for a time period
#' 
#' @param period_config Configuration list for the time period
#' @param co2_data List containing modern and icecore dataframes
#' @return List containing summary statistics and song-by-song BPM data
generate_playlist <- function(period_config, co2_data) {
  
  # Select appropriate data source
  if (period_config$data_source == "modern") {
    data <- co2_data$modern
  } else {
    data <- co2_data$icecore %>%
      filter(age <= period_config$filter_max_age)
  }
  
  # Calculate CO2 range for this period
  co2_min <- min(data$co2, na.rm = TRUE)
  co2_max <- max(data$co2, na.rm = TRUE)
  
  # Add BPM column to data
  data <- data %>%
    mutate(bpm = sapply(co2, co2_to_bpm, 
                        co2_min = co2_min, 
                        co2_max = co2_max))
  
  # Calculate playlist metrics
  total_years <- calculate_data_timespan(data)
  playlist_minutes <- calculate_playlist_length(total_years, 
                                                 period_config$years_per_minute)
  num_songs <- calculate_number_of_songs(playlist_minutes)
  
  # Generate song-by-song BPM data
  song_data <- calculate_song_bpm(data, num_songs)
  
  # Add time period context to song data
  song_data <- song_data %>%
    mutate(
      time_period = period_config$name,
      years_per_song = round(period_config$years_per_minute * AVERAGE_SONG_LENGTH, 0)
    )
  
  # Create summary
  summary <- list(
    name = period_config$name,
    description = period_config$description,
    total_years = round(total_years, 0),
    years_per_minute = period_config$years_per_minute,
    playlist_length_minutes = round(playlist_minutes, 1),
    number_of_songs = num_songs,
    co2_range = c(co2_min, co2_max),
    bpm_range = c(LOWEST_BPM, HIGHEST_BPM),
    data_points = nrow(data)
  )
  
  return(list(
    summary = summary,
    songs = song_data,
    raw_data = data
  ))
}

# -----------------------------------------------------------------------------
# 6. OUTPUT FUNCTIONS
# -----------------------------------------------------------------------------

#' Print a formatted summary of a playlist
#' 
#' @param playlist List returned by generate_playlist()
print_playlist_summary <- function(playlist) {
  s <- playlist$summary
  
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  ", s$name, "\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("\n")
  cat("DESCRIPTION:\n")
  cat(strwrap(s$description, width = 70, prefix = "  "), sep = "\n")
  cat("\n")
  cat("PLAYLIST STATISTICS:\n")
  cat("  • Time span:           ", format(s$total_years, big.mark = ","), " years\n")
  cat("  • Compression ratio:   ", s$years_per_minute, " years per minute\n")
  cat("  • Playlist duration:   ", s$playlist_length_minutes, " minutes\n")
  cat("  • Number of songs:     ", s$number_of_songs, "\n")
  cat("  • CO2 range:           ", s$co2_range[1], " - ", s$co2_range[2], " ppm\n")
  cat("  • BPM range:           ", s$bpm_range[1], " - ", s$bpm_range[2], " BPM\n")
  cat("\n")
}


#' Export all playlist data to Excel file
#' 
#' @param all_playlists List of all generated playlists
#' @param output_file Path for output Excel file
export_playlists_to_excel <- function(all_playlists, output_file = "output/playlist_data.xlsx") {
  
  # Create summary sheet
  summary_df <- do.call(rbind, lapply(names(all_playlists), function(name) {
    s <- all_playlists[[name]]$summary
    data.frame(
      period_id = name,
      period_name = s$name,
      total_years = s$total_years,
      years_per_minute = s$years_per_minute,
      playlist_minutes = s$playlist_length_minutes,
      num_songs = s$number_of_songs,
      co2_min = s$co2_range[1],
      co2_max = s$co2_range[2],
      bpm_min = s$bpm_range[1],
      bpm_max = s$bpm_range[2]
    )
  }))
  
  # Combine all song data
  all_songs_df <- do.call(rbind, lapply(all_playlists, function(p) {
    p$songs
  }))
  
  # Write to Excel with multiple sheets
  sheets <- list(
    "Summary" = summary_df,
    "All_Songs" = all_songs_df
  )
  
  # Add individual period sheets
  for (name in names(all_playlists)) {
    sheets[[gsub("_", " ", name)]] <- all_playlists[[name]]$songs
  }
  
  write_xlsx(sheets, output_file)
  cat("Exported playlist data to:", output_file, "\n")
}


#' Generate BPM recommendation categories
#' 
#' Maps BPM ranges to music mood/genre suggestions
#' 
#' @param bpm BPM value
#' @return Character string with mood/genre suggestion
get_music_mood <- function(bpm) {
  if (bpm < 70) return("Very Slow - Ambient, Funeral March, Gregorian Chant")
  if (bpm < 90) return("Slow - Ballads, Blues, Slow Jazz")
  if (bpm < 110) return("Moderate - Pop, Soft Rock, R&B")
  if (bpm < 130) return("Upbeat - Rock, Funk, Disco")
  if (bpm < 150) return("Fast - Dance, Electronic, Punk")
  return("Very Fast - Drum & Bass, Hardcore")
}

# -----------------------------------------------------------------------------
# 7. MAIN EXECUTION
# -----------------------------------------------------------------------------

#' Run the complete playlist generation workflow
#' 
#' @param data_dir Directory containing the data files
#' @param output_dir Directory for output files
run_playlist_generator <- function(data_dir = "data", output_dir = "output") {
  
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════════════════╗\n")
  cat("║         PALEOCLIMATE PLAYLIST GENERATOR v2.0                     ║\n")
  cat("║         Translating Earth's Climate History into Music           ║\n")
  cat("╚═══════════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  
  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Load data
  cat("Loading CO2 data...\n")
  co2_data <- load_co2_data(data_dir)
  cat("  ✓ Modern observations:", nrow(co2_data$modern), "data points\n")
  cat("  ✓ Ice core record:", nrow(co2_data$icecore), "data points\n")
  cat("\n")
  
  # Generate all playlists
  cat("Generating playlists...\n\n")
  all_playlists <- list()
  
  for (period_id in names(time_periods)) {
    cat("  Processing:", time_periods[[period_id]]$name, "...\n")
    all_playlists[[period_id]] <- generate_playlist(
      time_periods[[period_id]], 
      co2_data
    )
  }
  
  # Print summaries
  for (playlist in all_playlists) {
    print_playlist_summary(playlist)
  }
  
  # Export to Excel
  export_playlists_to_excel(all_playlists, file.path(output_dir, "playlist_data.xlsx"))
  
  # Print song list for each period
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  SONG-BY-SONG BPM REQUIREMENTS\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  
  for (name in names(all_playlists)) {
    playlist <- all_playlists[[name]]
    cat("\n", playlist$summary$name, "\n")
    cat(strrep("-", 70), "\n")
    cat(sprintf("%-6s  %-20s  %-8s  %s\n", 
                "Song#", "Time Period", "Avg BPM", "Mood/Genre"))
    cat(strrep("-", 70), "\n")
    
    for (i in 1:min(10, nrow(playlist$songs))) {
      song <- playlist$songs[i, ]
      if (song$start_age < 0) {
        time_label <- sprintf("%.0f-%0.f CE", 
                              REFERENCE_YEAR - song$end_age,
                              REFERENCE_YEAR - song$start_age)
      } else {
        time_label <- sprintf("%.0f-%.0f BP", song$start_age, song$end_age)
      }
      cat(sprintf("%-6d  %-20s  %-8d  %s\n",
                  song$song_number,
                  substr(time_label, 1, 20),
                  song$avg_bpm,
                  get_music_mood(song$avg_bpm)))
    }
    if (nrow(playlist$songs) > 10) {
      cat(sprintf("  ... and %d more songs\n", nrow(playlist$songs) - 10))
    }
  }
  
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  Generation complete! Check the output folder for exported data.\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("\n")
  
  return(all_playlists)
}

# -----------------------------------------------------------------------------
# 8. SCRIPT EXECUTION
# -----------------------------------------------------------------------------

# Run the generator when script is sourced
# Comment out the line below if you want to source the functions only
# all_playlists <- run_playlist_generator()

# Example: Run manually with custom directories
# all_playlists <- run_playlist_generator(data_dir = "data", output_dir = "output")
