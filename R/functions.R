# =============================================================================
# CLIMATE PLAYLISTS - SHARED FUNCTIONS
# =============================================================================
#
# This file contains all shared helper functions for CO2-to-BPM conversion,
# age formatting, mood mapping, and playlist generation.
#
# Requires: config.R to be sourced first
#
# =============================================================================

# -----------------------------------------------------------------------------
# CO2 TO BPM CONVERSION
# -----------------------------------------------------------------------------

#' Convert CO2 concentration to beats per minute
#' 
#' Uses linear interpolation to map CO2 values to BPM:
#'   - Minimum CO2 in dataset -> BPM_MIN (60)
#'   - Maximum CO2 in dataset -> BPM_MAX (150)
#' 
#' @param co2 Numeric vector of CO2 values in ppm
#' @param co2_min Minimum CO2 in the dataset (for scaling)
#' @param co2_max Maximum CO2 in the dataset (for scaling)
#' @return Numeric vector of BPM values (clamped to BPM_MIN-BPM_MAX range)
#' 
co2_to_bpm <- function(co2, co2_min, co2_max) {
  # Avoid division by zero

  if (co2_max == co2_min) {
    return(rep(round((BPM_MIN + BPM_MAX) / 2), length(co2)))
  }
  
  # Linear interpolation
  bpm <- BPM_MIN + ((BPM_MAX - BPM_MIN) / (co2_max - co2_min)) * (co2 - co2_min)
  
  # Clamp to valid range and round
  bpm <- pmin(pmax(bpm, BPM_MIN), BPM_MAX)
  return(round(bpm, 0))
}

# -----------------------------------------------------------------------------
# BPM TO COLOR
# -----------------------------------------------------------------------------

#' Get a color for a BPM value (blue-to-red gradient)
#' 
#' @param bpm Numeric BPM value
#' @return Hex color string
#' 
get_bpm_color <- function(bpm) {
  ratio <- (bpm - BPM_MIN) / (BPM_MAX - BPM_MIN)
  ratio <- pmin(pmax(ratio, 0), 1)  # Clamp to 0-1
  
  # Blue (#3b82f6) to Red (#ef4444)
  r <- round(59 + ratio * (239 - 59))
  g <- round(130 + ratio * (68 - 130))
  b <- round(246 + ratio * (68 - 246))
  

  return(sprintf("#%02x%02x%02x", r, g, b))
}

# Vectorized version
get_bpm_colors <- function(bpm) {
  sapply(bpm, get_bpm_color)
}

# -----------------------------------------------------------------------------
# MOOD / GENRE MAPPING
# -----------------------------------------------------------------------------

#' Map BPM to mood and genre suggestions
#' 
#' @param bpm Numeric BPM value(s)
#' @return Character vector of mood/genre descriptions
#' 
get_mood <- function(bpm) {
  dplyr::case_when(
    bpm < 70  ~ "Glacial – Ambient / Drone",
    bpm < 85  ~ "Slow – Ballads / Blues",
    bpm < 100 ~ "Relaxed – Jazz / Soft Rock",
    bpm < 115 ~ "Moderate – Pop / Indie",
    bpm < 130 ~ "Upbeat – Rock / Funk",
    bpm < 145 ~ "Energetic – Dance / Electronic",
    TRUE      ~ "Intense – Drum & Bass / Hardcore"
  )
}

# -----------------------------------------------------------------------------
# AGE FORMATTING
# -----------------------------------------------------------------------------

#' Format age for display
#' 
#' Converts numeric age (years BP) to human-readable string.
#' Handles different scales: years, thousands, millions.
#' 
#' @param age Numeric age in years before present (positive = past)
#' @param use_ce Logical; if TRUE, convert recent dates to CE format
#' @return Character string
#' 
format_age <- function(age, use_ce = TRUE) {
  sapply(age, function(a) {
    # Recent dates in CE format
    if (use_ce && a < 0) {
      year <- round(REFERENCE_YEAR - a)
      return(paste0(year, " CE"))
    }
    if (use_ce && a <= 100) {
      year <- round(REFERENCE_YEAR - a)
      if (year > 0) {
        return(paste0(year, " CE"))
      }
    }
    
    # Millions of years
    if (abs(a) >= 1000000) {
      ma <- a / 1000000
      if (ma >= 10) {
        return(paste0(round(ma), " Ma"))
      } else {
        return(paste0(round(ma, 1), " Ma"))
      }
    }
    
    # Thousands of years
    if (abs(a) >= 10000) {
      ka <- a / 1000
      return(paste0(round(ka), "k BP"))
    }
    if (abs(a) >= 1000) {
      ka <- a / 1000
      return(paste0(round(ka, 1), "k BP"))
    }
    
    # Plain years
    return(paste0(round(a), " BP"))
  })
}

#' Format an age range for display
#' 
#' @param start_age Start age in years BP
#' @param end_age End age in years BP
#' @return Character string like "1958 CE → 1961 CE" or "10k BP → 15k BP"
#' 
format_age_range <- function(start_age, end_age) {
  paste(format_age(start_age), "→", format_age(end_age))
}

# -----------------------------------------------------------------------------
# PLAYLIST GENERATION
# -----------------------------------------------------------------------------

#' Generate a playlist for a given time period
#' 
#' @param period_config Period configuration list (from TIME_PERIODS)
#' @param co2_data List containing dataframes with 'age' and 'co2' columns
#' @return List with 'songs' dataframe and 'stats' list
#' 
generate_playlist <- function(period_config, co2_data) {
  
  # Get the appropriate data source
  source_name <- period_config$data_source
  
  if (!source_name %in% names(co2_data)) {
    stop("Data source '", source_name, "' not found in co2_data. ",
         "Available sources: ", paste(names(co2_data), collapse = ", "))
  }
  
  data <- co2_data[[source_name]]
  
  # Handle modern data differently (negative ages = years after 1950)
  is_modern <- (source_name == "modern")
  
  if (is_modern) {
    # Modern: use all data, ages are negative (e.g., -8 to -75)
    # No filtering needed - use full dataset
    data <- data %>%
      dplyr::arrange(age)  # Most negative (oldest) first
  } else {
    # Ice core / Cenozoic: positive ages, filter by max age
    max_age <- period_config$filter_max_age %||% Inf
    data <- data %>%
      dplyr::filter(age <= max_age) %>%
      dplyr::arrange(age)
  }
  
  if (nrow(data) == 0) {
    warning("No data points found for period: ", period_config$name)
    return(list(
      songs = tibble::tibble(),
      stats = list(num_songs = 0),
      raw_data = data
    ))
  }
  
  # Calculate CO2 range for BPM scaling - SPECIFIC TO THIS PLAYLIST
  co2_min <- min(data$co2, na.rm = TRUE)
  co2_max <- max(data$co2, na.rm = TRUE)
  
  # Calculate playlist metrics
  years_span <- period_config$years_span
  years_per_minute <- period_config$years_per_minute
  playlist_minutes <- years_span / years_per_minute
  num_songs <- ceiling(playlist_minutes / AVG_SONG_LENGTH)
  years_per_song <- years_span / num_songs
  
  # Generate song time windows
  if (is_modern) {
    # Modern: start from oldest (most negative age) to newest
    age_min <- min(data$age)  # e.g., -75 (oldest, 1958)
    age_max <- max(data$age)  # e.g., -8 (newest, 2024)
    
    songs <- tibble::tibble(
      song_number = 1:num_songs,
      start_age = age_min + (0:(num_songs - 1)) * years_per_song,
      end_age = age_min + (1:num_songs) * years_per_song
    )
  } else {
    # Ice core / Cenozoic: start from 0 (present) going back in time
    songs <- tibble::tibble(
      song_number = 1:num_songs,
      start_age = (0:(num_songs - 1)) * years_per_song,
      end_age = (1:num_songs) * years_per_song
    )
  }
  
  # Calculate average CO2 for each song
  songs <- songs %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      # Find data points in this time window
      points_in_window = list(
        data %>% dplyr::filter(age >= start_age & age < end_age)
      ),
      # Calculate mean CO2 (interpolate if no points in window)
      avg_co2 = if (nrow(points_in_window) > 0) {
        round(mean(points_in_window$co2, na.rm = TRUE), 0)
      } else {
        # Find nearest points and interpolate
        mid_age <- (start_age + end_age) / 2
        nearest <- data %>%
          dplyr::mutate(dist = abs(age - mid_age)) %>%
          dplyr::arrange(dist) %>%
          head(2)
        round(mean(nearest$co2, na.rm = TRUE), 0)
      }
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-points_in_window)
  
  # Add BPM, color, and mood - using THIS PLAYLIST's CO2 range
  songs <- songs %>%
    dplyr::mutate(
      bpm = co2_to_bpm(avg_co2, co2_min, co2_max),
      bpm_color = get_bpm_colors(bpm),
      mood = get_mood(bpm)
    )
  
  # Format ages for display
  if (is_modern) {
    songs <- songs %>%
      dplyr::mutate(
        # Convert negative ages to CE years
        display_start = paste0(round(REFERENCE_YEAR - start_age), " CE"),
        display_end = paste0(round(REFERENCE_YEAR - end_age), " CE"),
        age_range = paste(display_start, "→", display_end)
      )
  } else {
    songs <- songs %>%
      dplyr::mutate(
        display_start = format_age(start_age),
        display_end = format_age(end_age),
        age_range = format_age_range(start_age, end_age)
      )
  }
  
  # Statistics
  stats <- list(
    period_id = period_config$id,
    period_name = period_config$name,
    years_span = years_span,
    years_per_minute = years_per_minute,
    playlist_minutes = round(playlist_minutes, 1),
    num_songs = num_songs,
    years_per_song = round(years_per_song, 0),
    co2_min = round(co2_min, 0),
    co2_max = round(co2_max, 0),
    bpm_min = min(songs$bpm),
    bpm_max = max(songs$bpm),
    data_points = nrow(data)
  )
  
  return(list(
    songs = songs,
    stats = stats,
    raw_data = data
  ))
}

#' Generate playlists for all time periods
#' 
#' @param co2_data List containing all CO2 datasets
#' @param period_ids Character vector of period IDs to generate (default: all)
#' @return Named list of playlist results
#' 
generate_all_playlists <- function(co2_data, period_ids = NULL) {
  
  if (is.null(period_ids)) {
    period_ids <- names(TIME_PERIODS)
  }
  
  playlists <- list()
  
  for (id in period_ids) {
    period <- get_period(id)
    cat("  Generating:", period$name, "...\n")
    playlists[[id]] <- generate_playlist(period, co2_data)
  }
  
  return(playlists)
}

# -----------------------------------------------------------------------------
# OUTPUT HELPERS
# -----------------------------------------------------------------------------

#' Create a playlist template for manual song entry
#' 
#' @param playlist Playlist result from generate_playlist()
#' @return Dataframe ready for CSV export with empty song columns
#' 
create_playlist_template <- function(playlist) {
  playlist$songs %>%
    dplyr::transmute(
      song_number,
      age_period = age_range,
      co2_ppm = avg_co2,
      bpm,
      mood_genre = mood,
      song_title = "",
      artist = "",
      spotify_uri = "",
      notes = ""
    )
}

#' Print a formatted summary of a playlist
#' 
#' @param playlist Playlist result from generate_playlist()
#' 
print_playlist_summary <- function(playlist) {
  s <- playlist$stats
  
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("  ", s$period_name, "\n")
  cat("═══════════════════════════════════════════════════════════════════\n")
  cat("\n")
  cat("  Time span:           ", format(s$years_span, big.mark = ","), " years\n")
  cat("  Compression:         ", format(s$years_per_minute, big.mark = ","), " years/minute\n")
  cat("  Playlist duration:   ", s$playlist_minutes, " minutes\n")
  cat("  Number of songs:     ", s$num_songs, "\n")
  cat("  CO₂ range:           ", s$co2_min, " – ", s$co2_max, " ppm\n")
  cat("  BPM range:           ", s$bpm_min, " – ", s$bpm_max, "\n")
  cat("  Data points:         ", s$data_points, "\n")
  cat("\n")
}

# -----------------------------------------------------------------------------
# NULL-COALESCING OPERATOR (if not already defined)
# -----------------------------------------------------------------------------

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
