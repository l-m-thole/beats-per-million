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
    
    # Adaptive decimals so neighbouring song edges stay distinct:
    # >=100 -> 0 dp, 10-100 -> 1 dp (e.g. 20.0k vs 19.7k), <10 -> 2 dp.
    scaled_label <- function(x, unit) {
      dp <- if (abs(x) >= 100) 0 else if (abs(x) >= 10) 1 else 2
      paste0(formatC(x, format = "f", digits = dp), unit)
    }

    # Millions of years
    if (abs(a) >= 1000000) {
      return(scaled_label(a / 1000000, " Ma"))
    }
    
    # Thousands of years
    if (abs(a) >= 1000) {
      return(scaled_label(a / 1000, "k BP"))
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
# TIMELINE AXIS MAPPING
# -----------------------------------------------------------------------------

#' Map ages to a plot x-axis for a period's timescale
#'
#' Returns the scaling function (age in years BP -> display x value), the axis
#' title, and whether the axis should be reversed. Shared by the timeline trace
#' and the selected-song marker so the two never drift apart.
#'
#' @param period Period configuration list (from TIME_PERIODS)
#' @return list(scale = function(age), title = character, reversed = logical)
#'
axis_for_period <- function(period) {
  if (period$data_source == DATA_SOURCE_MODERN) {
    list(
      scale    = function(age) REFERENCE_YEAR - age,   # negative ages -> CE years
      title    = "Year (CE)",
      reversed = FALSE
    )
  } else if (period$data_source == DATA_SOURCE_CENOZOIC) {
    list(
      scale    = function(age) age / 1e6,
      title    = "Age (millions of years ago)",
      reversed = TRUE
    )
  } else {
    list(
      scale    = function(age) age / 1000,
      title    = "Age (thousands of years ago)",
      reversed = TRUE
    )
  }
}

# -----------------------------------------------------------------------------
# PLAYLIST GENERATION
# -----------------------------------------------------------------------------

#' Generate a playlist for a given time period
#' 
#' @param period_config Period configuration list (from TIME_PERIODS)
#' @param co2_data List containing dataframes with 'age' and 'co2' columns
#' @param co2_scale Optional c(min, max) CO2 range for global BPM scaling;
#'   NULL (default) scales to this period's own range.
#' @return List with 'songs' dataframe and 'stats' list
#' 
generate_playlist <- function(period_config, co2_data, co2_scale = NULL) {
  
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
      dplyr::arrange(age)  # Most negative age = most recent year, sorted first
  } else {
    # Ice core / Cenozoic: apply BOTH configured age bounds so the data used for
    # BPM scaling matches the data used for the song windows. Without the lower
    # bound, post-1950 (negative-age) ice-core points leak into co2_min/co2_max
    # but fall outside every song window, squashing the BPM scale.
    min_age <- period_config$filter_min_age %||% 0
    max_age <- period_config$filter_max_age %||% Inf
    data <- data %>%
      dplyr::filter(age >= min_age, age <= max_age) %>%
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
  
  # CO2 range for BPM scaling.
  #   Per-period (default): scale to THIS playlist's own min/max (max contrast,
  #     but BPM not comparable across playlists).
  #   Global (co2_scale given): scale every playlist to one shared range so
  #     tempo is comparable across eras.
  period_co2_min <- min(data$co2, na.rm = TRUE)
  period_co2_max <- max(data$co2, na.rm = TRUE)
  if (is.null(co2_scale)) {
    scale_min <- period_co2_min
    scale_max <- period_co2_max
  } else {
    scale_min <- co2_scale[1]
    scale_max <- co2_scale[2]
  }
  
  # Calculate playlist metrics. The Modern span is derived from the actual
  # record range (so it never drifts as new months are added); geological
  # periods use their configured span.
  years_span <- if (is_modern) {
    round(max(data$age) - min(data$age))
  } else {
    period_config$years_span
  }
  years_per_minute <- period_config$years_per_minute
  playlist_minutes <- years_span / years_per_minute
  num_songs <- ceiling(playlist_minutes / AVG_SONG_LENGTH)
  years_per_song <- years_span / num_songs
  
  # Generate song time windows
  if (is_modern) {
    # Modern: ages are negative (years after 1950), so the MOST negative age is
    # the MOST recent year. Build equal-width windows here; the playlist is
    # reordered oldest -> youngest (past -> present) further below.
    age_min <- min(data$age)  # most negative = most recent year (e.g., -75 ~ 2025)
    age_max <- max(data$age)  # least negative = oldest year    (e.g., -8  ~ 1958)
    
    songs <- tibble::tibble(
      song_number = 1:num_songs,
      start_age = age_min + (0:(num_songs - 1)) * years_per_song,
      end_age = age_min + (1:num_songs) * years_per_song
    )
  } else {
    # Ice core / Cenozoic: equal-width windows over [0, span]; the playlist is
    # reordered oldest -> youngest (past -> present) further below.
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
      bpm = co2_to_bpm(avg_co2, scale_min, scale_max),
      bpm_color = get_bpm_colors(bpm),
      mood = get_mood(bpm)
    )
  
  # Format ages for display so each song reads oldest edge -> youngest edge.
  # (end_age is always the larger/older age; start_age the younger.)
  if (is_modern) {
    songs <- songs %>%
      dplyr::mutate(
        display_start = paste0(round(REFERENCE_YEAR - end_age), " CE"),   # older year
        display_end = paste0(round(REFERENCE_YEAR - start_age), " CE"),   # younger year
        age_range = paste(display_start, "→", display_end)
      )
  } else {
    songs <- songs %>%
      dplyr::mutate(
        display_start = format_age(end_age),                 # older edge first
        display_end = format_age(start_age),                 # younger edge
        age_range = format_age_range(end_age, start_age)
      )
  }

  # Order the whole playlist oldest -> youngest (past -> present) and renumber,
  # so playback moves forward in time and BPM rises with CO2 toward the present.
  songs <- songs %>%
    dplyr::arrange(dplyr::desc(end_age)) %>%
    dplyr::mutate(song_number = dplyr::row_number())
  
  # Statistics
  stats <- list(
    period_id = period_config$id,
    period_name = period_config$name,
    years_span = years_span,
    years_per_minute = years_per_minute,
    playlist_minutes = round(playlist_minutes, 1),
    num_songs = num_songs,
    years_per_song = round(years_per_song, 0),
    co2_min = round(period_co2_min, 0),
    co2_max = round(period_co2_max, 0),
    scale_min = round(scale_min, 0),
    scale_max = round(scale_max, 0),
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

#' Global CO2 range across all datasets (for the "global" BPM scaling mode)
#'
#' @param co2_data List of CO2 datasets
#' @return Numeric c(min, max) over every dataset's co2 values
global_co2_range <- function(co2_data) {
  all_co2 <- unlist(lapply(co2_data, function(d) d$co2), use.names = FALSE)
  range(all_co2, na.rm = TRUE)
}

#' Generate playlists for all time periods
#' 
#' @param co2_data List containing all CO2 datasets
#' @param period_ids Character vector of period IDs to generate (default: all)
#' @param co2_scale Optional c(min, max) for global BPM scaling; NULL = per-period
#' @return Named list of playlist results
#' 
generate_all_playlists <- function(co2_data, period_ids = NULL, co2_scale = NULL) {
  
  if (is.null(period_ids)) {
    period_ids <- names(TIME_PERIODS)
  }
  
  playlists <- list()
  
  for (id in period_ids) {
    period <- get_period(id)
    cat("  Generating:", period$name, "...\n")
    playlists[[id]] <- generate_playlist(period, co2_data, co2_scale = co2_scale)
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
      soundcloud_url = "",
      notes = ""
    )
}

# -----------------------------------------------------------------------------
# SONG LIBRARY - SEEDING, BPM MATCHING & EMBED HELPERS
# -----------------------------------------------------------------------------

#' Seed the persistent song library (only if it does not already exist)
#'
#' Writes `data/song_library.csv` with a header and two example rows, so you have
#' the right columns to start from. If the file already exists it is LEFT
#' UNTOUCHED, so run_generator.R can never clobber your library.
#'
#' The library is a flat list of songs you like, each tagged with its real tempo
#' (`bpm`). The app matches songs to playlist slots by BPM at run time, so --
#' unlike the old fixed-slot curated file -- a data refresh that shifts song
#' numbers can never misalign your picks. Columns:
#'   song_title, artist, spotify_uri, soundcloud_url, youtube_url, bpm, notes
#'
#' @param data_dir Path to the data directory (default: "data").
#' @return (Invisibly) the path to the library file.
seed_song_library <- function(data_dir = "data") {
  lib_file <- file.path(data_dir, "song_library.csv")

  if (file.exists(lib_file)) {
    message("  • song_library.csv already exists - leaving your library untouched.")
    return(invisible(lib_file))
  }

  rows <- tibble::tibble(
    song_title     = c("Example slow track (replace me)",
                       "Example fast track (replace me)"),
    artist         = c("Various Artists", "Various Artists"),
    spotify_uri    = c("", ""),
    soundcloud_url = c("", ""),
    youtube_url    = c("", ""),
    bpm            = c(70, 140),
    notes          = c("Delete these two example rows once you add real songs.",
                       "bpm is the song's real tempo - see tunebat.com / songbpm.com.")
  )

  readr::write_csv(rows, lib_file)
  message("  ✓ Seeded ", lib_file, " with a header and 2 example rows. ",
          "Fill it with real songs (title, artist, a Spotify, SoundCloud and/or ",
          "YouTube link, and the song's BPM), then delete the examples.")
  invisible(lib_file)
}

#' Pick one library song whose tempo is within `tol` BPM of a target
#'
#' Pure matcher (no side effects beyond the RNG draw): keeps songs with a
#' non-missing `bpm` inside `abs(bpm - target_bpm) <= tol`, drops any whose
#' `song_title` is in `exclude`, and returns ONE of the survivors chosen with
#' `dplyr::slice_sample(n = 1)`. Returns NULL when nothing qualifies.
#'
#' Reproducibility is the caller's job: call `set.seed()` beforehand so the draw
#' is deterministic (the app seeds from the period name - see
#' `assign_songs_to_playlist()`).
#'
#' @param songs Song-library tibble (needs `bpm`, `song_title`).
#' @param target_bpm Target tempo in BPM.
#' @param tol Half-width of the BPM window (inclusive).
#' @param exclude Character vector of song titles to skip (already used).
#' @return One-row tibble, or NULL if no song qualifies.
pick_song_for_bpm <- function(songs, target_bpm, tol, exclude = character()) {
  if (is.null(songs) || nrow(songs) == 0) return(NULL)
  if (length(target_bpm) == 0 || is.na(target_bpm)) return(NULL)

  cand <- songs %>%
    dplyr::filter(!is.na(bpm), abs(bpm - target_bpm) <= tol)

  if (length(exclude) > 0) {
    cand <- cand %>% dplyr::filter(!(song_title %in% exclude))
  }

  if (nrow(cand) == 0) return(NULL)
  dplyr::slice_sample(cand, n = 1)
}

#' Pick a song for a target BPM, widening the search until something matches
#'
#' Tries progressively looser tolerances, then falls back to the single nearest
#' song, then gives up:
#'   tol = 5  ->  tol = 10  ->  nearest song by |bpm - target|  ->  NULL
#'
#' Honours `exclude` at every step, so a song already used elsewhere in the
#' playlist is never picked again. Returns NULL only when the library has no
#' usable (non-excluded, non-missing-bpm) songs left.
#'
#' @inheritParams pick_song_for_bpm
#' @param tols Ascending BPM tolerances to try before the nearest-song fallback.
#' @return One-row tibble, or NULL.
pick_song_widening <- function(songs, target_bpm, exclude = character(),
                               tols = c(5, 10)) {
  if (is.null(songs) || nrow(songs) == 0) return(NULL)
  if (length(target_bpm) == 0 || is.na(target_bpm)) return(NULL)

  for (tol in tols) {
    hit <- pick_song_for_bpm(songs, target_bpm, tol, exclude = exclude)
    if (!is.null(hit)) return(hit)
  }

  # Fallback: the nearest song(s) by absolute BPM distance.
  cand <- songs %>% dplyr::filter(!is.na(bpm))
  if (length(exclude) > 0) {
    cand <- cand %>% dplyr::filter(!(song_title %in% exclude))
  }
  if (nrow(cand) == 0) return(NULL)

  min_dist <- min(abs(cand$bpm - target_bpm))
  cand <- cand %>% dplyr::filter(abs(bpm - target_bpm) == min_dist)
  dplyr::slice_sample(cand, n = 1)
}

#' Assign a library song to every slot of a playlist, matched by BPM
#'
#' Walks the playlist slots in order and picks a song for each with
#' `pick_song_widening()`, passing the titles already used in this playlist as
#' `exclude` so a song never repeats within a period. The random draws are made
#' reproducible by seeding the RNG from the period name plus `shuffle_counter`,
#' so the same period always yields the same assignment until the user shuffles.
#'
#' @param playlist_songs Playlist tibble from generate_playlist()$songs
#'   (needs `song_number`, `bpm`).
#' @param library Song-library tibble from load_song_library().
#' @param period Period id (character) - used to seed the RNG.
#' @param shuffle_counter Integer bumped by the app's Shuffle button (default 0).
#' @param tols Tolerances handed to pick_song_widening().
#' @return Tibble with one row per MATCHED slot: song_number plus the library
#'   columns (song_title, artist, spotify_uri, soundcloud_url, bpm, notes).
#'   Empty (correctly-shaped) tibble when nothing matches.
assign_songs_to_playlist <- function(playlist_songs, library, period,
                                     shuffle_counter = 0, tols = c(5, 10)) {
  empty <- tibble::tibble(
    song_number = integer(),   song_title = character(),    artist = character(),
    spotify_uri = character(), soundcloud_url = character(),
    youtube_url = character(), bpm = double(), notes = character()
  )
  if (is.null(playlist_songs) || nrow(playlist_songs) == 0) return(empty)
  if (is.null(library) || nrow(library) == 0) return(empty)

  set.seed(sum(utf8ToInt(as.character(period))) + shuffle_counter)

  used  <- character(0)
  picks <- vector("list", nrow(playlist_songs))

  for (i in seq_len(nrow(playlist_songs))) {
    pick <- pick_song_widening(library, playlist_songs$bpm[i],
                               exclude = used, tols = tols)
    if (is.null(pick)) next

    title <- pick$song_title[1]
    if (!is.na(title) && nzchar(trimws(title))) used <- c(used, title)

    picks[[i]] <- tibble::tibble(
      song_number    = playlist_songs$song_number[i],
      song_title     = pick$song_title[1],
      artist         = pick$artist[1],
      spotify_uri    = pick$spotify_uri[1],
      soundcloud_url = pick$soundcloud_url[1],
      youtube_url    = if ("youtube_url" %in% names(pick)) pick$youtube_url[1] else NA_character_,
      bpm            = pick$bpm[1],
      notes          = pick$notes[1]
    )
  }

  picks <- picks[!vapply(picks, is.null, logical(1))]
  if (length(picks) == 0) return(empty)
  dplyr::bind_rows(picks)
}

#' Extract a Spotify track ID from a URI/URL/bare id
#'
#' Handles the three common forms:
#'   spotify:track:4iV5W9uYEdYUVa79Axb7Rh
#'   https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh?si=...
#'   4iV5W9uYEdYUVa79Axb7Rh            (bare base-62 id)
#'
#' @param uri A single Spotify URI/URL/id (character; NA or "" allowed).
#' @return The track id (character) or NA_character_ if none can be parsed.
parse_spotify_id <- function(uri) {
  if (is.null(uri) || length(uri) == 0) return(NA_character_)
  uri <- suppressWarnings(as.character(uri)[1])
  if (is.na(uri)) return(NA_character_)
  uri <- trimws(uri)
  if (!nzchar(uri)) return(NA_character_)

  # "track:ID" or "track/ID" (URI or open.spotify.com URL forms)
  m <- regmatches(uri, regexec("track[:/]([A-Za-z0-9]+)", uri))[[1]]
  if (length(m) >= 2 && nzchar(m[2])) return(m[2])

  # Bare id (base-62 token, no scheme/slashes)
  if (grepl("^[A-Za-z0-9]+$", uri)) return(uri)

  NA_character_
}

#' Build a Spotify embed-player URL from a stored spotify_uri
#' @return https://open.spotify.com/embed/track/{id} or NA_character_
spotify_embed_url <- function(uri) {
  id <- parse_spotify_id(uri)
  if (is.na(id)) return(NA_character_)
  paste0("https://open.spotify.com/embed/track/", id)
}

#' Build a Spotify "open in app" URL from a stored spotify_uri
#' @return https://open.spotify.com/track/{id} or NA_character_
spotify_open_url <- function(uri) {
  id <- parse_spotify_id(uri)
  if (is.na(id)) return(NA_character_)
  paste0("https://open.spotify.com/track/", id)
}

#' Build a SoundCloud widget-player URL from a stored soundcloud_url
#' @return https://w.soundcloud.com/player/?url={encoded} or NA_character_
soundcloud_embed_url <- function(url) {
  if (is.null(url) || length(url) == 0) return(NA_character_)
  url <- suppressWarnings(as.character(url)[1])
  if (is.na(url)) return(NA_character_)
  url <- trimws(url)
  if (!nzchar(url)) return(NA_character_)
  paste0("https://w.soundcloud.com/player/?url=",
         utils::URLencode(url, reserved = TRUE),
         "&color=%23ff5500&auto_play=false&show_comments=false")
}

#' Keep only library songs the in-app player can actually play
#'
#' A song is playable when it has a BPM and a parseable Spotify id, a
#' SoundCloud URL or a YouTube video id. Matching against the full library would otherwise hand
#' many slots a song with no link (-> "no match" search buttons) even though
#' playable songs at a similar tempo exist.
#'
#' @param library Tibble from load_song_library()
#' @return The playable subset (same columns)
playable_songs <- function(library) {
  if (is.null(library) || nrow(library) == 0) return(library)
  has_sp <- !is.na(vapply(library$spotify_uri, parse_spotify_id, character(1),
                          USE.NAMES = FALSE))
  has_sc <- !is.na(vapply(library$soundcloud_url, soundcloud_embed_url,
                          character(1), USE.NAMES = FALSE))
  has_yt <- if ("youtube_url" %in% names(library)) {
    !is.na(vapply(library$youtube_url, parse_youtube_id, character(1), USE.NAMES = FALSE))
  } else {
    rep(FALSE, nrow(library))
  }
  library[!is.na(library$bpm) & (has_sp | has_sc | has_yt), , drop = FALSE]
}

#' Keep only songs the app can play IN FULL (and auto-advance from)
#'
#' YouTube and SoundCloud always play full songs. Spotify only does when the
#' in-app Spotify player is connected (Premium); otherwise a Spotify-only song
#' falls back to the 30-s preview widget, which can't auto-advance. Matching
#' against this subset keeps "play the whole song, then the next" working.
#' If no song qualifies, the input is returned unchanged (never an empty list).
#'
#' @param library Tibble from playable_songs()
#' @param spotify_full TRUE when the Spotify full player is ready
#' @return The full-song subset (same columns), or `library` if that is empty
full_song_songs <- function(library, spotify_full = FALSE) {
  if (is.null(library) || nrow(library) == 0) return(library)
  has_link <- function(col, parser) {
    if (!col %in% names(library)) return(rep(FALSE, nrow(library)))
    !is.na(vapply(library[[col]], parser, character(1), USE.NAMES = FALSE))
  }
  full <- has_link("youtube_url", parse_youtube_id) |
    has_link("soundcloud_url", soundcloud_embed_url) |
    (isTRUE(spotify_full) & has_link("spotify_uri", parse_spotify_id))
  if (!any(full)) return(library)
  library[full, , drop = FALSE]
}

#' Where the "now playing" ball sits on the CO2 curve
#'
#' Songs play past -> present, so the ball travels from the OLDER edge of the
#' song's time window (larger age) to the YOUNGER edge as the track plays.
#' The y value is read off the CO2 curve itself (linear interpolation of the
#' period's raw data), so the ball rides along the line rather than floating
#' at the window average.
#'
#' @param song One playlist row (needs start_age, end_age, avg_co2)
#' @param raw_data The period's CO2 data (age, co2)
#' @param frac Playback progress, 0 = song start, 1 = song end (clamped)
#' @return list(age, co2)
ball_position <- function(song, raw_data, frac = 0) {
  frac <- suppressWarnings(as.numeric(frac)[1])
  if (is.na(frac)) frac <- 0
  frac <- min(max(frac, 0), 1)

  age_old   <- max(song$start_age, song$end_age)
  age_young <- min(song$start_age, song$end_age)
  age <- age_old - frac * (age_old - age_young)

  ok <- !is.na(raw_data$age) & !is.na(raw_data$co2)
  co2 <- if (sum(ok) >= 2) {
    stats::approx(raw_data$age[ok], raw_data$co2[ok], xout = age,
                  rule = 2, ties = mean)$y
  } else {
    song$avg_co2
  }

  list(age = age, co2 = co2)
}

#' Extract a YouTube video id from a URL or bare id
#'
#' Handles youtube.com/watch?v=ID, music.youtube.com/watch?v=ID, youtu.be/ID,
#' youtube.com/embed/ID, youtube.com/shorts/ID and a bare 11-character id.
#' @return the 11-character id, or NA_character_
parse_youtube_id <- function(url) {
  if (is.null(url) || length(url) == 0) return(NA_character_)
  url <- suppressWarnings(as.character(url)[1])
  if (is.na(url)) return(NA_character_)
  url <- trimws(url)
  if (!nzchar(url)) return(NA_character_)

  pats <- c("[?&]v=([A-Za-z0-9_-]{11})",
            "youtu\\.be/([A-Za-z0-9_-]{11})",
            "/(?:embed|shorts|live)/([A-Za-z0-9_-]{11})")
  for (p in pats) {
    m <- regmatches(url, regexec(p, url, perl = TRUE))[[1]]
    if (length(m) >= 2) return(m[2])
  }
  if (grepl("^[A-Za-z0-9_-]{11}$", url)) return(url)
  NA_character_
}

#' "Open on YouTube" URL for a stored youtube_url
youtube_open_url <- function(url) {
  id <- parse_youtube_id(url)
  if (is.na(id)) return(NA_character_)
  paste0("https://www.youtube.com/watch?v=", id)
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
