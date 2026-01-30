# =============================================================================
# PALEOCLIMATE PLAYLIST - SONG LIST GENERATOR
# =============================================================================
#
# Description:
#   This script generates playlist templates for each time period with columns
#   for age, CO2, BPM, and an empty "song" column where you can add your own
#   song selections. Outputs are saved as CSV files (easy to edit) and as a 
#   single Excel file with one sheet per time period.
#
# Output files:
#   - playlist_template_modern.csv
#   - playlist_template_roman.csv
#   - playlist_template_lgm.csv
#   - playlist_template_humans.csv
#   - playlist_template_full.csv
#   - all_playlist_templates.xlsx (all periods in one file)
#
# =============================================================================

# -----------------------------------------------------------------------------
# 1. LOAD PACKAGES
# -----------------------------------------------------------------------------

library(readxl)
library(tidyverse)
library(writexl)

# -----------------------------------------------------------------------------
# 2. CONFIGURATION
# -----------------------------------------------------------------------------

# BPM range for music mapping
BPM_MIN <- 60
BPM_MAX <- 150

# Average song length in minutes
AVG_SONG_LENGTH <- 3

# Reference year for age calculations
REFERENCE_YEAR <- 1950

# Output directory (will be created if it doesn't exist)
OUTPUT_DIR <- "output"

# Time period configurations
TIME_PERIODS <- list(
  
  modern = list(
    id = "modern",
    name = "Modern Era (1958-Present)",
    years_span = 67,
    years_per_minute = 1,
    data_source = "modern",
    filter_max_age = Inf
  ),
  
  roman = list(
    id = "roman",
    name = "Roman Empire Era (~2,000 years)",
    years_span = 2000,
    years_per_minute = 20,
    data_source = "icecore",
    filter_max_age = 2000
  ),
  
  lgm = list(
    id = "lgm",
    name = "Last Glacial Maximum (~20,000 years)",
    years_span = 20000,
    years_per_minute = 100,
    data_source = "icecore",
    filter_max_age = 20000
  ),
  
  humans = list(
    id = "humans",
    name = "Early Modern Humans (~250,000 years)",
    years_span = 250000,
    years_per_minute = 1000,
    data_source = "icecore",
    filter_max_age = 250000
  ),
  
  full = list(
    id = "full",
    name = "Full Ice Core Record (~800,000 years)",
    years_span = 800000,
    years_per_minute = 3000,
    data_source = "icecore",
    filter_max_age = 800000
  )
)

# -----------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
# -----------------------------------------------------------------------------

#' Convert CO2 concentration to beats per minute
co2_to_bpm <- function(co2, co2_min, co2_max) {
  bpm <- BPM_MIN + ((BPM_MAX - BPM_MIN) / (co2_max - co2_min)) * (co2 - co2_min)
  return(round(pmin(pmax(bpm, BPM_MIN), BPM_MAX), 0))
}

#' Get music mood/genre suggestion from BPM
get_mood <- function(bpm) {
  case_when(
    bpm < 70 ~ "Glacial (Ambient/Drone)",
    bpm < 90 ~ "Slow (Jazz/Ballads)",
    bpm < 110 ~ "Moderate (Pop/Soft Rock)",
    bpm < 130 ~ "Upbeat (Rock/Funk)",
    TRUE ~ "Fast (Dance/Electronic)"
  )
}

#' Format age for display
format_age <- function(age, is_modern = FALSE) {
  if (is_modern) {
    year <- round(REFERENCE_YEAR - age)
    return(paste0(year, " CE"))
  } else {
    if (age < 0) {
      return(paste0(round(REFERENCE_YEAR - age), " CE"))
    }
    if (age < 1000) return(paste0(round(age), " BP"))
    if (age < 10000) return(paste0(round(age/1000, 1), "k BP"))
    return(paste0(round(age/1000), "k BP"))
  }
}

# -----------------------------------------------------------------------------
# 4. LOAD DATA
# -----------------------------------------------------------------------------

cat("Loading CO2 data...\n")

data_file <- "data/co2_data.xlsx"

if (file.exists(data_file)) {
  co2_modern <- read_excel(data_file, sheet = "maunaloa") %>%
    select(age, co2)
  co2_icecore <- read_excel(data_file, sheet = "bereiter2014") %>%
    select(age, co2)
  cat("  ✓ Loaded data from", data_file, "\n")
} else {
  cat("  ! Data file not found. Creating sample data...\n")
  
  # Sample modern data
  co2_modern <- tibble(
    age = seq(-8, -74, by = -1),
    co2 = c(315.7, 316.7, 317.6, 318.5, 319.7, 319.9, 320.8, 320.9, 322.4,
            323.0, 323.9, 325.6, 326.9, 327.2, 327.8, 330.3, 331.5, 331.9,
            333.4, 335.0, 336.7, 338.3, 340.1, 341.6, 342.8, 343.4, 345.7,
            347.9, 348.3, 349.8, 352.5, 354.1, 355.8, 357.3, 358.0, 358.6,
            360.1, 362.0, 364.3, 364.7, 367.4, 369.8, 370.8, 372.6, 374.3,
            376.6, 379.1, 381.0, 382.9, 384.8, 386.3, 389.0, 391.4, 392.8,
            394.6, 397.7, 399.9, 401.7, 405.1, 407.5, 409.6, 412.2, 414.7,
            417.6, 418.8, 421.0, 425.4)
  )
  
  # Sample ice core data
  co2_icecore <- tibble(
    age = c(-51, 0, 500, 1000, 2000, 5000, 8000, 10000, 11500, 12000,
            14000, 16000, 18000, 20000, 25000, 30000, 40000, 50000,
            60000, 70000, 80000, 90000, 100000, 110000, 120000, 130000,
            140000, 150000, 180000, 200000, 220000, 240000, 260000,
            280000, 300000, 320000, 340000, 400000, 450000, 500000,
            550000, 600000, 650000, 700000, 750000, 800000),
    co2 = c(368, 312, 283, 280, 277, 266, 260, 264, 267, 250, 240, 220,
            188, 190, 183, 188, 195, 204, 210, 215, 230, 230, 245, 255,
            275, 250, 195, 200, 210, 245, 210, 275, 210, 200, 230, 250,
            235, 280, 200, 230, 245, 240, 190, 235, 195, 200)
  )
}

CO2_DATA <- list(modern = co2_modern, icecore = co2_icecore)

# -----------------------------------------------------------------------------
# 5. GENERATE PLAYLIST TEMPLATES
# -----------------------------------------------------------------------------

#' Generate a playlist template for a given time period
generate_playlist_template <- function(period_config, co2_data) {
  
  cat("  Generating:", period_config$name, "...\n")
  
  # Select appropriate data source
  if (period_config$data_source == "modern") {
    data <- co2_data$modern
    is_modern <- TRUE
  } else {
    data <- co2_data$icecore %>%
      filter(age <= period_config$filter_max_age)
    is_modern <- FALSE
  }
  
  # Calculate CO2 range
  co2_min <- min(data$co2, na.rm = TRUE)
  co2_max <- max(data$co2, na.rm = TRUE)
  
  # Calculate number of songs
  playlist_minutes <- period_config$years_span / period_config$years_per_minute
  num_songs <- ceiling(playlist_minutes / AVG_SONG_LENGTH)
  years_per_song <- period_config$years_span / num_songs
  
  # Generate song entries
  songs <- tibble(
    song_number = 1:num_songs,
    start_age = (0:(num_songs-1)) * years_per_song,
    end_age = (1:num_songs) * years_per_song
  )
  
  # Calculate average CO2 for each song
  songs <- songs %>%
    rowwise() %>%
    mutate(
      relevant_data = list(
        if (is_modern) {
          data %>% filter(-age >= start_age & -age < end_age)
        } else {
          data %>% filter(age >= start_age & age < end_age)
        }
      ),
      co2_ppm = if (nrow(relevant_data) > 0) {
        round(mean(relevant_data$co2, na.rm = TRUE), 0)
      } else {
        mid_age <- (start_age + end_age) / 2
        closest <- data %>%
          mutate(dist = abs(ifelse(is_modern, -age, age) - mid_age)) %>%
          arrange(dist) %>%
          head(2)
        round(mean(closest$co2), 0)
      }
    ) %>%
    ungroup() %>%
    select(-relevant_data)
  
  # Add BPM and mood
  songs <- songs %>%
    mutate(
      bpm = co2_to_bpm(co2_ppm, co2_min, co2_max),
      mood_genre = get_mood(bpm)
    )
  
  # Format ages for display
  if (is_modern) {
    songs <- songs %>%
      mutate(
        age_start = sapply(end_age, function(a) format_age(-a, TRUE)),
        age_end = sapply(start_age, function(a) format_age(-a, TRUE))
      ) %>%
      arrange(desc(song_number)) %>%
      mutate(song_number = row_number())
  } else {
    songs <- songs %>%
      mutate(
        age_start = sapply(start_age, format_age),
        age_end = sapply(end_age, format_age)
      )
  }
  
  # Create final template with empty song columns
  playlist_template <- songs %>%
    transmute(
      song_number,
      age_period = paste(age_start, "→", age_end),
      co2_ppm,
      bpm,
      mood_genre,
      song_title = "",
      artist = "",
      spotify_uri = "",
      soundcloud_url = "",
      notes = ""
    )
  
  return(playlist_template)
}

# Create output directory
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

cat("\nGenerating playlist templates...\n")

# Generate all playlists
all_playlists <- list()

for (period_id in names(TIME_PERIODS)) {
  period <- TIME_PERIODS[[period_id]]
  playlist <- generate_playlist_template(period, CO2_DATA)
  all_playlists[[period_id]] <- playlist
  
  # Save individual CSV
  csv_file <- file.path(OUTPUT_DIR, paste0("playlist_template_", period_id, ".csv"))
  write_csv(playlist, csv_file)
  cat("    Saved:", csv_file, "(", nrow(playlist), "songs )\n")
}

# Save all playlists to a single Excel file
excel_file <- file.path(OUTPUT_DIR, "all_playlist_templates.xlsx")
write_xlsx(all_playlists, excel_file)
cat("\n  ✓ Saved all playlists to:", excel_file, "\n")

# -----------------------------------------------------------------------------
# 6. PRINT SUMMARY
# -----------------------------------------------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  PLAYLIST TEMPLATES GENERATED\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

for (period_id in names(TIME_PERIODS)) {
  period <- TIME_PERIODS[[period_id]]
  playlist <- all_playlists[[period_id]]
  
  cat(sprintf("%-40s %3d songs  |  BPM range: %d - %d\n",
              period$name,
              nrow(playlist),
              min(playlist$bpm),
              max(playlist$bpm)))
}

cat("\n")
cat("───────────────────────────────────────────────────────────────────\n")
cat("COLUMNS IN EACH TEMPLATE:\n")
cat("───────────────────────────────────────────────────────────────────\n")
cat("  • song_number   - Sequential song number\n")
cat("  • age_period    - Time period this song represents\n")
cat("  • co2_ppm       - Average CO2 concentration (ppm)\n")
cat("  • bpm           - Target beats per minute for the song\n")
cat("  • mood_genre    - Suggested mood/genre based on BPM\n")
cat("  • song_title    - [EMPTY - Add your song title here]\n")
cat("  • artist        - [EMPTY - Add the artist name here]\n")
cat("  • spotify_uri   - [EMPTY - Add Spotify URI if available]\n")
cat("  • soundcloud_url- [EMPTY - Add SoundCloud URL if available]\n")
cat("  • notes         - [EMPTY - Add any notes]\n")
cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  Files saved to:", normalizePath(OUTPUT_DIR), "\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

# -----------------------------------------------------------------------------
# 7. PREVIEW FIRST PLAYLIST
# -----------------------------------------------------------------------------

cat("PREVIEW - Modern Era playlist (first 10 songs):\n\n")

preview <- all_playlists$modern %>%
  head(10) %>%
  select(song_number, age_period, co2_ppm, bpm, mood_genre)

print(preview, n = 10)

cat("\n")
cat("Open the CSV files in Excel or Google Sheets to add your songs!\n")
cat("\n")
